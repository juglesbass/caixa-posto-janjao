import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dialogs/cadastro_pin_dialog.dart';
import '../models/operador_model.dart';
import '../models/turno.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/operadores_sync_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_haptics.dart';
import '../utils/validator.dart';

/// Identificação do operador em tela cheia.
///
/// Substitui o diálogo que existia antes. A diferença não é estética: um
/// diálogo tem bordas, e no iOS o teclado do sistema empurrava essas bordas
/// para fora da tela — o diálogo sumia ou colapsava. Uma tela inteira não tem
/// para onde ser empurrada: o Scaffold reduz a altura útil e o conteúdo rola,
/// que é o comportamento que o sistema já sabe fazer.
///
/// Também acaba com a tela de fundo aparecendo por trás, com os mesmos botões
/// repetidos logo abaixo do diálogo.
///
/// Retorna, via Navigator.pop:
///   {'operador': String, 'fundoCaixa': double}  identificação concluída
///   {'acao': 'historico'}                       abrir histórico de turnos
///   null                                        desistiu
class IdentificacaoScreen extends StatefulWidget {
  final bool novoTurno;

  /// Quando informado, a tela é usada embutida (é o conteúdo da vez, sem rota
  /// empurrada) e devolve o resultado por aqui em vez de Navigator.pop.
  ///
  /// Sem isso, o app renderizava a tela "Nenhum Turno Aberto" e só no frame
  /// seguinte empurrava a identificação por cima: dava um flash na abertura e
  /// a tela antiga ficava por trás.
  final ValueChanged<Map<String, dynamic>?>? onResultado;

  /// Conteúdo opcional acima do painel — hoje o aviso de PDFs pendentes
  final Widget? banner;

  /// Alternância de tema, exibida no lugar do X quando a tela está embutida
  final ValueChanged<bool>? onMudarTema;
  final bool isDark;

  const IdentificacaoScreen({
    super.key,
    required this.novoTurno,
    this.onResultado,
    this.banner,
    this.onMudarTema,
    this.isDark = true,
  });

  /// True quando a tela é o próprio conteúdo, e não uma rota sobre outra
  bool get embutida => onResultado != null;

  @override
  State<IdentificacaoScreen> createState() => _IdentificacaoScreenState();
}

enum _Etapa { escolha, digitarNome, pin }

class _IdentificacaoScreenState extends State<IdentificacaoScreen> {
  final _controllerNome = TextEditingController();
  final _focusNome = FocusNode();
  final _controllerPin = TextEditingController();
  final _focusPin = FocusNode();

  _Etapa _etapa = _Etapa.escolha;

  /// Nome já resolvido (da lista ou digitado) para o qual o PIN será pedido
  String _nomeEmValidacao = '';

  /// Dígitos do PIN. Alimentado só pelo teclado da própria tela.
  String _pin = '';

  String? _erroNome;
  String? _erroPin;
  bool _processando = false;

  /// Nomes que abriram turno neste aparelho, do mais recente para o mais antigo
  List<String> _recentes = [];

  @override
  void initState() {
    super.initState();
    _focusPin.addListener(_repintar);
    unawaited(OperadoresSyncService.obterOperadores(sincronizarNuvem: true));
    _carregarRecentes();
  }

  void _repintar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusPin.removeListener(_repintar);
    _controllerNome.dispose();
    _focusNome.dispose();
    _controllerPin.dispose();
    _focusPin.dispose();
    super.dispose();
  }

  /// Quem usou este caixa por último tem alta chance de ser quem vai usar
  /// agora. Com uma equipe grande, isso evita caçar o próprio nome na lista.
  Future<void> _carregarRecentes() async {
    try {
      final turnos = await DatabaseService.instance.obterTodosTurnos(limit: 40);
      final vistos = <String>[];
      for (final Turno t in turnos) {
        final nome = t.operador.trim();
        if (nome.isEmpty) continue;
        if (vistos.any((v) => v.toLowerCase() == nome.toLowerCase())) continue;
        vistos.add(nome);
        if (vistos.length == 4) break;
      }
      if (mounted) setState(() => _recentes = vistos);
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FLUXO
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _selecionarNome(String nome) async {
    AppHaptics.selection();
    final formatado = Validator.formatarNomeOperador(nome);

    setState(() {
      _processando = true;
      _erroNome = null;
      _erroPin = null;
      _pin = '';
    });

    await Future<void>.delayed(const Duration(milliseconds: 16));
    final temPin = await AuthService.operadorTemPin(formatado);
    if (!mounted) return;

    if (!temPin) {
      // 1º acesso: precisa cadastrar PIN antes de entrar
      setState(() => _processando = false);
      final cadastrou = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => CadastroPinDialog(operador: formatado, obrigatorio: true),
      );
      if (cadastrou != true || !mounted) return;
      _concluir(formatado);
      return;
    }

    setState(() {
      _processando = false;
      _nomeEmValidacao = formatado;
      _etapa = _Etapa.pin;
      _controllerPin.clear();
    });
  }

  void _irParaDigitacao() {
    AppHaptics.light();
    setState(() {
      _etapa = _Etapa.digitarNome;
      _erroNome = null;
    });
    // Só pede foco depois do primeiro frame da nova etapa
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNome.requestFocus();
    });
  }

  void _voltar() {
    AppHaptics.light();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _etapa = _Etapa.escolha;
      _nomeEmValidacao = '';
      _pin = '';
      _erroNome = null;
      _erroPin = null;
      _controllerNome.clear();
      _controllerPin.clear();
    });
  }

  void _confirmarNomeDigitado() {
    final erro = Validator.validarNomeOperador(_controllerNome.text);
    if (erro != null) {
      AppHaptics.heavy();
      setState(() => _erroNome = erro);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _selecionarNome(_controllerNome.text);
  }

  void _onPinChanged(String valor) {
    setState(() {
      _pin = valor;
      if (_erroPin != null) _erroPin = null;
    });
    if (valor.length == 4) _validarPin();
  }

  Future<void> _validarPin() async {
    if (_processando) return;
    setState(() => _processando = true);

    // Dois frames antes de começar: a derivação do PIN é pesada e roda na
    // thread da interface. Sem esta pausa, o setState acima nunca chega a ser
    // desenhado — a tela congela sem nenhum sinal de que algo está em curso.
    await Future<void>.delayed(const Duration(milliseconds: 32));

    final valido = await AuthService.validarPin(_nomeEmValidacao, _pin);
    if (!mounted) return;

    if (!valido) {
      AppHaptics.heavy();
      setState(() {
        _processando = false;
        _pin = '';
        _controllerPin.clear();
        _erroPin = 'PIN incorreto. Tente novamente.';
      });
      _focusPin.requestFocus();
      return;
    }

    _concluir(_nomeEmValidacao);
  }

  void _concluir(String operador) {
    AppHaptics.medium();
    _devolver({'operador': operador, 'fundoCaixa': 0.0});
  }

  void _devolver(Map<String, dynamic>? resultado) {
    if (widget.embutida) {
      widget.onResultado!(resultado);
      // Embutida, a tela continua montada: limpa para o próximo uso
      if (mounted) {
        setState(() {
          _etapa = _Etapa.escolha;
          _nomeEmValidacao = '';
          _pin = '';
          _controllerNome.clear();
          _controllerPin.clear();
          _erroNome = null;
          _erroPin = null;
          _processando = false;
        });
      }
      return;
    }
    Navigator.of(context).pop(resultado);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // INTERFACE
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF080B12) : AppColors.lightBg;

    return Scaffold(
      backgroundColor: bg,
      // Padrão do Scaffold: o teclado reduz a altura útil e o conteúdo rola.
      // É justamente o que o diálogo não conseguia fazer.
      resizeToAvoidBottomInset: true,
      body: Container(
        // Fundo com profundidade. Preto chapado deixava a tela com cara de
        // vazio, principalmente com poucos operadores na lista.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF101B33), Color(0xFF0A0F1A), Color(0xFF070A11)]
                : const [Color(0xFFEFF4FF), Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Brilho suave atrás do topo, para o fundo não ser uma chapa só
            Positioned(
              top: -140,
              left: -80,
              right: -80,
              height: 380,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: isDark ? 0.20 : 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      // Centraliza quando sobra espaço e rola quando o teclado
                      // encolhe a área útil
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.banner != null) widget.banner!,
                                _painel(isDark),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Superfície onde o conteúdo vive. É ela que devolve a contenção que o
  /// diálogo tinha — borda, elevação e cantos — sem trazer de volta o problema
  /// do teclado, porque quem gerencia a altura continua sendo o Scaffold.
  Widget _painel(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1524) : Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.10),
            blurRadius: 40,
            spreadRadius: -6,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _topo(isDark),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: switch (_etapa) {
                _Etapa.escolha => _passoEscolha(isDark),
                _Etapa.digitarNome => _passoDigitarNome(isDark),
                _Etapa.pin => _passoPin(isDark),
              },
            ),
          ),
          if (_etapa == _Etapa.escolha && widget.novoTurno) _rodapeHistorico(isDark),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ── Topo ─────────────────────────────────────────────────────────────────

  Widget _topo(bool isDark) {
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final naEscolha = _etapa == _Etapa.escolha;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF16223C), const Color(0xFF0E1524)]
              : [const Color(0xFFEFF6FF), Colors.white],
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          if (naEscolha)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, Color(0xFF0284C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
              child: const Icon(Icons.local_gas_station_rounded,
                  color: Colors.white, size: 23),
            )
          else
            IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: textPri),
              tooltip: 'Voltar',
              onPressed: _processando ? null : _voltar,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _etapa == _Etapa.pin ? _nomeEmValidacao : 'POSTO JANJÃO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _etapa == _Etapa.pin ? 17 : 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: _etapa == _Etapa.pin ? -0.2 : 0.6,
                    color: textPri,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  switch (_etapa) {
                    _Etapa.escolha =>
                      widget.novoTurno ? 'Abrir novo turno' : 'Retomar turno',
                    _Etapa.digitarNome => 'Informe o nome do operador',
                    _Etapa.pin => 'Digite o PIN para confirmar',
                  },
                  style: TextStyle(fontSize: 12, color: textSec),
                ),
              ],
            ),
          ),
          if (widget.embutida && widget.onMudarTema != null && _etapa == _Etapa.escolha)
            IconButton(
              icon: Icon(
                widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: widget.isDark ? const Color(0xFFFBBF24) : const Color(0xFF2563EB),
              ),
              tooltip: widget.isDark ? 'Tema claro' : 'Tema escuro',
              onPressed: () => widget.onMudarTema!(!widget.isDark),
            )
          else if (!widget.embutida)
            IconButton(
              icon: Icon(Icons.close_rounded, color: textSec),
              tooltip: 'Fechar',
              onPressed: _processando ? null : () => Navigator.of(context).pop(),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ── Passo 1: escolher quem é ─────────────────────────────────────────────

  Widget _passoEscolha(bool isDark) {
    return ValueListenableBuilder<List<OperadorModel>>(
      key: const ValueKey('escolha'),
      valueListenable: OperadoresSyncService.operadoresNotifier,
      builder: (context, operadores, _) {
        final ativos = operadores.where((o) => o.ativo && !o.removido).toList()
          ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

        if (ativos.isEmpty) {
          // Primeiro uso do posto: não há lista, então digitar é o único caminho
          return _passoDigitarNome(isDark, semVoltar: true);
        }

        final nomesRecentes = _recentes
            .where((r) => ativos.any((o) => o.nomeExibicao.toLowerCase() == r.toLowerCase()))
            .toList();

        final demais = ativos
            .where((o) => !nomesRecentes.any((r) => r.toLowerCase() == o.nomeExibicao.toLowerCase()))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (nomesRecentes.isNotEmpty) ...[
              _rotulo('RECENTES NESTE CAIXA', isDark),
              const SizedBox(height: 8),
              _grade(nomesRecentes, isDark, destaque: true),
              const SizedBox(height: 18),
            ],
            _rotulo(
              nomesRecentes.isEmpty ? 'QUEM ESTÁ ASSUMINDO O CAIXA?' : 'OUTROS OPERADORES',
              isDark,
            ),
            const SizedBox(height: 8),
            _grade([for (final op in demais) op.nomeExibicao], isDark),
            const SizedBox(height: 18),
            _botaoOutroNome(isDark),
            if (_erroNome != null) ...[
              const SizedBox(height: 14),
              _mensagemErro(_erroNome!),
            ],
          ],
        );
      },
    );
  }

  /// Duas colunas de cartões compactos.
  ///
  /// Um por linha ficava confortável com 2 operadores e insustentável com 12:
  /// a lista virava uma rolagem longa antes de chegar em qualquer outra coisa.
  Widget _grade(List<String> nomes, bool isDark, {bool destaque = false}) {
    if (nomes.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        const espaco = 8.0;
        final largura = (constraints.maxWidth - espaco) / 2;
        return Wrap(
          spacing: espaco,
          runSpacing: espaco,
          children: [
            for (final nome in nomes)
              SizedBox(
                width: largura,
                child: _cartaoNome(nome, isDark, destaque: destaque),
              ),
          ],
        );
      },
    );
  }

  Widget _cartaoNome(String nome, bool isDark, {bool destaque = false}) {
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;

    return InkWell(
      onTap: _processando ? null : () => _selecionarNome(nome),
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: destaque
              ? AppColors.accent.withValues(alpha: isDark ? 0.16 : 0.08)
              : (isDark ? const Color(0xFF121A2B) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(
            color: destaque
                ? AppColors.accentLight.withValues(alpha: 0.6)
                : (isDark ? const Color(0xFF1E293B) : AppColors.lightBorder),
          ),
        ),
        child: Row(
          children: [
            _avatar(nome, destaque, isDark),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: destaque ? AppColors.accentLight : textPri,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String nome, bool destaque, bool isDark) {
    final partes =
        nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final iniciais = partes.isEmpty
        ? '?'
        : (partes.length == 1
            ? partes.first.substring(0, 1)
            : '${partes.first.substring(0, 1)}${partes.last.substring(0, 1)}');

    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: destaque
            ? const LinearGradient(
                colors: [AppColors.accent, Color(0xFF0284C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: destaque
            ? null
            : (isDark ? const Color(0xFF20273D) : const Color(0xFFE2E8F0)),
      ),
      child: Text(
        iniciais.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: destaque
              ? Colors.white
              : (isDark ? AppColors.darkTextSec : AppColors.lightTextSec),
        ),
      ),
    );
  }

  Widget _botaoOutroNome(bool isDark) {
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: _processando ? null : _irParaDigitacao,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
        label: const Text(
          'Outro nome',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: textSec,
          side: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : AppColors.lightBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
        ),
      ),
    );
  }

  // ── Passo 2: digitar nome ────────────────────────────────────────────────

  Widget _passoDigitarNome(bool isDark, {bool semVoltar = false}) {
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;

    return Column(
      key: const ValueKey('digitar'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rotulo('NOME DO OPERADOR', isDark),
        const SizedBox(height: 10),
        TextField(
          controller: _controllerNome,
          focusNode: _focusNome,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          // 16px é o mínimo: abaixo disso o Safari do iOS amplia a tela ao focar
          style: TextStyle(color: textPri, fontSize: 16, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Nome completo',
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
            errorText: _erroNome,
            filled: true,
            fillColor: isDark ? const Color(0xFF121A2B) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : AppColors.lightBorder,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : AppColors.lightBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              borderSide: const BorderSide(color: AppColors.accentLight, width: 1.6),
            ),
          ),
          onChanged: (_) {
            if (_erroNome != null) setState(() => _erroNome = null);
          },
          onSubmitted: (_) => _confirmarNomeDigitado(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _processando ? null : _confirmarNomeDigitado,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
            ),
            child: _processando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.white),
                  )
                : const Text(
                    'Continuar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        if (semVoltar) ...[
          const SizedBox(height: 14),
          Text(
            'Nenhum operador cadastrado ainda. O primeiro acesso cria o cadastro '
            'e pede um PIN de 4 dígitos.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
            ),
          ),
        ],
      ],
    );
  }

  // ── Passo 3: PIN ─────────────────────────────────────────────────────────

  Widget _passoPin(bool isDark) {
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final erro = _erroPin != null;

    return Column(
      key: const ValueKey('pin'),
      children: [
        const SizedBox(height: 12),
        // Campo real, com o teclado numérico do sistema.
        //
        // A fonte é grande de propósito: o Safari do iOS amplia a tela ao focar
        // qualquer campo com fonte menor que 16px, e foi assim que a tentativa
        // anterior quebrou. Aqui não há campo escondido nem fonte minúscula —
        // e, por ser tela cheia, o teclado apenas empurra o conteúdo.
        Container(
          constraints: const BoxConstraints(maxWidth: 260),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121A2B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            border: Border.all(
              color: erro
                  ? AppColors.red
                  : (_focusPin.hasFocus
                      ? AppColors.accentLight
                      : (isDark ? const Color(0xFF1E293B) : AppColors.lightBorder)),
              width: erro || _focusPin.hasFocus ? 1.8 : 1,
            ),
          ),
          child: TextField(
            controller: _controllerPin,
            focusNode: _focusPin,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            obscuringCharacter: '\u25CF',
            textAlign: TextAlign.center,
            enabled: !_processando,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontSize: 30,
              letterSpacing: 16,
              fontWeight: FontWeight.w700,
              color: erro ? AppColors.red : textPri,
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 18),
            ),
            onChanged: _onPinChanged,
            onSubmitted: (_) {
              if (_controllerPin.text.length == 4) _validarPin();
            },
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 22,
          child: _erroPin != null
              ? _mensagemErro(_erroPin!)
              : (_processando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accentLight),
                    )
                  : Text(
                      'Digite os 4 números do seu PIN',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
                      ),
                    )),
        ),
      ],
    );
  }

  // ── Rodapé ───────────────────────────────────────────────────────────────

  Widget _rodapeHistorico(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(
            height: 18,
            color: isDark ? const Color(0xFF1B2233) : AppColors.lightBorder,
          ),
          SizedBox(
        width: double.infinity,
        height: 46,
        child: TextButton.icon(
          onPressed: _processando
              ? null
              : () => _devolver({'acao': 'historico'}),
          icon: const Icon(Icons.history_rounded, size: 19),
          label: const Text(
            'Histórico e reabrir turno',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Peças ────────────────────────────────────────────────────────────────

  Widget _rotulo(String texto, bool isDark) {
    return Text(
      texto,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.9,
        color: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
      ),
    );
  }

  Widget _mensagemErro(String texto) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline_rounded, size: 15, color: AppColors.red),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
