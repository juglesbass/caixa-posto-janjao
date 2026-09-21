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
import 'utils/data_caixa.dart';
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
  Timer? _timerFila;
  bool _conferindoCaixaAntigo = false;
  final Set<int> _avisosCaixaAntigoMostrados = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inicializarApp();
    _tentarSincronizarFilaInicial();
    _iniciarTimerFila();
    DatabaseService.lancamentosNotifier.addListener(_recarregarDados);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerFila?.cancel();
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

    if (!emPrimeiroPlano) {
      _timerFila?.cancel();
      _timerFila = null;
      return;
    }

    _iniciarTimerFila();
    unawaited(_sincronizarAoRetomar());
  }

  /// Confere a fila do Drive de tempos em tempos enquanto o app está aberto.
  ///
  /// Antes a fila só tentava de novo ao abrir o app ou ao voltar do segundo
  /// plano: com o caixa aberto na tela o dia inteiro, um PDF pendente esperava
  /// alguém sair e voltar. Sem pendência, cada tique só lê um número em memória
  /// — não toca no banco nem na rede —, então não pesa no celular mais fraco.
  /// Com pendência, a própria fila respeita o backoff.
  void _iniciarTimerFila() {
    _timerFila?.cancel();
    _timerFila = Timer.periodic(const Duration(minutes: 3), (_) async {
      // Só compara a data do caixa em memória; nada de banco ou rede enquanto o
      // caixa for de hoje.
      unawaited(_conferirCaixaDeDiaAnterior());
      if (NotificationService.pendenciasCount.value <= 0) return;
      try {
        await DriveService.sincronizarTodasPendencias(respeitarBackoff: true);
      } catch (_) {}
    });
  }

  Future<void> _sincronizarAoRetomar() async {
    // Primeiro, antes da fila: quem volta ao app dias depois precisa da data
    // certa na hora, e não depois de uma rodada de envios.
    unawaited(_conferirCaixaDeDiaAnterior());
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_conferirCaixaDeDiaAnterior());
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

      // Caixa aberto de madrugada pode ser do dia anterior: pergunta.
      final dataCaixa = await _escolherDataCaixa();
      if (!mounted) return;

      final novoTurnoObj = await db.abrirNovoTurno(
        operador,
        fundoCaixa: fundo,
        dataCaixa: dataCaixa,
      );
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

  /// Caixa ainda aberto de um dia anterior, depois das 6h: corrige a data
  /// sozinho quando dá para ter certeza, e só avisa quando não dá.
  ///
  /// O caso: o funcionário do dia trabalha um dia sim, um não. Fecha o caixa no
  /// dia 15, abre o app de novo no mesmo dia — e se identificar já abre um
  /// turno — e deixa assim até o dia 17. O caixa usado no dia 17 ficava datado
  /// do dia 15, e o PDF chegava ao gerente com a data errada.
  ///
  /// Quem decide é o movimento registrado (ver DataCaixa.decidirCaixaAberto):
  /// sem movimento, o caixa recomeça hoje; com lançamentos só de hoje, a data
  /// vira hoje; com lançamentos de um dia anterior pode ser o caixa daquele dia
  /// esquecido aberto, e trocar a data mandaria as vendas dele para hoje — então
  /// só avisa. De madrugada não faz nada: vale a regra das 00h às 06h.
  ///
  /// Enquanto o caixa for de hoje, só compara uma data em memória.
  Future<void> _conferirCaixaDeDiaAnterior() async {
    final turno = _turnoAtual;
    final turnoId = turno?.id;
    if (turno == null || turnoId == null || _conferindoCaixaAntigo || !mounted) return;
    if (!DataCaixa.caixaDeDiaAnterior(turno.dataCaixa, DateTime.now())) return;

    // Nunca no meio de outra janela (fechamento de caixa, identificação) nem de
    // um envio ao Drive: trocar a data ali deixaria o PDF com um dia e o banco
    // com outro. A próxima conferência pega.
    final rota = ModalRoute.of(context);
    if (rota != null && !rota.isCurrent) return;
    if (DatabaseService.enviosDriveEmCurso.isNotEmpty) return;

    _conferindoCaixaAntigo = true;
    try {
      final db = DatabaseService.instance;
      final lancamentos = await db.obterLancamentos(turnoId);
      final encerrantes = await db.obterEncerrantes(turnoId);
      final agora = DateTime.now();
      final hoje = DataCaixa.formatar(agora);

      final acao = DataCaixa.decidirCaixaAberto(
        dataAbertura: turno.data,
        dataCaixa: turno.dataCaixa,
        datasHoraLancamentos: lancamentos.map((l) => l.dataHora),
        temEncerrantes: encerrantes.isNotEmpty,
        agora: agora,
      );

      switch (acao) {
        case AcaoCaixaAntigo.nenhuma:
          return;

        case AcaoCaixaAntigo.recomecar:
        case AcaoCaixaAntigo.mudarParaHoje:
          // recomecarCaixaVazio confere de novo, na transação, que o caixa
          // continua vazio: se entrou um lançamento no meio, não recomeça e a
          // próxima conferência só troca a data.
          final alterou = acao == AcaoCaixaAntigo.recomecar
              ? await db.recomecarCaixaVazio(turnoId)
              : await db.alterarDataCaixa(turnoId, hoje);
          if (!alterou || !mounted) return;
          await _recarregarDados();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Data do caixa atualizada para hoje, ${DataCaixa.curta(hoje)}.'),
              backgroundColor: AppColors.green,
            ),
          );

        case AcaoCaixaAntigo.avisarCaixaAntigo:
          // Uma vez por turno enquanto o app estiver aberto: lembrar a cada 3
          // minutos atrapalharia o trabalho.
          if (_avisosCaixaAntigoMostrados.contains(turnoId)) return;
          _avisosCaixaAntigoMostrados.add(turnoId);
          final irParaResumo = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Caixa de outro dia ainda aberto'),
              content: Text(
                'Este caixa é do dia ${turno.dataCaixa} e continua aberto, com '
                'movimento registrado.\n\n'
                'A data não foi trocada sozinha porque as vendas podem ser daquele '
                'dia. Se este caixa já terminou, feche pelo Resumo. Se ele é mesmo '
                'o de hoje, use "trocar" no Resumo.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Agora não'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Ir para o Resumo'),
                ),
              ],
            ),
          );
          if (irParaResumo == true && mounted) {
            setState(() => _indiceAba = 2);
          }
      }
    } catch (e) {
      debugPrint('[Caixa] Conferência do caixa $turnoId falhou: $e');
    } finally {
      _conferindoCaixaAntigo = false;
    }
  }

  /// De qual dia é o caixa que está sendo aberto.
  ///
  /// Fora da madrugada é o dia de hoje, sem perguntar nada. Entre 00h e 06h o
  /// app pergunta: o funcionário da noite fecha um caixa até a meia-noite (dia
  /// anterior) e outro até as 6h (dia novo), e só ele sabe qual está abrindo.
  ///
  /// Sem botão de cancelar, de propósito: a escolha é obrigatória, e fechar o
  /// diálogo sem resposta deixaria a abertura pela metade.
  Future<String> _escolherDataCaixa() async {
    final agora = DateTime.now();
    final hoje = DataCaixa.formatar(agora);
    if (!DataCaixa.aberturaDeMadrugada(agora)) return hoje;

    final ontem = DataCaixa.formatar(DataCaixa.diaAnterior(agora));
    final hora =
        '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}';

    ButtonStyle estilo() => ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        );

    final escolha = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('De qual turno é este caixa?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Você está abrindo o caixa às $hora. '
                'Selecione o dia correspondente:',
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: estilo(),
                onPressed: () => Navigator.of(ctx).pop(ontem),
                child: Text(
                  'Ontem — ${DataCaixa.curta(ontem)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                style: estilo(),
                onPressed: () => Navigator.of(ctx).pop(hoje),
                child: Text(
                  'Hoje — ${DataCaixa.curta(hoje)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return escolha ?? hoje;
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
            onDadosAlterados: _recarregarDados,
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
