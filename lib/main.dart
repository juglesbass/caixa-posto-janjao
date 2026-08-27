import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dialogs/auth_dialog.dart';
import 'dialogs/quick_launch_modal.dart';
import 'dialogs/turnos_anteriores_dialog.dart';
import 'models/totais_turno.dart';
import 'models/turno.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/summary_screen.dart';
import 'services/database_service.dart';
import 'services/drive_service.dart';
import 'services/notification_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
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

  // Inicializa notificações e fila de sincronização
  await NotificationService.inicializar();

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
    _tentarSincronizarFilaInicial();
  }

  void _tentarSincronizarFilaInicial() async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      await DriveService.sincronizarTodasPendencias();
    } catch (_) {}
  }

  Future<void> _inicializarApp() async {
    setState(() => _carregando = true);
    try {
      final db = DatabaseService.instance;
      final turnoAberto = await db.obterTurnoAberto();
      await NotificationService.atualizarPendencias();

      if (turnoAberto == null) {
        setState(() {
          _turnoAtual = null;
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

  Future<void> _recarregarDados() async {
    final db = DatabaseService.instance;
    final turnoAtualizado = await db.obterTurnoAberto();
    await NotificationService.atualizarPendencias();

    if (turnoAtualizado == null) {
      setState(() {
        _turnoAtual = null;
      });
      return;
    }

    final totais = await db.obterTotaisTurno(turnoAtualizado.id!);
    setState(() {
      _turnoAtual = turnoAtualizado;
      _totais = totais;
    });
  }

  void _solicitarIdentificacao({required bool novoTurno}) async {
    final db = DatabaseService.instance;
    final pin = await db.getConfig('pin_acesso');

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AuthDialog(
        novoTurno: novoTurno,
        pinConfigurado: pin,
      ),
    );

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

      // Novo turno sempre inicia com a máquina Rede por padrão
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('maquina_ativa', PaymentTypes.maquinaRede);
      } catch (_) {}

      final novoTurnoObj = await db.abrirNovoTurno(operador, fundoCaixa: fundo);
      final totais = await db.obterTotaisTurno(novoTurnoObj.id!);

      setState(() {
        _turnoAtual = novoTurnoObj;
        _totais = totais;
        _indiceAba = 0;
      });
    }
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentLight),
        ),
      );
    }

    if (_turnoAtual == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'POSTO JANJÃO',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                    ),
                    IconButton(
                      icon: Icon(
                        widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        color: widget.isDark ? const Color(0xFFFBBF24) : const Color(0xFF2563EB),
                      ),
                      tooltip: widget.isDark ? 'Ativar Tema Claro' : 'Ativar Tema Escuro',
                      onPressed: () => widget.onMudarTema(!widget.isDark),
                    ),
                  ],
                ),
              ),
              PendingSyncBanner(onSincronizado: _inicializarApp),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.14),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_gas_station_rounded, size: 54, color: AppColors.accentLight),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Nenhum Turno Aberto',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Abra um novo turno ou reabra um turno anterior para continuar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 280,
                          child: ElevatedButton.icon(
                            onPressed: () => _solicitarIdentificacao(novoTurno: true),
                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                            label: const Text(
                              'Abrir Turno Agora',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 280,
                          child: ElevatedButton.icon(
                            onPressed: () {
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
                            },
                            icon: const Icon(Icons.history_rounded, size: 18, color: Colors.white),
                            label: const Text(
                              'Histórico e Reabrir Turno',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
            onMudarTema: widget.onMudarTema,
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
