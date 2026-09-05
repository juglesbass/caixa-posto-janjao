import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

class EncerrantesDialog extends StatefulWidget {
  final int turnoId;

  const EncerrantesDialog({super.key, required this.turnoId});

  @override
  State<EncerrantesDialog> createState() => _EncerrantesDialogState();
}

class _BicoItem {
  final String bico;
  final TextEditingController controllerCombustivel;
  final TextEditingController controllerPreco;
  final TextEditingController controllerLitros;

  _BicoItem({
    required this.bico,
    required String combustivel,
    required double preco,
    double litros = 0.0,
  })  : controllerCombustivel = TextEditingController(text: combustivel),
        controllerPreco = TextEditingController(text: preco > 0 ? preco.toStringAsFixed(2) : ''),
        controllerLitros = TextEditingController(text: litros > 0 ? litros.toStringAsFixed(2) : '');

  String get combustivel => controllerCombustivel.text.trim();
  double get preco => double.tryParse(controllerPreco.text.replaceAll(',', '.')) ?? 0.0;
  double get litrosVendidos => double.tryParse(controllerLitros.text.replaceAll(',', '.')) ?? 0.0;
  double get totalReais => litrosVendidos * preco;

  void dispose() {
    controllerCombustivel.dispose();
    controllerPreco.dispose();
    controllerLitros.dispose();
  }
}

class _EncerrantesDialogState extends State<EncerrantesDialog> {
  final List<_BicoItem> _bicos = [
    _BicoItem(bico: 'Bico 01', combustivel: 'Gasolina Comum', preco: 5.89),
    _BicoItem(bico: 'Bico 02', combustivel: 'Gasolina Aditivada', preco: 6.09),
    _BicoItem(bico: 'Bico 03', combustivel: 'Etanol Hidratado', preco: 3.99),
    _BicoItem(bico: 'Bico 04', combustivel: 'Diesel S10', preco: 5.99),
  ];

  static const List<String> _sugestoesCombustivel = [
    'Gasolina Comum',
    'Gasolina Aditivada',
    'Etanol Hidratado',
    'Diesel S10',
    'Diesel Comum',
    'GNV',
  ];

  @override
  void initState() {
    super.initState();
    _carregarSalvos();
  }

  @override
  void dispose() {
    for (final b in _bicos) {
      b.dispose();
    }
    super.dispose();
  }

  void _carregarSalvos() async {
    final db = DatabaseService.instance;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // 1. Carrega preferências salvas no aparelho (preços e nomes atualizados)
    for (final b in _bicos) {
      final combSalvo = prefs.getString('bico_${b.bico}_combustivel');
      if (combSalvo != null && combSalvo.isNotEmpty) {
        b.controllerCombustivel.text = combSalvo;
      }
      final precoSalvo = prefs.getDouble('bico_${b.bico}_preco');
      if (precoSalvo != null && precoSalvo > 0) {
        b.controllerPreco.text = precoSalvo.toStringAsFixed(2);
      }
    }

    // 2. Carrega os dados específicos salvos deste turno
    final salvos = await db.obterEncerrantes(widget.turnoId);
    if (!mounted) return;
    if (salvos.isNotEmpty) {
      if (_bicos.isEmpty) return;
      for (final s in salvos) {
        final bico = _bicos.firstWhere(
          (b) => b.bico == s['bico'],
          orElse: () => _bicos.first,
        );
        if (s['combustivel'] != null && (s['combustivel'] as String).isNotEmpty) {
          bico.controllerCombustivel.text = s['combustivel'];
        }
        if (s['preco'] != null && (s['preco'] as num) > 0) {
          bico.controllerPreco.text = (s['preco'] as num).toDouble().toStringAsFixed(2);
        }
        final finalVal = (s['final'] as num?)?.toDouble() ?? 0.0;
        final inicialVal = (s['inicial'] as num?)?.toDouble() ?? 0.0;
        final litros = finalVal > 0 && inicialVal > 0 ? (finalVal - inicialVal) : finalVal;
        bico.controllerLitros.text = litros > 0 ? litros.toStringAsFixed(2) : '';
      }
    }
    if (mounted) setState(() {});
  }

  void _adicionarBico() {
    final novoIndex = _bicos.length + 1;
    final nomeBico = 'Bico ${novoIndex.toString().padLeft(2, '0')}';
    setState(() {
      _bicos.add(_BicoItem(
        bico: nomeBico,
        combustivel: 'Gasolina Comum',
        preco: 5.89,
      ));
    });
  }

  void _removerBico(int index) {
    if (_bicos.length <= 1) return;
    setState(() {
      final removido = _bicos.removeAt(index);
      removido.dispose();
    });
  }

  void _salvar() async {
    final db = DatabaseService.instance;
    final prefs = await SharedPreferences.getInstance();

    for (final b in _bicos) {
      await db.salvarEncerrante(
        widget.turnoId,
        b.bico,
        b.combustivel,
        0.0, // Não necessita de leitura inicial
        b.litrosVendidos, // Salva diretamente os litros vendidos
        b.preco,
      );

      // Salva os valores de preço e combustível para lembrar no próximo turno
      await prefs.setString('bico_${b.bico}_combustivel', b.combustivel);
      await prefs.setDouble('bico_${b.bico}_preco', b.preco);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Encerrantes salvos com sucesso!'),
        backgroundColor: AppColors.green,
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
  }

  double get _totalLitrosGeral => _bicos.fold(0.0, (acc, b) => acc + b.litrosVendidos);
  double get _totalReaisGeral => _bicos.fold(0.0, (acc, b) => acc + b.totalReais);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgDialog = isDark ? const Color(0xFF0F172A) : AppColors.lightSurface;
    final textPri = isDark ? Colors.white : AppColors.lightTextPri;
    final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;
    final borderCol = isDark ? const Color(0xFF1E293B) : AppColors.lightBorder;
    final cardBg = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    return Dialog(
      backgroundColor: bgDialog,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderCol),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          children: [
            // ── Cabeçalho do Modal ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_gas_station_rounded, color: Color(0xFFF59E0B), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Encerrantes de Bombas',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPri),
                      ),
                      Text(
                        'Informe os litros vendidos e ajuste os preços por bico',
                        style: TextStyle(fontSize: 11, color: textSec),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textSec),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Divider(color: borderCol, height: 20),

            // ── Lista de Bicos ──
            Expanded(
              child: ListView.separated(
                itemCount: _bicos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final bico = _bicos[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Topo do Card: Badge do Bico + Botão Excluir (se > 4 bicos)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_gas_station_rounded, size: 13, color: Color(0xFF38BDF8)),
                                  const SizedBox(width: 4),
                                  Text(
                                    bico.bico,
                                    style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            if (_bicos.length > 4)
                              InkWell(
                                onTap: () => _removerBico(index),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.red.withValues(alpha: 0.8)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Linha 1: Combustível Editável + Preço/L Editável
                        Row(
                          children: [
                            // Campo Combustível
                            Expanded(
                              flex: 3,
                              child: PopupMenuButton<String>(
                                tooltip: 'Selecionar combustível',
                                onSelected: (valor) {
                                  setState(() {
                                    bico.controllerCombustivel.text = valor;
                                  });
                                },
                                itemBuilder: (ctx) => _sugestoesCombustivel.map((comb) {
                                  return PopupMenuItem<String>(
                                    value: comb,
                                    child: Text(comb, style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList(),
                                child: TextField(
                                  controller: bico.controllerCombustivel,
                                  style: TextStyle(color: textPri, fontSize: 13, fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    labelText: 'Combustível',
                                    labelStyle: TextStyle(color: textSec, fontSize: 11),
                                    isDense: true,
                                    filled: true,
                                    fillColor: inputBg,
                                    suffixIcon: const Icon(Icons.arrow_drop_down_rounded, size: 20, color: Color(0xFF94A3B8)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: borderCol),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Campo Preço/L
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: bico.controllerPreco,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(color: textPri, fontSize: 13, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  labelText: 'Preço/L (R\$)',
                                  labelStyle: TextStyle(color: textSec, fontSize: 11),
                                  prefixText: 'R\$ ',
                                  prefixStyle: const TextStyle(fontSize: 12, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                                  isDense: true,
                                  filled: true,
                                  fillColor: inputBg,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderCol),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Linha 2: Quantidade de Litros Vendidos + Total do Bico em Dinheiro
                        Row(
                          children: [
                            // Campo Litros Vendidos
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: bico.controllerLitros,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(color: textPri, fontSize: 14, fontWeight: FontWeight.w700),
                                decoration: InputDecoration(
                                  labelText: 'Litros Vendidos',
                                  labelStyle: TextStyle(color: textSec, fontSize: 11),
                                  hintText: '0.00',
                                  hintStyle: TextStyle(color: textSec.withValues(alpha: 0.5)),
                                  suffixText: 'L',
                                  suffixStyle: TextStyle(fontSize: 12, color: textSec, fontWeight: FontWeight.bold),
                                  isDense: true,
                                  filled: true,
                                  fillColor: inputBg,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderCol),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Total em Dinheiro do Bico
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Total Bico',
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        CurrencyFormatter.formatar(bico.totalReais),
                                        style: const TextStyle(
                                          color: Color(0xFF10B981),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Botão Adicionar Bico (se tiver mais bicos na pista)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _adicionarBico,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFF38BDF8)),
                label: const Text('Adicionar Bico', style: TextStyle(fontSize: 12, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // ── Totais Gerais ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2563EB)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Litros: ${_totalLitrosGeral.toStringAsFixed(2)} L',
                    style: TextStyle(color: textPri, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    'Valor: ${CurrencyFormatter.formatar(_totalReaisGeral)}',
                    style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Botões de Ação ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textSec,
                      side: BorderSide(color: borderCol),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Voltar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _salvar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Salvar Encerrantes', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
