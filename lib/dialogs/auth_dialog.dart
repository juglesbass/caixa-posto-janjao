import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dialogs/cadastro_pin_dialog.dart';
import '../models/operador_model.dart';
import '../services/auth_service.dart';
import '../services/operadores_sync_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_haptics.dart';
import '../utils/validator.dart';

/// Identificação do operador na abertura/retomada de turno.
///
/// O caixa já tem a lista de operadores sincronizada do Firestore, então o
/// caminho normal é **tocar no próprio nome** — digitar vira exceção, não regra.
/// Isso corta o erro de digitação (que criava operador novo por engano, pedindo
/// cadastro de PIN do nada) e evita abrir o teclado numa tela onde, na maioria
/// das vezes, não há o que escrever.
class AuthDialog extends StatefulWidget {
  final bool novoTurno;
  final String? pinConfigurado;

  const AuthDialog({
    super.key,
    required this.novoTurno,
    this.pinConfigurado,
  });

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  final _controllerNome = TextEditingController();
  final _controllerPin = TextEditingController();
  final _focusNome = FocusNode();
  final _focusPin = FocusNode();

  String? _erroNome;
  String? _erroPin;

  /// Operador escolhido na lista. Nulo enquanto ninguém foi selecionado.
  OperadorModel? _selecionado;

  /// Digitação manual do nome, para quem ainda não está cadastrado
  bool _modoManual = false;

  bool _mostrarCampoPin = false;
  bool _processando = false;

  /// Filtro da lista de operadores, exibido só quando a lista cresce
  final _controllerBusca = TextEditingController();
  String _busca = '';

  /// A partir de quantos operadores vale mostrar o campo de busca
  static const int _limiteParaBusca = 6;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _focusPin.addListener(_repintar);
    // Puxa a lista mais recente sem travar a abertura do diálogo
    unawaited(OperadoresSyncService.obterOperadores(sincronizarNuvem: true));
  }

  void _repintar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusPin.removeListener(_repintar);
    _controllerNome.dispose();
    _controllerPin.dispose();
    _controllerBusca.dispose();
    _focusNome.dispose();
    _focusPin.dispose();
    super.dispose();
  }

  String get _nomeAtual => _selecionado?.nomeExibicao ?? _controllerNome.text;

  // ──────────────────────────────────────────────────────────────────────────
  // SELEÇÃO
  // ──────────────────────────────────────────────────────────────────────────

  void _escolherOperador(OperadorModel op) async {
    AppHaptics.selection();
    setState(() {
      _selecionado = op;
      _modoManual = false;
      _erroNome = null;
      _erroPin = null;
      _controllerPin.clear();
      _mostrarCampoPin = false;
    });

    final temPin = await AuthService.operadorTemPin(op.nomeExibicao);
    if (!mounted) return;
    setState(() => _mostrarCampoPin = temPin);
    if (temPin) {
      _focusPin.requestFocus();
    }
  }

  void _entrarNoModoManual() {
    AppHaptics.light();
    setState(() {
      _modoManual = true;
      _selecionado = null;
      _mostrarCampoPin = false;
      _erroPin = null;
      _controllerPin.clear();
    });
    _focusNome.requestFocus();
  }

  void _voltarParaLista() {
    AppHaptics.light();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _modoManual = false;
      _selecionado = null;
      _mostrarCampoPin = false;
      _erroNome = null;
      _erroPin = null;
      _controllerNome.clear();
      _controllerPin.clear();
    });
  }

  void _onNomeChanged(String val) {
    // Redesenha na hora para o botao principal habilitar junto com a digitacao;
    // o debounce abaixo cuida so da consulta de PIN, que e assincrona.
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      if (_erroNome != null) setState(() => _erroNome = null);

      if (Validator.validarNomeOperador(val) == null) {
        final nomeFormatado = Validator.formatarNomeOperador(val);
        final temPin = await AuthService.operadorTemPin(nomeFormatado);
        if (mounted) setState(() => _mostrarCampoPin = temPin);
      } else if (_mostrarCampoPin) {
        setState(() => _mostrarCampoPin = false);
      }
    });
  }

  void _onPinChanged(String val) {
    if (_erroPin != null) setState(() => _erroPin = null);
    setState(() {}); // redesenha as casas do PIN
    // 4 dígitos completos: confirma sozinho, sem exigir mais um toque
    if (val.length == 4 && !_processando) {
      _confirmar();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CONFIRMAÇÃO
  // ──────────────────────────────────────────────────────────────────────────

  void _confirmar() async {
    if (_processando) return;

    final nomeRaw = _nomeAtual;
    final erroValidacao = Validator.validarNomeOperador(nomeRaw);

    if (erroValidacao != null) {
      AppHaptics.heavy();
      setState(() => _erroNome = erroValidacao);
      return;
    }

    final nomeFormatado = Validator.formatarNomeOperador(nomeRaw);

    setState(() {
      _processando = true;
      _erroPin = null;
    });

    final temPin = await AuthService.operadorTemPin(nomeFormatado);
    if (!mounted) return;

    if (!temPin) {
      // ── 1º ACESSO: cadastro de PIN obrigatório ──
      setState(() => _processando = false);

      final cadastrou = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => CadastroPinDialog(
          operador: nomeFormatado,
          obrigatorio: true,
        ),
      );

      if (cadastrou != true || !mounted) return;
    } else {
      final pinDigitado = _controllerPin.text.trim();
      if (pinDigitado.length != 4) {
        AppHaptics.heavy();
        setState(() {
          _processando = false;
          _mostrarCampoPin = true;
          _erroPin = 'Digite os 4 números do seu PIN';
        });
        _focusPin.requestFocus();
        return;
      }

      final valido = await AuthService.validarPin(nomeFormatado, pinDigitado);
      if (!mounted) return;

      if (!valido) {
        AppHaptics.heavy();
        setState(() {
          _processando = false;
          _mostrarCampoPin = true;
          _erroPin = 'PIN incorreto. Tente novamente.';
        });
        _controllerPin.clear();
        _focusPin.requestFocus();
        return;
      }
    }

    if (!mounted) return;
    AppHaptics.medium();
    Navigator.of(context).pop({
      'operador': nomeFormatado,
      'fundoCaixa': 0.0,
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // INTERFACE
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgDialogo = isDark ? const Color(0xFF0E1524) : AppColors.lightSurface;
    final borda = isDark ? const Color(0xFF1E293B) : AppColors.lightBorder;

    // O teclado não pode empurrar o conteúdo para fora da tela: o corpo rola e
    // o diálogo respeita a área livre acima do teclado.
    final alturaTeclado = MediaQuery.viewInsetsOf(context).bottom;

    final comTeclado = alturaTeclado > 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      // Centralizado é bonito com a tela livre, mas com o teclado aberto o
      // espaço restante encolhe e o diálogo era empurrado para fora da tela —
      // no iOS ele sumia para cima. Ancorado no topo isso não acontece: o que
      // não couber vira rolagem dentro do corpo.
      alignment: comTeclado ? Alignment.topCenter : Alignment.center,
      insetPadding: EdgeInsets.fromLTRB(
        16,
        comTeclado ? 12 : 24,
        16,
        (comTeclado ? 8 : 24) + alturaTeclado,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: bgDialogo,
            borderRadius: BorderRadius.circular(AppColors.radiusXl),
            border: Border.all(color: borda),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.18),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _cabecalho(isDark),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _corpo(isDark),
                  ),
                ),
              ),
              _rodape(isDark),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cabeçalho ────────────────────────────────────────────────────────────

  Widget _cabecalho(bool isDark) {
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF15203A), const Color(0xFF0E1524)]
              : [const Color(0xFFEFF6FF), AppColors.lightSurface],
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, Color(0xFF0284C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              widget.novoTurno
                  ? Icons.local_gas_station_rounded
                  : Icons.waving_hand_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.novoTurno ? 'Abrir Novo Turno' : 'Bem-vindo de volta',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textPri,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _selecionado != null
                      ? 'Confirme com o seu PIN'
                      : 'Identifique-se para começar',
                  style: TextStyle(fontSize: 12, color: textSec),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: textSec, size: 22),
            tooltip: 'Fechar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ── Corpo ────────────────────────────────────────────────────────────────

  Widget _corpo(bool isDark) {
    return ValueListenableBuilder<List<OperadorModel>>(
      valueListenable: OperadoresSyncService.operadoresNotifier,
      builder: (context, operadores, _) {
        final disponiveis =
            operadores.where((o) => o.ativo && !o.removido).toList()
              ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

        // Sem ninguém cadastrado ainda (primeiro uso do posto): não faz sentido
        // mostrar uma lista vazia, vai direto para a digitação.
        final semLista = disponiveis.isEmpty;
        final digitando = _modoManual || semLista;

        // Depois de escolher, a lista inteira só ocupa espaço — e espaço é
        // exatamente o que falta com o teclado aberto. Vira uma linha compacta
        // com quem foi escolhido e um atalho para trocar.
        final confirmandoPin = !digitando && _selecionado != null && _mostrarCampoPin;

        return Column(
          key: ValueKey('corpo-${digitando ? 'manual' : 'lista'}-${_selecionado?.id ?? ''}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (digitando)
              ..._blocoDigitacao(isDark, podeVoltar: !semLista)
            else if (confirmandoPin)
              _resumoSelecionado(isDark)
            else
              ..._blocoLista(isDark, disponiveis),
            if (_mostrarCampoPin) ...[
              const SizedBox(height: 18),
              _blocoPin(isDark),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _blocoLista(bool isDark, List<OperadorModel> operadores) {
    final comBusca = operadores.length > _limiteParaBusca;
    final termo = _busca.trim().toLowerCase();
    final visiveis = termo.isEmpty
        ? operadores
        : operadores.where((o) => o.nome.toLowerCase().contains(termo)).toList();

    return [
      _rotulo('QUEM ESTÁ ASSUMINDO O CAIXA?', isDark),
      if (comBusca) ...[
        const SizedBox(height: 10),
        _campoBusca(isDark),
      ],
      const SizedBox(height: 10),
      if (visiveis.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Nenhum operador encontrado para "$_busca".',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
            ),
          ),
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final op in visiveis) _cartaoOperador(op, isDark)],
        ),
      const SizedBox(height: 8),
      _cartaoOutro(isDark),
      if (_erroNome != null) ...[
        const SizedBox(height: 10),
        _mensagemErro(_erroNome!),
      ],
    ];
  }

  /// Linha compacta do operador já escolhido, exibida no lugar da lista
  Widget _resumoSelecionado(bool isDark) {
    final op = _selecionado!;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.accentLight.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          _avatarIniciais(op.nomeExibicao, true, isDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  op.nomeExibicao,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: textPri,
                  ),
                ),
                Text(
                  'Assumindo o caixa',
                  style: TextStyle(fontSize: 11, color: textSec),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _voltarParaLista,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentLight,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Trocar',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoBusca(bool isDark) {
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    return SizedBox(
      height: 42,
      child: TextField(
        controller: _controllerBusca,
        style: TextStyle(color: textPri, fontSize: 13.5),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Buscar operador',
          hintStyle: TextStyle(color: textSec, fontSize: 13.5),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: textSec),
          suffixIcon: _busca.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded, size: 16, color: textSec),
                  onPressed: () {
                    _controllerBusca.clear();
                    setState(() => _busca = '');
                  },
                ),
          filled: true,
          fillColor: isDark ? const Color(0xFF161E31) : const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : AppColors.lightBorder,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : AppColors.lightBorder,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
            borderSide: const BorderSide(color: AppColors.accentLight, width: 1.4),
          ),
        ),
        onChanged: (v) => setState(() => _busca = v),
      ),
    );
  }

  List<Widget> _blocoDigitacao(bool isDark, {required bool podeVoltar}) {
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;

    return [
      Row(
        children: [
          Expanded(child: _rotulo('NOME DO OPERADOR', isDark)),
          if (podeVoltar)
            TextButton.icon(
              onPressed: _voltarParaLista,
              icon: const Icon(Icons.arrow_back_rounded, size: 15),
              label: const Text('Ver lista'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentLight,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _controllerNome,
        focusNode: _focusNome,
        autofocus: podeVoltar == false,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        style: TextStyle(color: textPri, fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Digite o nome completo',
          prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
          errorText: _erroNome,
          filled: true,
          fillColor: isDark ? const Color(0xFF161E31) : const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        onChanged: _onNomeChanged,
        onSubmitted: (_) => _confirmar(),
      ),
    ];
  }

  Widget _cartaoOperador(OperadorModel op, bool isDark) {
    final selecionado = _selecionado?.id == op.id;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final ehGerente = op.perfil.toLowerCase() == 'gerente';

    return InkWell(
      onTap: () => _escolherOperador(op),
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selecionado
              ? AppColors.accent.withValues(alpha: isDark ? 0.20 : 0.10)
              : (isDark ? const Color(0xFF161E31) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(
            color: selecionado
                ? AppColors.accentLight
                : (isDark ? const Color(0xFF1E293B) : AppColors.lightBorder),
            width: selecionado ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _avatarIniciais(op.nomeExibicao, selecionado, isDark),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    op.nomeExibicao,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: selecionado ? AppColors.accentLight : textPri,
                    ),
                  ),
                  if (ehGerente)
                    const Text(
                      'Gerência',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.amber,
                      ),
                    ),
                ],
              ),
            ),
            if (selecionado) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle_rounded,
                  size: 17, color: AppColors.accentLight),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cartaoOutro(bool isDark) {
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    return InkWell(
      onTap: _entrarNoModoManual,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(
            color: isDark ? const Color(0xFF1E293B) : AppColors.lightBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: textSec.withValues(alpha: 0.5)),
              ),
              child: Icon(Icons.person_add_alt_1_rounded, size: 17, color: textSec),
            ),
            const SizedBox(width: 10),
            Text(
              'Outro nome',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: textSec,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarIniciais(String nome, bool selecionado, bool isDark) {
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final iniciais = partes.isEmpty
        ? '?'
        : (partes.length == 1
            ? partes.first.substring(0, 1)
            : '${partes.first.substring(0, 1)}${partes.last.substring(0, 1)}');

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: selecionado
            ? const LinearGradient(
                colors: [AppColors.accent, Color(0xFF0284C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: selecionado
            ? null
            : (isDark ? const Color(0xFF20273D) : const Color(0xFFE2E8F0)),
      ),
      child: Text(
        iniciais.toUpperCase(),
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: selecionado
              ? Colors.white
              : (isDark ? AppColors.darkTextSec : AppColors.lightTextSec),
        ),
      ),
    );
  }

  // ── PIN ──────────────────────────────────────────────────────────────────

  Widget _blocoPin(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _rotulo('PIN DE ACESSO', isDark),
        const SizedBox(height: 10),
        // Um único campo guarda o valor; as quatro casas são só a representação
        // dele. Evita a dança de foco entre quatro campos, que quebra colar e
        // apagar.
        //
        // O campo fica no fluxo normal, ocupando exatamente a área das casas,
        // apenas com texto e cursor transparentes. Escondê-lo dentro de um
        // Opacity(0) tirava o input do lugar onde o navegador acha que ele
        // está, e no iOS o Safari rolava a página atrás dele — foi o que fazia
        // o diálogo sumir ao tocar no PIN.
        SizedBox(
          height: 54,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Row(
                    children: List.generate(4, (i) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: i == 3 ? 0 : 8),
                            child: _casaPin(i, isDark),
                          ),
                        )),
                  ),
                ),
              ),
              TextField(
                controller: _controllerPin,
                focusNode: _focusPin,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                showCursor: false,
                enableInteractiveSelection: false,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.transparent, fontSize: 1),
                cursorColor: Colors.transparent,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: _onPinChanged,
                onSubmitted: (_) => _confirmar(),
              ),
            ],
          ),
        ),
        if (_erroPin != null) ...[
          const SizedBox(height: 10),
          _mensagemErro(_erroPin!),
        ],
      ],
    );
  }

  Widget _casaPin(int indice, bool isDark) {
    final valor = _controllerPin.text;
    final preenchido = indice < valor.length;
    final ativo = _focusPin.hasFocus && indice == valor.length;
    final temErro = _erroPin != null;

    final corBorda = temErro
        ? AppColors.red
        : ativo
            ? AppColors.accentLight
            : (isDark ? const Color(0xFF1E293B) : AppColors.lightBorder);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161E31) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: corBorda, width: ativo || temErro ? 1.6 : 1),
      ),
      child: preenchido
          ? Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: temErro ? AppColors.red : AppColors.accentLight,
              ),
            )
          : (ativo
              ? Container(
                  width: 2,
                  height: 22,
                  color: AppColors.accentLight.withValues(alpha: 0.8),
                )
              : const SizedBox.shrink()),
    );
  }

  // ── Rodapé ───────────────────────────────────────────────────────────────

  Widget _rodape(bool isDark) {
    final habilitado = !_processando && _nomeAtual.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: habilitado ? _confirmar : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor:
                    isDark ? const Color(0xFF1B2540) : const Color(0xFFE2E8F0),
                elevation: habilitado ? 2 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
              ),
              child: _processando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.novoTurno
                              ? Icons.play_arrow_rounded
                              : Icons.login_rounded,
                          size: 20,
                          color: habilitado
                              ? Colors.white
                              : (isDark
                                  ? AppColors.darkTextSec
                                  : AppColors.lightTextSec),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.novoTurno ? 'Abrir Turno' : 'Entrar',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: habilitado
                                ? Colors.white
                                : (isDark
                                    ? AppColors.darkTextSec
                                    : AppColors.lightTextSec),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (widget.novoTurno) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton.icon(
                onPressed: _processando
                    ? null
                    : () => Navigator.of(context).pop({'acao': 'historico'}),
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text(
                  'Histórico e reabrir turno',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
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
        ],
      ),
    );
  }

  // ── Peças reutilizadas ───────────────────────────────────────────────────

  Widget _rotulo(String texto, bool isDark) {
    return Text(
      texto,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.9,
        color: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
      ),
    );
  }

  Widget _mensagemErro(String texto) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline_rounded, size: 15, color: AppColors.red),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
