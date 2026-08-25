import 'package:flutter/material.dart';
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
  final String combustivel;
  final double precoPadrao;
  final TextEditingController controllerInicial;
  final TextEditingController controllerFinal;

  _BicoItem({
    required this.bico,
    required this.combustivel,
    required this.precoPadrao,
    double inicial = 0.0,
    double finalLitros = 0.0,
  })  : controllerInicial = TextEditingController(text: inicial > 0 ? inicial.toStringAsFixed(2) : ''),
        controllerFinal = TextEditingController(text: finalLitros > 0 ? finalLitros.toStringAsFixed(2) : '');

  double get inicial => double.tryParse(controllerInicial.text.replaceAll(',', '.')) ?? 0.0;
  double get finalLitros => double.tryParse(controllerFinal.text.replaceAll(',', '.')) ?? 0.0;
  double get litrosVendidos => (finalLitros - inicial) > 0 ? (finalLitros - inicial) : 0.0;
  double get totalReais => litrosVendidos * precoPadrao;
}

class _EncerrantesDialogState extends State<EncerrantesDialog> {
  final List<_BicoItem> _bicos = [
    _BicoItem(bico: 'Bico 01', combustivel: 'Gasolina Comum', precoPadrao: 5.89),
    _BicoItem(bico: 'Bico 02', combustivel: 'Gasolina Aditivada', precoPadrao: 6.09),
    _BicoItem(bico: 'Bico 03', combustivel: 'Etanol Hidratado', precoPadrao: 3.99),
    _BicoItem(bico: 'Bico 04', combustivel: 'Diesel S10', precoPadrao: 5.99),
  ];

  @override
  void initState() {
    super.initState();
    _carregarSalvos();
  }

  void _carregarSalvos() async {
    final db = DatabaseService.instance;
    final salvos = await db.obterEncerrantes(widget.turnoId);
    if (salvos.isNotEmpty) {
      for (final s in salvos) {
        final bico = _bicos.firstWhere(
          (b) => b.bico == s['bico'],
          orElse: () => _bicos.first,
        );
        bico.controllerInicial.text = (s['inicial'] as num?)?.toStringAsFixed(2) ?? '';
        bico.controllerFinal.text = (s['final'] as num?)?.toStringAsFixed(2) ?? '';
      }
      if (mounted) setState(() {});
    }
  }

  void _salvar() async {
    final db = DatabaseService.instance;
    for (final b in _bicos) {
      await db.salvarEncerrante(
        widget.turnoId,
        b.bico,
        b.combustivel,
        b.inicial,
        b.finalLitros,
        b.precoPadrao,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Encerrantes salvos com sucesso!'),
        backgroundColor: AppColors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  double get _totalLitrosGeral => _bicos.fold(0.0, (acc, b) => acc + b.litrosVendidos);
  double get _totalReaisGeral => _bicos.fold(0.0, (acc, b) => acc + b.totalReais);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_gas_station_rounded, color: Color(0xFFF59E0B), size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Encerrantes de Bombas',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Conferência de litros e bicos da pista',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: Color(0xFF1E293B), height: 20),

            // ── Lista de Bicos ──
            Expanded(
              child: ListView.separated(
                itemCount: _bicos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final bico = _bicos[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${bico.bico} • ${bico.combustivel}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'R\$ ${bico.precoPadrao.toStringAsFixed(2)}/L',
                              style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: bico.controllerInicial,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  labelText: 'Leitura Inicial',
                                  labelStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Color(0xFF0F172A),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: bico.controllerFinal,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  labelText: 'Leitura Final',
                                  labelStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Color(0xFF0F172A),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Litros: ${bico.litrosVendidos.toStringAsFixed(2)} L',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                            Text(
                              'Total: ${CurrencyFormatter.formatar(bico.totalReais)}',
                              style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // ── Totais ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2563EB)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Litros: ${_totalLitrosGeral.toStringAsFixed(2)} L',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    'Valor: ${CurrencyFormatter.formatar(_totalReaisGeral)}',
                    style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                      side: const BorderSide(color: Color(0xFF334155)),
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
