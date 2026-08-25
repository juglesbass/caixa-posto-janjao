import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dialogs/auth_dialog.dart';
import 'dialogs/quick_launch_modal.dart';
import 'models/totais_turno.dart';
import 'models/turno.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/summary_screen.dart';
import 'services/database_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'utils/payment_types.dart';
import 'widgets/bottom_nav_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Trava a orientação em modo retrato para melhor usabilidade de caixa
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const CaixaPostoJanjaoApp());
}

class CaixaPostoJanjaoApp extends StatefulWidget {
  const CaixaPostoJanjaoApp({super.key});

  @override
  State<CaixaPostoJanjaoApp> createState() => _CaixaPostoJanjaoAppState();
}

class _CaixaPostoJanjaoAppState extends State<CaixaPostoJanjaoApp> {
  bool _isDark = true;

  @override
  void initState() {
    super.initState();
    _carregarTema();
  }

  void _carregarTema() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDark = prefs.getBool('tema_escuro') ?? true;
    });
  }

  void _mudarTema(bool escuro) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tema_escuro', escuro);
    setState(() {
      _isDark = escuro;
    });
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
      home: MainShell(
        isDark: _isDark,
        onMudarTema: _mudarTema,
      ),
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

class _MainShellState extends State<MainShell> {
  int _indiceAba = 0;
  Turno? _turnoAtual;
  TotaisTurno _totais = TotaisTurno();
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _inicializarApp();
  }

  void _inicializarApp() async {
    setState(() => _carregando = true);
    try {
      final db = DatabaseService.instance;
      final turnoAberto = await db.obterTurnoAberto();

      if (turnoAberto == null) {
        setState(() {
          _carregando = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _solicitarIdentificacao(novoTurno: true);
        });
      } else {
        final totais = await db.obterTotaisTurno(turnoAberto.id!);
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _solicitarIdentificacao(novoTurno: true);
        });
      }
    }
  }

  void _recarregarDados() async {
    if (_turnoAtual == null) return;
    final db = DatabaseService.instance;
    final totais = await db.obterTotaisTurno(_turnoAtual!.id!);
    final turnoAtualizado = await db.obterTurnoAberto();
    setState(() {
      _totais = totais;
      if (turnoAtualizado != null) _turnoAtual = turnoAtualizado;
    });
  }

  void _solicitarIdentificacao({required bool novoTurno}) async {
    final db = DatabaseService.instance;
    final pin = await db.getConfig('pin_acesso');

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AuthDialog(
        novoTurno: novoTurno,
        pinConfigurado: pin,
      ),
    );

    if (result != null) {
      final operador = result['operador'] as String;
      final fundo = (result['fundoCaixa'] as num?)?.toDouble() ?? 0.0;

      final novoTurnoObj = await db.abrirNovoTurno(operador, fundoCaixa: fundo);
      final totais = await db.obterTotaisTurno(novoTurnoObj.id!);

      setState(() {
        _turnoAtual = novoTurnoObj;
        _totais = totais;
        _indiceAba = 0;
      });
    }
  }

  void _abrirLancamentoRapido() {
    if (_turnoAtual == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDark ? AppColors.darkSheetBg : AppColors.lightSheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.radiusXl)),
      ),
      builder: (ctx) => QuickLaunchModal(
        maquinaAtiva: PaymentTypes.maquinaRede,
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentLight),
        ),
      );
    }

    if (_turnoAtual == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_gas_station_rounded, size: 64, color: AppColors.accentLight),
              const SizedBox(height: 16),
              const Text('Nenhum Turno Aberto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _solicitarIdentificacao(novoTurno: true),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Abrir Turno Agora'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              ),
            ],
          ),
        ),
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
          ),

          // Aba 2: Resumo
          SummaryScreen(
            turno: _turnoAtual!,
            totais: _totais,
            onTurnoAlterado: _inicializarApp,
            onFechar: () => setState(() => _indiceAba = 0),
          ),

          // Aba 3: Menu / Configurações
          SettingsScreen(
            isDark: widget.isDark,
            onMudarTema: widget.onMudarTema,
            onAbrirNovoTurno: () => _solicitarIdentificacao(novoTurno: true),
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
