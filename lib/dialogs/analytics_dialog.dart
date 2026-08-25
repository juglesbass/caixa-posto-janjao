import 'package:flutter/material.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

class AnalyticsDialog extends StatelessWidget {
  final Turno turno;
  final TotaisTurno totais;

  const AnalyticsDialog({
    super.key,
    required this.turno,
    required this.totais,
  });

  @override
  Widget build(BuildContext context) {
    final totalGeral = totais.totalGeral > 0 ? totais.totalGeral : 1.0;
    final percCartoes = (totais.cartoes / totalGeral) * 100;
    final percPix = (totais.pix / totalGeral) * 100;
    final percDinheiro = (totais.dinheiro / totalGeral) * 100;
    final percOutros = ((totais.requisicao + totais.depositoGlobal) / totalGeral) * 100;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA855F7).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_graph_rounded, color: Color(0xFFA855F7), size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analytics & Desempenho',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Gráficos de vendas e distribuição do turno',
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

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Card de Total Geral ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Vendido no Turno', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                CurrencyFormatter.formatar(totais.totalGeral),
                                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 20, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Qtd Lançamentos', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                '${totais.qtdCartoes + (totais.pix > 0 ? 1 : 0) + (totais.dinheiro > 0 ? 1 : 0)} un',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'DISTRIBUIÇÃO POR MEIO DE PAGAMENTO',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),

                    // Barra Progresso Visual
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 14,
                        child: Row(
                          children: [
                            if (percCartoes > 0)
                              Expanded(
                                flex: (percCartoes * 10).toInt().clamp(1, 1000),
                                child: Container(color: const Color(0xFF3B82F6)),
                              ),
                            if (percPix > 0)
                              Expanded(
                                flex: (percPix * 10).toInt().clamp(1, 1000),
                                child: Container(color: const Color(0xFF06B6D4)),
                              ),
                            if (percDinheiro > 0)
                              Expanded(
                                flex: (percDinheiro * 10).toInt().clamp(1, 1000),
                                child: Container(color: const Color(0xFF10B981)),
                              ),
                            if (percOutros > 0)
                              Expanded(
                                flex: (percOutros * 10).toInt().clamp(1, 1000),
                                child: Container(color: const Color(0xFFF59E0B)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _itemBarra(
                      label: 'Cartões e Vouchers',
                      valor: totais.cartoes,
                      percentual: percCartoes,
                      cor: const Color(0xFF3B82F6),
                      icon: Icons.credit_card_rounded,
                    ),
                    const SizedBox(height: 8),

                    _itemBarra(
                      label: 'Pag Pix',
                      valor: totais.pix,
                      percentual: percPix,
                      cor: const Color(0xFF06B6D4),
                      icon: Icons.qr_code_2_rounded,
                    ),
                    const SizedBox(height: 8),

                    _itemBarra(
                      label: 'Sobra de Dinheiro',
                      valor: totais.dinheiro,
                      percentual: percDinheiro,
                      cor: const Color(0xFF10B981),
                      icon: Icons.payments_rounded,
                    ),
                    const SizedBox(height: 8),

                    _itemBarra(
                      label: 'Outros Meios (Req / Dep)',
                      valor: totais.requisicao + totais.depositoGlobal,
                      percentual: percOutros,
                      cor: const Color(0xFFF59E0B),
                      icon: Icons.account_balance_rounded,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Fechar Analytics'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemBarra({
    required String label,
    required double valor,
    required double percentual,
    required Color cor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Icon(icon, color: cor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          Text(
            '${percentual.toStringAsFixed(1)}%',
            style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(width: 12),
          Text(
            CurrencyFormatter.formatar(valor),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
