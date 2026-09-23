import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../dialogs/analytics_dialog.dart';
import '../dialogs/bloqueio_dialog.dart';
import '../dialogs/encerrantes_dialog.dart';
import '../dialogs/reset_dialog.dart';
import '../dialogs/trocar_pin_dialog.dart';
import '../dialogs/turnos_anteriores_dialog.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../services/auth_service.dart';
import '../services/csv_service.dart';
import '../services/database_service.dart';
import '../services/drive_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';
import '../utils/app_haptics.dart';
import '../widgets/cabecalho_turno.dart';
import '../widgets/janela.dart';
import 'consulta_produtos_screen.dart';
import 'gerencia/gestao_operadores_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Turno? turno;
  final TotaisTurno totais;
  final bool isDark;
  final ValueChanged<bool> onMudarTema;
  final VoidCallback onAbrirNovoTurno;
  final VoidCallback onAbrirResumo;
  final VoidCallback onRecarregar;
  final VoidCallback? onFechar;

  const SettingsScreen({
    super.key,
    required this.turno,
    required this.totais,
    required this.isDark,
    required this.onMudarTema,
    required this.onAbrirNovoTurno,
    required this.onAbrirResumo,
    required this.onRecarregar,
    this.onFechar,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool get isDark => widget.isDark;
  final _controllerPinMestre = TextEditingController();

  @override
  void dispose() {
    _controllerPinMestre.dispose();
    super.dispose();
  }

  void _abrirConsultaProdutos(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => const ConsultaProdutosScreen()),
    );
  }

  void _abrirEncerrantes(BuildContext context) {
    if (widget.turno == null) return;
    showDialog(
      context: context,
      builder: (ctx) => EncerrantesDialog(turnoId: widget.turno!.id!),
    );
  }

  void _abrirAnalytics(BuildContext context) {
    if (widget.turno == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AnalyticsDialog(turno: widget.turno!, totais: widget.totais),
    );
  }

  void _exportarCsv(BuildContext context) async {
    if (widget.turno == null) return;
    try {
      final db = DatabaseService.instance;
      final lancamentos = await db.obterLancamentos(widget.turno!.id!);
      await CsvService.exportarECompartilharCsv(
        turno: widget.turno!,
        totais: widget.totais,
        lancamentos: lancamentos,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar CSV: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  void _sincronizarDrive(BuildContext context) async {
    try {
      final res = await DriveService.sincronizarTodasPendencias();
      widget.onRecarregar();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.mensagem),
            backgroundColor: res.todosOk ? AppColors.green : AppColors.amber,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na sincronização: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  void _bloquearCaixa(BuildContext context) {
    if (widget.turno == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BloqueioDialog(operador: widget.turno!.operador),
    );
  }

  void _abrirTrocarPin(BuildContext context) {
    if (widget.turno == null) return;
    showDialog(
      context: context,
      builder: (ctx) => TrocarPinDialog(operador: widget.turno!.operador),
    );
  }

  void _abrirHistoricoTurnos(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => TurnosAnterioresDialog(
        onReabrirTurno: (turnoReaberto) async {
          final db = DatabaseService.instance;
          await db.reabrirTurno(turnoReaberto.id!);
          widget.onRecarregar();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🔓 Turno #${turnoReaberto.numero} reaberto com sucesso!'),
                backgroundColor: AppColors.green,
              ),
            );
          }
        },
      ),
    );
  }

  void _limparZerarTudo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ResetDialog(
        onResetConcluido: () {
          widget.onRecarregar();
          widget.onAbrirNovoTurno();
        },
      ),
    );
  }

  void _solicitarAcessoGerencia(BuildContext context) {
    _controllerPinMestre.clear();
    String? erroLocal;
    bool validandoLocal = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = widget.isDark;
            final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
            final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
            void entrar() => _validarEEntrarGerencia(
                  dialogCtx,
                  setDialogState,
                  (err) => erroLocal = err,
                  (v) => validandoLocal = v,
                );

            return AlertDialog(
              title: const CabecalhoJanela(
                icone: Icons.admin_panel_settings_rounded,
                cor: AppColors.amber,
                titulo: 'Desenvolvedor',
                subtitulo: 'Informe o PIN Mestre (4 dígitos)',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TextoJanela(
                    'Digite a senha administrativa para acessar o painel restrito de configurações e segurança:',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controllerPinMestre,
                    obscureText: true,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      fontSize: 24,
                      letterSpacing: 10,
                      fontWeight: FontWeight.w700,
                      color: textPri,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••',
                      counterText: '',
                      errorText: erroLocal,
                      filled: true,
                      fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        borderSide: BorderSide(color: borderCol),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        borderSide: BorderSide(color: borderCol),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => entrar(),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                BotoesJanela(
                  secundario: BotaoSecundario(texto: 'Cancelar', onPressed: () => Navigator.of(dialogCtx).pop()),
                  principal: BotaoPrincipal(
                    texto: 'Acessar Painel',
                    icone: Icons.lock_open_rounded,
                    cor: AppColors.amber,
                    ocupado: validandoLocal,
                    onPressed: validandoLocal ? null : entrar,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _validarEEntrarGerencia(
    BuildContext dialogCtx,
    StateSetter setDialogState,
    void Function(String?) setErro,
    void Function(bool) setValidando,
  ) async {
    final pin = _controllerPinMestre.text.trim();
    if (pin.length != 4) {
      setDialogState(() => setErro('Informe os 4 dígitos do PIN'));
      return;
    }
    setDialogState(() {
      setValidando(true);
      setErro(null);
    });

    final ok = await AuthService.validarPinGerente(pin);
    if (!dialogCtx.mounted) return;

    if (!ok) {
      AppHaptics.heavy();
      setDialogState(() {
        setValidando(false);
        setErro('PIN Mestre Incorreto!');
      });
      _controllerPinMestre.clear();
      return;
    }

    AppHaptics.light();
    Navigator.of(dialogCtx).pop();
    _controllerPinMestre.clear();

    if (mounted) {
      _abrirPainelGerencia(context);
    }
  }

  void _abrirPainelGerencia(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/gerencia'),
        builder: (ctx) => _PainelGerenciaPage(
          isDark: widget.isDark,
          turno: widget.turno,
          totais: widget.totais,
          onAlterarPinMestre: () => _abrirAlterarPinMestre(ctx),
          onGestaoOperadores: () => _abrirGestaoOperadores(ctx),
          onAnalytics: () => _abrirAnalytics(ctx),
          onExportarCsv: () => _exportarCsv(ctx),
          onLimparZerarTudo: () => _limparZerarTudo(ctx),
        ),
      ),
    );
  }

  Future<void> _abrirAlterarPinMestre(BuildContext context) async {
    final bool? alterou = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _AlterarPinMestreDialog(),
    );

    if (alterou == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ PIN Mestre do Desenvolvedor atualizado com sucesso!'),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  void _abrirGestaoOperadores(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/gestao-operadores'),
        builder: (ctx) => GestaoOperadoresScreen(isDark: widget.isDark),
      ),
    );
  }

  /// Entrada da área restrita, no mesmo lugar de sempre (topo do Menu), mas na
  /// linguagem dos outros itens: antes era um cartão âmbar inteiro, o elemento
  /// mais chamativo do Menu — justamente o que o frentista não usa.
  Widget _cardAreaGerencia(BuildContext context, bool isDark) {
    return _grupo(null, [
      _itemMenu(
        icon: Icons.admin_panel_settings_rounded,
        iconColor: AppColors.amber,
        titulo: 'Desenvolvedor',
        subtitulo: 'Configurações administrativas e segurança',
        fim: const SeloTurno(texto: 'Restrito', cor: AppColors.amber),
        onTap: () {
          AppHaptics.light();
          _solicitarAcessoGerencia(context);
        },
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    // Mesmo fundo das outras abas.
    final bgScaffold = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Scaffold(
      backgroundColor: bgScaffold,
      body: SafeArea(
        child: Column(
          children: [
            // ── Cabeçalho ──
            Container(
              color: surface,
              padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Menu',
                          style: TextStyle(fontSize: AppTexto.valor, fontWeight: FontWeight.w700, color: textPri),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Operações do caixa e atalhos',
                          style: TextStyle(fontSize: AppTexto.rotulo, color: textSec),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onFechar != null)
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: textSec),
                      tooltip: 'Fechar',
                      onPressed: widget.onFechar,
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: borderCol),

            // ── Opções ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                children: [
                  _cardAreaGerencia(context, isDark),

                  _grupo('Operações do caixa', [
                    _itemMenu(
                      icon: Icons.local_gas_station_rounded,
                      iconColor: AppColors.amber,
                      titulo: 'Encerrantes de Bombas',
                      subtitulo: 'Conferência de litros vendidos nos bicos',
                      onTap: () => _abrirEncerrantes(context),
                    ),
                    _itemMenu(
                      icon: Icons.shopping_bag_rounded,
                      iconColor: AppColors.accentLight,
                      titulo: 'Tabela de Códigos / Produtos',
                      subtitulo: 'Consulta rápida por código ou nome do produto',
                      onTap: () => _abrirConsultaProdutos(context),
                    ),
                    _itemMenu(
                      icon: Icons.lock_rounded,
                      iconColor: AppColors.accent,
                      titulo: 'Bloquear Caixa',
                      subtitulo: 'Travar tela por ausência do operador',
                      onTap: () => _bloquearCaixa(context),
                    ),
                    _itemMenu(
                      icon: Icons.cloud_sync_rounded,
                      iconColor: AppColors.green,
                      titulo: 'Sincronizar com Google Drive',
                      subtitulo: 'Forçar reenvio de relatórios pendentes na fila',
                      onTap: () => _sincronizarDrive(context),
                    ),
                    _itemMenu(
                      icon: Icons.password_rounded,
                      iconColor: AppColors.accentLight,
                      titulo: 'Alterar Meu PIN',
                      subtitulo: 'Atualizar senha individual do operador ${widget.turno?.operador ?? ""}',
                      onTap: () => _abrirTrocarPin(context),
                    ),
                  ]),

                  _grupo('Atalhos e aplicativo', [
                    _itemMenu(
                      icon: Icons.bar_chart_rounded,
                      iconColor: AppColors.indigo,
                      titulo: 'Fechar Caixa & Resumo',
                      subtitulo: 'Conferir totais, conciliação e encerrar',
                      onTap: widget.onAbrirResumo,
                    ),
                    _itemMenu(
                      icon: Icons.history_rounded,
                      iconColor: AppColors.blue,
                      titulo: 'Histórico de Turnos',
                      subtitulo: 'Consultar ou reabrir turnos anteriores',
                      onTap: () => _abrirHistoricoTurnos(context),
                    ),
                    _itemMenu(
                      icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      iconColor: isDark ? AppColors.amber2 : AppColors.accent,
                      titulo: isDark ? 'Ativar Tema Claro' : 'Ativar Tema Escuro',
                      subtitulo: isDark ? 'Mudar interface para fundo claro' : 'Mudar interface para modo noturno',
                      onTap: () => widget.onMudarTema(!isDark),
                    ),
                    _itemMenu(
                      icon: Icons.vibration_rounded,
                      iconColor: AppHaptics.habilitado ? AppColors.green : textSec,
                      titulo: AppHaptics.habilitado ? 'Vibração: Suave (Ativa)' : 'Vibração: Desativada',
                      subtitulo: AppHaptics.habilitado
                          ? 'Feedback tátil calibrado bem suave ao tocar'
                          : 'Toque para reativar o feedback tátil suave',
                      onTap: () async {
                        await AppHaptics.setHabilitado(!AppHaptics.habilitado);
                        if (AppHaptics.habilitado) {
                          AppHaptics.light();
                        }
                        if (mounted) setState(() {});
                      },
                    ),
                    _itemMenu(
                      icon: Icons.person_outline_rounded,
                      iconColor: AppColors.orange,
                      titulo: 'Trocar / Sair do Operador',
                      subtitulo: 'Voltar ao login sem fechar o turno',
                      onTap: widget.onAbrirNovoTurno,
                    ),
                  ]),

                  if (widget.onFechar != null)
                    Center(
                      child: TextButton(
                        onPressed: widget.onFechar,
                        child: const Text(
                          'Voltar ao Caixa',
                          style: TextStyle(
                            color: AppColors.accentLight,
                            fontSize: AppTexto.corpo,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grupo(String? titulo, List<Widget> itens) => _grupoMenu(isDark, titulo, itens);

  Widget _itemMenu({
    required IconData icon,
    required Color iconColor,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
    Widget? fim,
  }) =>
      _itemMenuDe(
        isDark,
        icon: icon,
        iconColor: iconColor,
        titulo: titulo,
        subtitulo: subtitulo,
        onTap: onTap,
        fim: fim,
      );
}

/// Um grupo do Menu: título em caixa alta e os itens num cartão só,
/// separados por fio — a mesma forma dos blocos do Resumo. Serve ao Menu e ao
/// painel do desenvolvedor.
Widget _grupoMenu(bool isDark, String? titulo, List<Widget> itens) {
  final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
  final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
  final textTer = isDark ? AppColors.darkTextTer : AppColors.lightTextTer;

  final linhas = <Widget>[];
  for (var i = 0; i < itens.length; i++) {
    // O fio comeca depois do icone, como nas listas do sistema.
    if (i > 0) linhas.add(Divider(height: 1, thickness: 1, indent: 64, color: borderCol));
    linhas.add(itens[i]);
  }

  return Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (titulo != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              titulo.toUpperCase(),
              style: TextStyle(
                fontSize: AppTexto.rotulo,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: textTer,
              ),
            ),
          ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppColors.radiusLg),
            border: Border.all(color: borderCol),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: linhas),
          ),
        ),
      ],
    ),
  );
}

/// Um item do Menu: ícone na cor da função, título, uma linha de apoio e a
/// seta (ou outro sinal no fim, como o selo "Restrito" ou um interruptor).
/// [corTitulo] pinta o título quando o item pede atenção (zerar tudo, modo
/// teste ligado).
Widget _itemMenuDe(
  bool isDark, {
  required IconData icon,
  required Color iconColor,
  required String titulo,
  required String subtitulo,
  required VoidCallback? onTap,
  Widget? fim,
  Color? corTitulo,
}) {
  final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
  final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
  final textTer = isDark ? AppColors.darkTextTer : AppColors.lightTextTer;

  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.16 : 0.12),
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(fontSize: AppTexto.corpo, fontWeight: FontWeight.w700, color: corTitulo ?? textPri),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: TextStyle(fontSize: AppTexto.rotulo, color: textSec),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          fim ?? Icon(Icons.chevron_right_rounded, color: textTer, size: 20),
        ],
      ),
    ),
  );
}

class _PainelGerenciaPage extends StatefulWidget {
  final bool isDark;
  final Turno? turno;
  final TotaisTurno totais;
  final VoidCallback onAlterarPinMestre;
  final VoidCallback onGestaoOperadores;
  final VoidCallback onAnalytics;
  final VoidCallback onExportarCsv;
  final VoidCallback onLimparZerarTudo;

  const _PainelGerenciaPage({
    required this.isDark,
    required this.turno,
    required this.totais,
    required this.onAlterarPinMestre,
    required this.onGestaoOperadores,
    required this.onAnalytics,
    required this.onExportarCsv,
    required this.onLimparZerarTudo,
  });

  @override
  State<_PainelGerenciaPage> createState() => _PainelGerenciaPageState();
}

class _PainelGerenciaPageState extends State<_PainelGerenciaPage> {
  bool _pinEhPadrao = false;

  @override
  void initState() {
    super.initState();
    _checarPinPadrao();
  }

  void _checarPinPadrao() async {
    final ehPadrao = await AuthService.pinGerenteEhPadrao();
    if (mounted) {
      setState(() => _pinEhPadrao = ehPadrao);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgScaffold = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: bgScaffold,
        appBar: AppBar(
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textPri),
            tooltip: 'Voltar',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Desenvolvedor',
                    style: TextStyle(fontSize: AppTexto.valor, fontWeight: FontWeight.w700, color: textPri),
                  ),
                  const SizedBox(width: 8),
                  const SeloTurno(texto: 'Restrito', cor: AppColors.amber),
                ],
              ),
              Text(
                'Configurações administrativas e segurança',
                style: TextStyle(fontSize: AppTexto.rotulo, color: textSec, fontWeight: FontWeight.normal),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: borderCol),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          children: [
            // 0. Cobra a troca do PIN Mestre enquanto ele for o padrão de fábrica
            if (_pinEhPadrao) ...[
              const AvisoJanela(
                cor: AppColors.red,
                icone: Icons.gpp_maybe_rounded,
                titulo: 'PIN Mestre ainda é o de fábrica',
                texto: 'O PIN mestre abre qualquer turno e libera qualquer operação. '
                    'Troque agora para um valor que só o desenvolvedor conheça.',
              ),
              const SizedBox(height: 16),
            ],

            _grupoMenu(isDark, 'Segurança', [
              _itemMenuDe(
                isDark,
                icon: Icons.key_rounded,
                iconColor: AppColors.amber,
                titulo: 'Alterar PIN Mestre do Desenvolvedor',
                subtitulo: 'Modificar a senha administrativa mestre (PBKDF2 com sal)',
                onTap: () async {
                  widget.onAlterarPinMestre();
                  _checarPinPadrao();
                },
              ),
              _itemMenuDe(
                isDark,
                icon: Icons.badge_rounded,
                iconColor: AppColors.accentLight,
                titulo: 'Gestão de Operadores & Senhas',
                subtitulo: 'Visualizar operadores cadastrados e redefinir PINs',
                onTap: widget.onGestaoOperadores,
              ),
            ]),

            _grupoMenu(isDark, 'Dados e relatórios', [
              _itemMenuDe(
                isDark,
                icon: Icons.auto_graph_rounded,
                iconColor: AppColors.purple,
                titulo: 'Analytics & Desempenho',
                subtitulo: 'Gráficos de vendas, ticket médio e formas de pagamento',
                onTap: widget.onAnalytics,
              ),
              _itemMenuDe(
                isDark,
                icon: Icons.table_chart_rounded,
                iconColor: AppColors.green,
                titulo: 'Exportar Planilha Excel (CSV)',
                subtitulo: 'Salvar ou compartilhar dados estruturados',
                onTap: widget.onExportarCsv,
              ),
              // Modo Teste / Simulação: só o interruptor liga e desliga.
              ValueListenableBuilder<bool>(
                valueListenable: DriveService.modoTesteNotifier,
                builder: (context, modoTeste, _) => _itemMenuDe(
                  isDark,
                  icon: Icons.science_outlined,
                  iconColor: AppColors.amber,
                  titulo: modoTeste ? 'Modo Teste / Simulação (ligado)' : 'Modo Teste / Simulação',
                  subtitulo: 'Envia os relatórios para a pasta de homologação no Drive',
                  corTitulo: modoTeste ? AppColors.amber : null,
                  onTap: null,
                  fim: Switch(
                    value: modoTeste,
                    activeThumbColor: AppColors.amber,
                    onChanged: (novoValor) async {
                      await DriveService.setModoTeste(novoValor);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              novoValor
                                  ? '🧪 Modo Teste ativado! Relatórios irão para a homologação.'
                                  : '✅ Modo Teste desativado. Relatórios irão para a pasta oficial.',
                            ),
                            backgroundColor: novoValor ? AppColors.amber : AppColors.green,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ]),

            _grupoMenu(isDark, 'Zona de perigo', [
              _itemMenuDe(
                isDark,
                icon: Icons.delete_forever_rounded,
                iconColor: AppColors.red,
                titulo: 'Limpar / Zerar Tudo',
                subtitulo: 'Reset completo e irreversível dos dados locais',
                corTitulo: AppColors.red,
                onTap: widget.onLimparZerarTudo,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Troca do PIN Mestre. Com estado próprio, os campos só são descartados
/// quando a janela sai de vez.
class _AlterarPinMestreDialog extends StatefulWidget {
  const _AlterarPinMestreDialog();

  @override
  State<_AlterarPinMestreDialog> createState() => _AlterarPinMestreDialogState();
}

class _AlterarPinMestreDialogState extends State<_AlterarPinMestreDialog> {
  final _novo = TextEditingController();
  final _confirma = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _novo.dispose();
    _confirma.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final p1 = _novo.text.trim();
    final p2 = _confirma.text.trim();
    if (p1.length != 4 || p2.length != 4) {
      setState(() => _erro = 'Ambos devem ter 4 dígitos');
      return;
    }
    if (p1 != p2) {
      setState(() => _erro = 'Os PINs não conferem!');
      return;
    }
    await AuthService.alterarPinGerente(p1);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;

    InputDecoration campo(String rotulo, {String? erro}) => InputDecoration(
          labelText: rotulo,
          hintText: '••••',
          counterText: '',
          errorText: erro,
          filled: true,
          fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
        );
    final estiloPin = TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.w700, color: textPri);

    return AlertDialog(
      title: const CabecalhoJanela(
        icone: Icons.key_rounded,
        cor: AppColors.amber,
        titulo: 'Alterar PIN Mestre',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TextoJanela(
            'Defina um novo PIN Mestre de 4 dígitos para o desenvolvedor (armazenado como hash PBKDF2 com sal):',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _novo,
            obscureText: true,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: estiloPin,
            decoration: campo('Novo PIN (4 dígitos)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirma,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: estiloPin,
            decoration: campo('Confirmar Novo PIN', erro: _erro),
            onSubmitted: (_) => _salvar(),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        BotoesJanela(
          secundario: BotaoSecundario(texto: 'Cancelar', onPressed: () => Navigator.of(context).pop(false)),
          principal: BotaoPrincipal(texto: 'Salvar PIN Mestre', cor: AppColors.amber, onPressed: _salvar),
        ),
      ],
    );
  }
}
