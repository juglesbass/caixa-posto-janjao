import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dialogs/quick_launch_modal.dart';
import 'dialogs/turnos_anteriores_dialog.dart';
import 'models/totais_turno.dart';
import 'models/turno.dart';
import 'screens/history_screen.dart';
import 'screens/identificacao_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/summary_screen.dart';
import 'screens/validar_screen.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/drive_service.dart';
import 'services/notification_service.dart';
import 'services/operadores_sync_service.dart';
import 'firebase_options.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'utils/app_haptics.dart';
import 'utils/app_pronto.dart';
import 'utils/payment_types.dart';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/pending_sync_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Trava a orientação em modo retrato para melhor usabilidade de caixa
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Preferência tátil: leitura barata, e é consultada já no primeiro toque.
  await AppHaptics.inicializar();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[App Error] ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[Platform Error] $error');
    return true;
  };

  runApp(const CaixaPostoJanjaoApp());

  // O que não é pré-requisito para desenhar a primeira tela sobe depois dela.
  //
  // `NotificationService.inicializar()` era aguardado antes do `runApp`, e é ele
  // quem abre o banco: no PWA isso significa baixar e compilar o `sqlite3.wasm`,
  // criar tabelas e rodar migrações — tudo antes de o Flutter pintar um único
  // frame, com o usuário parado no spinner do HTML. Em iPhone mais fraco essa
  // era boa parte da demora da abertura. Agora a identificação aparece primeiro
  // e o banco abre em seguida.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_aquecerServicos());
  });
}

/// Sobe os serviços que a primeira tela não precisa esperar.
///
/// Cada etapa é isolada: notificação indisponível (permissão negada, navegador
/// sem suporte) não pode impedir o Firestore de sincronizar, e vice-versa.
Future<void> _aquecerServicos() async {
  try {
    await NotificationService.inicializar();
  } catch (e) {
    debugPrint('[Init] Notificações indisponíveis: $e');
  }

  try {
    await DriveService.inicializarModoTeste();
  } catch (e) {
    debugPrint('[Init] Modo Teste indisponível: $e');
  }

  debugPrint('[Firebase Diagnostic] Plataforma ativa: ${kIsWeb ? "Web (PWA)" : defaultTargetPlatform.name}');
  debugPrint('[Firebase Diagnostic] Projeto Firestore: ${DefaultFirebaseOptions.defaultProjectId}');
  try {
    final ops = await OperadoresSyncService.obterOperadores(sincronizarNuvem: true);
    debugPrint('[Firebase Diagnostic] Inicialização concluída. ${ops.length} operadores carregados.');
    // Migra automaticamente operadores já cadastrados anteriormente para o Firestore
    await OperadoresSyncService.migrarOperadoresLocaisParaFirestore();
  } catch (e) {
    debugPrint('[Firebase Diagnostic] Conexão em segundo plano: $e');
  }

  // Pré-carregamento do PDF por último, e com folga.
  //
  // Ele precisa acontecer antes do primeiro fechamento de turno, para que isso
  // não dependa de sinal. Mas com cache vazio é baixar e COMPILAR algumas
  // centenas de KB de JavaScript, e compilar é trabalho na mesma thread que
  // recebe os toques. Rodando junto da abertura, isso pegava o operador no meio
  // dos primeiros toques nos menus e parecia app travado. Para um fechamento que
  // vem minutos ou horas depois, esta espera não custa nada.
  await Future<void>.delayed(const Duration(seconds: 12));
  await DriveService.aquecerPdf();
}

class CaixaPostoJanjaoApp extends StatefulWidget {
  const CaixaPostoJanjaoApp({super.key});

  @override
  State<CaixaPostoJanjaoApp> createState() => _CaixaPostoJanjaoAppState();
}

class _CaixaPostoJanjaoAppState extends State<CaixaPostoJanjaoApp> {
  bool _isDark = true;
  late final Map<String, String> _parametrosValidacao;

  @override
  void initState() {
    super.initState();
    _carregarTema();
    _parametrosValidacao = Uri.base.queryParameters;
  }

  void _carregarTema() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isDark = prefs.getBool('tema_escuro') ?? true;
    });
  }

  void _mudarTema(bool escuro) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tema_escuro', escuro);
    if (!mounted) return;
    setState(() {
      _isDark = escuro;
    });
  }

  String _obterRotaInicial() {
    final fragment = Uri.base.fragment;
    if (fragment.contains('validar')) {
      return fragment.startsWith('/') ? fragment : '/$fragment';
    }
    if (Uri.base.path.contains('validar') ||
        Uri.base.queryParameters.containsKey('auth')) {
      final query = Uri.base.query;
      return query.isNotEmpty ? '/validar?$query' : '/validar';
    }
    return '/';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caixa Posto Janjão',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      builder: (context, child) {
        // Tanto no iOS quanto no Android e Web, qualquer toque fora de um campo recolhe o teclado imediatamente
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: _obterRotaInicial(),
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');

        // Tratamento da rota pública de validação (/validar ou #/validar)
        if (uri.path == '/validar' ||
            uri.path == 'validar' ||
            (settings.name?.contains('validar') ?? false)) {
          final auth = uri.queryParameters['auth'] ??
              Uri.base.queryParameters['auth'] ??
              _parametrosValidacao['auth'];

          return MaterialPageRoute(
            settings: settings,
            builder: (_) => ValidarScreen(
              authHash: auth,
              operadorFallback: uri.queryParameters['op'] ??
                  Uri.base.queryParameters['op'] ??
                  _parametrosValidacao['op'],
              turnoFallback: uri.queryParameters['turno'] ??
                  Uri.base.queryParameters['turno'] ??
                  _parametrosValidacao['turno'],
              totalFallback: uri.queryParameters['total'] ??
                  Uri.base.queryParameters['total'] ??
                  _parametrosValidacao['total'],
              dataFallback: uri.queryParameters['data'] ??
                  Uri.base.queryParameters['data'] ??
                  _parametrosValidacao['data'],
            ),
          );
        }

        // Rota padrão do sistema
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => MainShell(
            isDark: _isDark,
            onMudarTema: _mudarTema,
          ),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onMudarTema;

  const MainShell({
    super.key,
    required this.isDark,
    required this.onMudarTema,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _indiceAba = 0;
  Turno? _turnoAtual;
  TotaisTurno _totais = TotaisTurno();
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inicializarApp();
    _tentarSincronizarFilaInicial();
    DatabaseService.lancamentosNotifier.addListener(_recarregarDados);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DatabaseService.lancamentosNotifier.removeListener(_recarregarDados);
    super.dispose();
  }

  /// O caso mais comum de PDF preso na fila é fechar o turno sem sinal, guardar
  /// o celular e voltar depois já com internet. Sem este gancho, nada tentava de
  /// novo até o app ser reaberto do zero — o fechamento ficava parado no
  /// aparelho, fora da pasta do gerente, sem ninguém perceber.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final emPrimeiroPlano = state == AppLifecycleState.resumed;
    OperadoresSyncService.definirAppEmPrimeiroPlano(emPrimeiroPlano);

    if (!emPrimeiroPlano) return;

    unawaited(_sincronizarAoRetomar());
  }

  Future<void> _sincronizarAoRetomar() async {
    try {
      await DriveService.sincronizarTodasPendencias(respeitarBackoff: true);
    } catch (_) {}
    try {
      await NotificationService.atualizarPendencias();
    } catch (_) {}
    if (mounted) await _recarregarDados();
  }

  /// Reenvio automático da fila do Drive na abertura.
  ///
  /// A espera é longa de propósito: dois segundos caíam exatamente sobre a tela
  /// de identificação, e no PWA a varredura da fila roda no mesmo thread que
  /// desenha e que recebe os toques — era o operador digitando o PIN justamente
  /// enquanto isso acontecia. Para um PDF preso na fila desde o turno anterior,
  /// alguns segundos a mais não mudam nada.
  void _tentarSincronizarFilaInicial() async {
    try {
      await Future.delayed(const Duration(seconds: 8));
      await DriveService.sincronizarTodasPendencias(respeitarBackoff: true);
    } catch (_) {}
  }

  Future<void> _inicializarApp() async {
    setState(() => _carregando = true);
    try {
      final db = DatabaseService.instance;
      final turnoAberto = await db.obterTurnoAberto();
      await NotificationService.atualizarPendencias();

      if (!mounted) return;

      if (turnoAberto == null) {
        // Sem rota empurrada: o build já mostra a identificação como conteúdo.
        // Empurrar por cima causava um flash da tela anterior na abertura, e
        // ela continuava montada por trás.
        setState(() {
          _turnoAtual = null;
          _carregando = false;
        });
      } else {
        final totais = await db.obterTotaisTurno(turnoAberto.id!);
        if (!mounted) return;
        setState(() {
          _turnoAtual = turnoAberto;
          _totais = totais;
          _carregando = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Aviso ao inicializar app: $e\n$stack');
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _recarregarDados() async {
    final db = DatabaseService.instance;
    final turnoAtualizado = await db.obterTurnoAberto();
    await NotificationService.atualizarPendencias();

    if (!mounted) return;

    if (turnoAtualizado == null) {
      setState(() {
        _turnoAtual = null;
      });
      return;
    }

    final totais = await db.obterTotaisTurno(turnoAtualizado.id!);
    if (!mounted) return;
    setState(() {
      _turnoAtual = turnoAtualizado;
      _totais = totais;
    });
  }

  /// Abre a identificação por cima da tela atual. Usado quando já existe turno
  /// aberto (ex.: trocar de operador pelo Menu). Sem turno, a identificação é a
  /// própria tela — ver o build.
  void _solicitarIdentificacao({required bool novoTurno}) async {
    if (!mounted) return;

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => IdentificacaoScreen(novoTurno: novoTurno),
      ),
    );

    if (!mounted) return;
    _processarIdentificacao(result);
  }

  void _processarIdentificacao(Map<String, dynamic>? result) async {
    final db = DatabaseService.instance;

    if (result != null) {
      if (result['acao'] == 'historico') {
        showDialog(
          context: context,
          builder: (ctx) => TurnosAnterioresDialog(
            onReabrirTurno: (turnoReaberto) async {
              final db = DatabaseService.instance;
              await db.reabrirTurno(turnoReaberto.id!);
              await _inicializarApp();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🔓 Turno #${turnoReaberto.numero} (${turnoReaberto.operador}) reaberto com sucesso!'),
                    backgroundColor: AppColors.green,
                  ),
                );
              }
            },
          ),
        );
        return;
      }

      final operador = result['operador'] as String;
      final fundo = (result['fundoCaixa'] as num?)?.toDouble() ?? 0.0;

      // Já existe turno aberto: quem chegou aqui veio do "Trocar / Sair do
      // Operador", que manda para a tela de login sem fechar nada.
      //
      // Antes, este caminho caía direto no abrirNovoTurno abaixo — e ele fecha
      // qualquer turno aberto. O operador saía, entrava de novo com o próprio
      // nome, e encontrava o caixa zerado: o turno dele tinha sido fechado sem
      // relatório e substituído por um vazio. O botão até promete o contrário,
      // no subtítulo: "Manter turno aberto e desconectar usuário".
      final turnoAberto = _turnoAtual;
      if (turnoAberto != null) {
        final mesmoOperador =
            AuthService.normalizarOperador(turnoAberto.operador) ==
                AuthService.normalizarOperador(operador);

        // Voltou quem já estava: nada muda, o turno continua o mesmo.
        if (mesmoOperador) {
          if (!mounted) return;
          setState(() => _indiceAba = 0);
          return;
        }

        // Outra pessoa assumindo. Aí o turno de quem estava é mesmo fechado —
        // mas isso precisa ser escolha declarada, não efeito colateral.
        final confirmou = await _confirmarTrocaDeOperador(turnoAberto, operador);
        if (!confirmou || !mounted) return;
      }

      // Novo turno sempre inicia com a máquina Rede por padrão
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('maquina_ativa', PaymentTypes.maquinaRede);
      } catch (_) {}

      final novoTurnoObj = await db.abrirNovoTurno(operador, fundoCaixa: fundo);
      final totais = await db.obterTotaisTurno(novoTurnoObj.id!);

      // Momento certo de pedir notificação: o operador acabou de agir e vai
      // querer ser avisado se o PDF do fechamento ficar preso na fila.
      unawaited(NotificationService.solicitarPermissao());

      if (!mounted) return;

      setState(() {
        _turnoAtual = novoTurnoObj;
        _totais = totais;
        _indiceAba = 0;
      });
    }
  }

  /// Confirma a passagem do caixa para outro operador.
  ///
  /// Trocar de operador fecha o turno de quem estava, e esse fechamento não gera
  /// relatório nem envia nada ao Drive — é um fechamento sem prestação de
  /// contas. Por isso o aviso diz o número do turno, o nome de quem está nele e
  /// aponta o caminho certo para encerrar de verdade.
  Future<bool> _confirmarTrocaDeOperador(
    Turno turnoAberto,
    String novoOperador,
  ) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fechar o turno atual?'),
        content: Text(
          'O turno #${turnoAberto.numero} está aberto no nome de '
          '${turnoAberto.operador}.\n\n'
          'Entrar como $novoOperador fecha esse turno e abre um novo, vazio. '
          'Esse fechamento não gera relatório nem envia nada ao Google Drive.\n\n'
          'Para encerrar com relatório, use "Fechar Caixa & Resumo".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Fechar e trocar'),
          ),
        ],
      ),
    );
    return confirmou == true;
  }

  void _abrirLancamentoRapido() async {
    if (_turnoAtual == null) return;

    String maquinaAtiva = PaymentTypes.maquinaRede;
    try {
      final prefs = await SharedPreferences.getInstance();
      maquinaAtiva = prefs.getString('maquina_ativa') ?? PaymentTypes.maquinaRede;
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDark ? AppColors.darkSheetBg : AppColors.lightSheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.radiusXl)),
      ),
      builder: (ctx) => QuickLaunchModal(
        maquinaAtiva: maquinaAtiva,
        onLancar: (dados) async {
          final db = DatabaseService.instance;
          await db.inserirLancamento(
            _turnoAtual!.id!,
            dados.tipo,
            dados.valor,
            dados.descricao,
          );
          _recarregarDados();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      // No PWA o carregador do index.html continua na tela até [sinalizarAppPronto]
      // abaixo, então uma rodinha aqui seria a segunda, desenhada por baixo da
      // primeira. No celular não há carregador de HTML, e aí ela é necessária.
      if (kIsWeb) return const Scaffold(body: SizedBox.expand());
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentLight),
        ),
      );
    }

    // Daqui para baixo já existe tela de verdade. Fica no build, e não no fim de
    // _inicializarApp, para valer também no caminho de erro: qualquer coisa que
    // resulte em conteúdo desenhado esconde o carregador.
    sinalizarAppPronto();

    // Sem turno aberto, a identificação É a tela — não uma rota por cima.
    // A antiga "Nenhum Turno Aberto" só repetia os dois botões que esta tela
    // já oferece, e ficava montada por trás depois do push.
    if (_turnoAtual == null) {
      return IdentificacaoScreen(
        novoTurno: true,
        isDark: widget.isDark,
        onMudarTema: widget.onMudarTema,
        banner: PendingSyncBanner(onSincronizado: _inicializarApp),
        onResultado: _processarIdentificacao,
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _indiceAba,
        children: [
          // Aba 0: Início
          HomeScreen(
            turno: _turnoAtual!,
            totais: _totais,
            onRecarregar: _recarregarDados,
            onAbrirResumo: () => setState(() => _indiceAba = 2),
            onMudarTema: widget.onMudarTema,
          ),

          // Aba 1: Histórico
          HistoryScreen(
            turno: _turnoAtual!,
            onAtualizado: _recarregarDados,
            ativo: _indiceAba == 1,
          ),

          // Aba 2: Resumo
          SummaryScreen(
            turno: _turnoAtual!,
            totais: _totais,
            onTurnoAlterado: _inicializarApp,
            onFechar: () => setState(() => _indiceAba = 0),
          ),

          // Aba 3: Menu / Ações do Caixa
          SettingsScreen(
            turno: _turnoAtual,
            totais: _totais,
            isDark: widget.isDark,
            onMudarTema: widget.onMudarTema,
            onAbrirNovoTurno: () => _solicitarIdentificacao(novoTurno: true),
            onAbrirResumo: () => setState(() => _indiceAba = 2),
            onRecarregar: _recarregarDados,
            onFechar: () => setState(() => _indiceAba = 0),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        indiceAtual: _indiceAba,
        onTrocarAba: (i) {
          setState(() => _indiceAba = i);
          _recarregarDados();
        },
        onAbrirLancamentoRapido: _abrirLancamentoRapido,
      ),
    );
  }
}
