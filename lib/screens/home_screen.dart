import 'package:flutter/material.dart';
import '../dialogs/card_brand_dialog.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../services/database_service.dart';
import '../services/drive_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';
import '../utils/app_haptics.dart';
import '../utils/currency_formatter.dart';
import '../utils/payment_types.dart';
import '../widgets/cabecalho_turno.dart';
import '../widgets/campos_lancamento.dart';
import '../widgets/hud_totais.dart';
import '../widgets/machine_selector.dart';
import '../widgets/payment_grid.dart';
import '../widgets/pending_sync_banner.dart';
import '../widgets/ultimos_lancamentos.dart';
import '../widgets/quick_amount_row.dart';
import '../widgets/troco_calculator.dart';
import 'consulta_produtos_screen.dart';

class HomeScreen extends StatefulWidget {
  final Turno turno;
  final TotaisTurno totais;
  final VoidCallback onRecarregar;
  final VoidCallback onAbrirResumo;
  final ValueChanged<bool>? onMudarTema;

  const HomeScreen({
    super.key,
    required this.turno,
    required this.totais,
    required this.onRecarregar,
    required this.onAbrirResumo,
    this.onMudarTema,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controllerValor = TextEditingController();
  final _controllerDesc = TextEditingController();
  final _controllerRecebido = TextEditingController();
  final _focusNodeValor = FocusNode();

  final ValueNotifier<double> _valorVendaNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> _valorRecebidoNotifier = ValueNotifier<double>(0.0);

  String _maquinaAtiva = PaymentTypes.maquinaRede;
  String _tipoAtivo = PaymentTypes.dinheiro;
  String _bandeiraCartaoAtiva = 'Master Débito';

  String? _erroValor;
  bool _enviando = false;
  bool _abrindoSeletor = false;

  @override
  void initState() {
    super.initState();
    PaymentTypes.maquinaAtivaNotifier.addListener(_sincronizarMaquinaGlobal);
    _carregarMaquinaAtiva();
  }

  void _sincronizarMaquinaGlobal() {
    final novaMaq = PaymentTypes.maquinaAtivaNotifier.value;
    if (!mounted || novaMaq == _maquinaAtiva) return;
    setState(() {
      _maquinaAtiva = novaMaq;
      if (PaymentTypes.ehCartao(_tipoAtivo)) {
        _tipoAtivo = '$_maquinaAtiva $_bandeiraCartaoAtiva';
      }
    });
  }

  void _carregarMaquinaAtiva() async {
    final maqSalva = await PaymentTypes.carregarMaquinaAtiva();
    if (mounted && maqSalva != _maquinaAtiva) {
      setState(() {
        _maquinaAtiva = maqSalva;
        if (PaymentTypes.ehCartao(_tipoAtivo)) {
          _tipoAtivo = '$_maquinaAtiva $_bandeiraCartaoAtiva';
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.turno.id != widget.turno.id) {
      _controllerValor.clear();
      _controllerDesc.clear();
      _controllerRecebido.clear();
      _valorVendaNotifier.value = 0.0;
      _valorRecebidoNotifier.value = 0.0;
      _erroValor = null;
      _carregarMaquinaAtiva();
    }
  }

  @override
  void dispose() {
    PaymentTypes.maquinaAtivaNotifier.removeListener(_sincronizarMaquinaGlobal);
    _valorVendaNotifier.dispose();
    _valorRecebidoNotifier.dispose();
    _controllerValor.dispose();
    _controllerDesc.dispose();
    _controllerRecebido.dispose();
    _focusNodeValor.dispose();
    super.dispose();
  }

  void _selecionarTipo(String tipo) {
    AppHaptics.light();
    setState(() {
      _tipoAtivo = tipo;
    });
  }

  void _abrirSeletorCartoes() async {
    if (_abrindoSeletor) return;
    _abrindoSeletor = true;
    try {
      final bandeiraEscolhida = await showDialog<String>(
        context: context,
        builder: (ctx) => CardBrandDialog(
          maquinaAtiva: _maquinaAtiva,
          bandeiraSelecionada: _bandeiraCartaoAtiva,
        ),
      );

      if (!mounted) return;
      if (bandeiraEscolhida != null) {
        AppHaptics.light();
        setState(() {
          _bandeiraCartaoAtiva = bandeiraEscolhida;
          _tipoAtivo = '$_maquinaAtiva $bandeiraEscolhida';
        });
      }
    } finally {
      _abrindoSeletor = false;
    }
  }

  void _setValorRapido(double v) {
    AppHaptics.light();
    final novoValor = _valorVendaNotifier.value + v;
    _controllerValor.text = CurrencyFormatter.formatar(novoValor);
    _valorVendaNotifier.value = novoValor;
    if (_erroValor != null) {
      setState(() => _erroValor = null);
    }
  }

  void _limparValorVenda() {
    AppHaptics.light();
    _controllerValor.clear();
    _valorVendaNotifier.value = 0.0;
    if (_erroValor != null) {
      setState(() => _erroValor = null);
    }
  }

  void _lancarVenda() async {
    if (_enviando) return;

    final valor = CurrencyFormatter.parse(_controllerValor.text);
    if (valor <= 0) {
      AppHaptics.heavy();
      setState(() {
        _erroValor = 'Informe um valor maior que zero';
      });
      return;
    }

    setState(() {
      _enviando = true;
      _erroValor = null;
    });

    try {
      final db = DatabaseService.instance;
      String tipoFinal = _tipoAtivo;

      if (PaymentTypes.ehCartao(tipoFinal)) {
        if (!tipoFinal.startsWith('Rede ') && !tipoFinal.startsWith('Cielo ')) {
          tipoFinal = '$_maquinaAtiva $_bandeiraCartaoAtiva';
        }
      }

      await db.inserirLancamento(
        widget.turno.id!,
        tipoFinal,
        valor,
        _controllerDesc.text.trim(),
      );

      AppHaptics.light();

      if (!mounted) return;

      // Sem faixa de "lancado": a confirmacao e o lancamento entrando, aceso,
      // no topo dos ultimos lancamentos (UltimosLancamentos). A faixa verde
      // aparecia embaixo, por cima do rodape, longe de onde o olho estava.
      _controllerValor.clear();
      _controllerDesc.clear();
      _controllerRecebido.clear();

      _valorVendaNotifier.value = 0.0;
      _valorRecebidoNotifier.value = 0.0;
      // Totais e últimos lançamentos se atualizam pelo aviso do banco
      // (lancamentosNotifier), que o inserirLancamento acabou de disparar.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao lançar: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _enviando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ehDinheiro = PaymentTypes.ehDinheiro(_tipoAtivo);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 14,
        title: CabecalhoTurno(turno: widget.turno),
        actions: [
          // O modo teste ocupa o lugar do selo de estado: enquanto estiver
          // ligado, e o aviso que mais importa. A tarja no corpo continua.
          ValueListenableBuilder<bool>(
            valueListenable: DriveService.modoTesteNotifier,
            builder: (context, modoTeste, _) => modoTeste
                ? const Center(
                    child: SeloTurno(texto: 'Teste', cor: AppColors.amber),
                  )
                : const SizedBox.shrink(),
          ),
          // Consulta de produtos e tema ficam na barra: os dois sao usados no
          // meio do turno, e no Menu custariam um toque a mais toda vez. O
          // resumo saiu (tem a aba e o placar) e a sangria saiu do app.
          if (widget.onMudarTema != null)
            IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: isDark ? AppColors.amber2 : AppColors.accent,
              ),
              tooltip: isDark ? 'Ativar Tema Claro' : 'Ativar Tema Escuro',
              onPressed: () => widget.onMudarTema!(!isDark),
            ),
          IconButton(
            icon: const Icon(Icons.manage_search_rounded, color: AppColors.accentLight),
            tooltip: 'Tabela de Códigos / Produtos',
            onPressed: () {
              if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const ConsultaProdutosScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Tarja / Banner Visual de Modo Teste Ativo ──
                  ValueListenableBuilder<bool>(
                    valueListenable: DriveService.modoTesteNotifier,
                    builder: (context, modoTeste, _) {
                      if (!modoTeste) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                          border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Text('🧪', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'MODO TESTE ATIVO: Relatórios serão enviados para a pasta de homologação no Drive.',
                                style: TextStyle(
                                  color: AppColors.amber2,
                                  fontSize: AppTexto.rotulo,
                                  fontWeight: FontWeight.bold,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  PendingSyncBanner(
                    onSincronizado: widget.onRecarregar,
                    margem: const EdgeInsets.only(bottom: 12),
                  ),

                  // ── HUD Bento Grid de Totais ──
                  RepaintBoundary(
                    child: HudTotais(
                      totais: widget.totais,
                      onTapDetalhes: widget.onAbrirResumo,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Conferência rápida do que acabou de ser lançado ──
                  RepaintBoundary(
                    child: UltimosLancamentos(
                      turno: widget.turno,
                      maquinaAtiva: _maquinaAtiva,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Seletor de Máquina (REDE vs CIELO) ──
                  MachineSelector(
                    maquinaAtiva: _maquinaAtiva,
                    onSelecionar: (maq) async {
                      AppHaptics.selection();
                      setState(() {
                        _maquinaAtiva = maq;
                        if (PaymentTypes.ehCartao(_tipoAtivo)) {
                          _tipoAtivo = '$_maquinaAtiva $_bandeiraCartaoAtiva';
                        }
                      });
                      await PaymentTypes.definirMaquinaAtiva(maq);
                    },
                  ),
                  const SizedBox(height: 12),

                  // ── Grade de Formas de Pagamento ──
                  RepaintBoundary(
                    child: PaymentGrid(
                      tipoAtivo: _tipoAtivo,
                      bandeiraCartaoAtiva: _bandeiraCartaoAtiva,
                      onSelecionarTipo: _selecionarTipo,
                      onAbrirSeletorCartoes: _abrirSeletorCartoes,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Campo Principal de Valor (isolado para não repintar a tela ao digitar) ──
                  ValueListenableBuilder<double>(
                    valueListenable: _valorVendaNotifier,
                    builder: (context, valorVenda, _) => CampoValorVenda(
                      controller: _controllerValor,
                      focusNode: _focusNodeValor,
                      podeLancar: valorVenda > 0,
                      enviando: _enviando,
                      erro: _erroValor,
                      onLimpar: valorVenda > 0 ? _limparValorVenda : null,
                      onChanged: (val) {
                        _valorVendaNotifier.value = CurrencyFormatter.parse(val);
                        if (_erroValor != null) {
                          setState(() => _erroValor = null);
                        }
                      },
                      onLancar: _lancarVenda,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Atalhos Rápidos (+ R$ 10 a + R$ 500) ──
                  RepaintBoundary(
                    child: QuickAmountRow(onSelecionarValor: _setValorRapido),
                  ),
                  const SizedBox(height: 12),

                  // ── Calculadora de Troco (Se Dinheiro) ──
                  if (ehDinheiro) ...[
                    ListenableBuilder(
                      listenable: Listenable.merge([_valorVendaNotifier, _valorRecebidoNotifier]),
                      builder: (context, _) => TrocoCalculator(
                        valorVenda: _valorVendaNotifier.value,
                        valorRecebido: _valorRecebidoNotifier.value,
                        controllerRecebido: _controllerRecebido,
                        onChanged: (val) {
                          _valorRecebidoNotifier.value = CurrencyFormatter.parse(val);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Campo Opcional de Descrição / Placa ──
                  CampoDescricao(controller: _controllerDesc, onSubmitted: _lancarVenda),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
