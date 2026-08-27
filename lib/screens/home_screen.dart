import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dialogs/card_brand_dialog.dart';
import '../dialogs/sangria_dialog.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../services/database_service.dart';
import '../services/drive_service.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/payment_types.dart';
import '../widgets/hud_totais.dart';
import '../widgets/machine_selector.dart';
import '../widgets/payment_grid.dart';
import '../widgets/pending_sync_banner.dart';
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

  String _maquinaAtiva = PaymentTypes.maquinaRede;
  String _tipoAtivo = PaymentTypes.dinheiro;
  String _bandeiraCartaoAtiva = 'Master Débito';

  double _valorVenda = 0.0;
  double _valorRecebido = 0.0;
  String? _erroValor;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _focusNodeValor.addListener(_onFocusValorChange);
    _carregarMaquinaAtiva();
  }

  void _onFocusValorChange() {
    if (mounted) setState(() {});
  }

  void _carregarMaquinaAtiva() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final maqSalva = prefs.getString('maquina_ativa') ?? PaymentTypes.maquinaRede;
      if (mounted) {
        setState(() {
          _maquinaAtiva = maqSalva;
          if (PaymentTypes.ehCartao(_tipoAtivo)) {
            _tipoAtivo = '$_maquinaAtiva $_bandeiraCartaoAtiva';
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _focusNodeValor.removeListener(_onFocusValorChange);
    _controllerValor.dispose();
    _controllerDesc.dispose();
    _controllerRecebido.dispose();
    _focusNodeValor.dispose();
    super.dispose();
  }

  void _selecionarTipo(String tipo) {
    HapticFeedback.selectionClick();
    setState(() {
      _tipoAtivo = tipo;
    });
  }

  void _abrirSeletorCartoes() async {
    final bandeiraEscolhida = await showDialog<String>(
      context: context,
      builder: (ctx) => CardBrandDialog(
        maquinaAtiva: _maquinaAtiva,
        bandeiraSelecionada: _bandeiraCartaoAtiva,
      ),
    );

    if (bandeiraEscolhida != null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _bandeiraCartaoAtiva = bandeiraEscolhida;
        _tipoAtivo = '$_maquinaAtiva $bandeiraEscolhida';
      });
    }
  }

  void _setValorRapido(double v) {
    HapticFeedback.lightImpact();
    final novoValor = _valorVenda + v;
    _controllerValor.text = CurrencyFormatter.formatar(novoValor);
    setState(() {
      _valorVenda = novoValor;
      _erroValor = null;
    });
  }

  void _lancarVenda() async {
    if (_enviando) return;

    final valor = CurrencyFormatter.parse(_controllerValor.text);
    if (valor <= 0) {
      HapticFeedback.heavyImpact();
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

      HapticFeedback.lightImpact();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${CurrencyFormatter.formatar(valor)} lançado em $tipoFinal'),
          backgroundColor: AppColors.green,
          duration: const Duration(milliseconds: 1800),
        ),
      );

      _controllerValor.clear();
      _controllerDesc.clear();
      _controllerRecebido.clear();

      setState(() {
        _valorVenda = 0.0;
        _valorRecebido = 0.0;
      });

      widget.onRecarregar();
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

  void _abrirSangria() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SangriaDialog(
        dinheiroNaGaveta: widget.totais.dinheiroGaveta,
      ),
    );

    if (result != null) {
      final valor = result['valor'] as double;
      final motivo = result['motivo'] as String;

      final db = DatabaseService.instance;
      await db.inserirLancamento(
        widget.turno.id!,
        PaymentTypes.sangria,
        valor,
        motivo,
      );

      HapticFeedback.mediumImpact();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sangria de ${CurrencyFormatter.formatar(valor)} realizada com sucesso!'),
          backgroundColor: AppColors.orange,
        ),
      );

      widget.onRecarregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final ehDinheiro = PaymentTypes.ehDinheiro(_tipoAtivo);
    final alertaGaveta = widget.totais.dinheiroGaveta >= 800.0;

    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<bool>(
          valueListenable: DriveService.modoTesteNotifier,
          builder: (context, modoTeste, _) {
            return Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('POSTO JANJÃO', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    if (modoTeste) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '🧪 MODO TESTE',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Turno #${widget.turno.numero} • ${widget.turno.operador}',
                  style: TextStyle(fontSize: 11, color: textSec),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_search_rounded, color: Color(0xFF38BDF8)),
            tooltip: 'Tabela de Códigos / Produtos',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const ConsultaProdutosScreen()),
              );
            },
          ),
          if (widget.onMudarTema != null)
            IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF3B82F6),
              ),
              tooltip: isDark ? 'Ativar Tema Claro' : 'Ativar Tema Escuro',
              onPressed: () => widget.onMudarTema!(!isDark),
            ),
          IconButton(
            icon: const Icon(Icons.call_made_rounded, color: AppColors.orange),
            tooltip: 'Realizar Sangria',
            onPressed: _abrirSangria,
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: AppColors.accentLight),
            tooltip: 'Resumo do Turno',
            onPressed: widget.onAbrirResumo,
          ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF78350F).withOpacity(0.35),
                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                          border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                        ),
                        child: const Row(
                          children: [
                            Text('🧪', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'MODO TESTE ATIVO: Relatórios serão enviados para a pasta de homologação no Drive.',
                                style: TextStyle(
                                  color: Color(0xFFFBBF24),
                                  fontSize: 11.5,
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
                  PendingSyncBanner(onSincronizado: widget.onRecarregar),
                  // ── Banner de Alerta de Sangria ──
                  if (alertaGaveta) ...[
                    InkWell(
                      onTap: _abrirSangria,
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                          border: Border.all(color: AppColors.orange),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.orange, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Gaveta com ${CurrencyFormatter.formatar(widget.totais.dinheiroGaveta)}. Recomenda-se fazer sangria!',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.orange),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.orange),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── HUD Bento Grid de Totais ──
                  HudTotais(
                    totais: widget.totais,
                    onTapDetalhes: widget.onAbrirResumo,
                  ),
                  const SizedBox(height: 14),

                  // ── Seletor de Máquina (REDE vs CIELO) ──
                  MachineSelector(
                    maquinaAtiva: _maquinaAtiva,
                    onSelecionar: (maq) async {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _maquinaAtiva = maq;
                        if (PaymentTypes.ehCartao(_tipoAtivo)) {
                          _tipoAtivo = '$_maquinaAtiva $_bandeiraCartaoAtiva';
                        }
                      });
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('maquina_ativa', maq);
                      } catch (_) {}
                    },
                  ),
                  const SizedBox(height: 12),

                  // ── Grade de Formas de Pagamento ──
                  PaymentGrid(
                    tipoAtivo: _tipoAtivo,
                    bandeiraCartaoAtiva: _bandeiraCartaoAtiva,
                    onSelecionarTipo: _selecionarTipo,
                    onAbrirSeletorCartoes: _abrirSeletorCartoes,
                  ),
                  const SizedBox(height: 14),

                  // ── Campo Principal de Valor ──
                  TextField(
                    controller: _controllerValor,
                    focusNode: _focusNodeValor,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [CurrencyInputFormatter()],
                    textInputAction: TextInputAction.done,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textPri,
                      letterSpacing: 0.5,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Valor da Venda',
                      labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textSec),
                      hintText: 'R\$ 0,00',
                      prefixIcon: const Icon(Icons.attach_money_rounded, color: AppColors.accentLight, size: 26),
                      suffixIcon: _valorVenda > 0
                          ? Padding(
                              padding: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
                              child: ElevatedButton.icon(
                                onPressed: _enviando ? null : _lancarVenda,
                                icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                label: const Text(
                                  'LANÇAR',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                  ),
                                ),
                              ),
                            )
                          : null,
                      errorText: _erroValor,
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        borderSide: const BorderSide(color: AppColors.accentLight, width: 2),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _valorVenda = CurrencyFormatter.parse(val);
                        if (_erroValor != null) _erroValor = null;
                      });
                    },
                    onSubmitted: (_) => _lancarVenda(),
                  ),
                  const SizedBox(height: 10),

                  // ── Botão Grande LANÇAR VENDA ──
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _enviando ? null : _lancarVenda,
                      icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 22),
                      label: Text(
                        _enviando ? 'Lançando...' : 'LANÇAR VENDA',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        elevation: 4,
                        shadowColor: AppColors.accent.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Atalhos Rápidos (+ R$ 10 a + R$ 500) ──
                  QuickAmountRow(onSelecionarValor: _setValorRapido),
                  const SizedBox(height: 12),

                  // ── Calculadora de Troco (Se Dinheiro) ──
                  if (ehDinheiro) ...[
                    TrocoCalculator(
                      valorVenda: _valorVenda,
                      valorRecebido: _valorRecebido,
                      controllerRecebido: _controllerRecebido,
                      onChanged: (val) {
                        setState(() {
                          _valorRecebido = CurrencyFormatter.parse(val);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Campo Opcional de Descrição / Placa ──
                  TextField(
                    controller: _controllerDesc,
                    decoration: InputDecoration(
                      labelText: 'Descrição / Placa / Observação (Opcional)',
                      hintText: 'Ex: Troca de óleo, Placa ABC-1234...',
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                    onSubmitted: (_) => _lancarVenda(),
                  ),
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
