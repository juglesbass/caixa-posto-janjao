import 'dart:math' as math;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgDialog = isDark ? const Color(0xFF0F172A) : AppColors.lightSurface;
    final textPri = isDark ? Colors.white : AppColors.lightTextPri;
    final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;
    final borderCol = isDark ? const Color(0xFF1E293B) : AppColors.lightBorder;
    final cardBg = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF1F5F9);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    final totalGeral = totais.totalGeral > 0 ? totais.totalGeral : 1.0;
    final percCartoes = (totais.cartoes / totalGeral) * 100;
    final percPix = (totais.pix / totalGeral) * 100;
    final percDinheiro = (totais.dinheiro / totalGeral) * 100;
    final percOutros = ((totais.requisicao + totais.depositoGlobal) / totalGeral) * 100;

    return Dialog(
      backgroundColor: bgDialog,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderCol),
      ),
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
                    color: const Color(0xFFA855F7).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_graph_rounded, color: Color(0xFFA855F7), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analytics & Desempenho',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPri),
                      ),
                      Text(
                        'Gráficos de vendas e distribuição do turno',
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

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Card de Total Geral ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Vendido no Turno', style: TextStyle(color: textSec, fontSize: 12)),
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
                              Text('Qtd Lançamentos', style: TextStyle(color: textSec, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                '${totais.qtdCartoes + totais.qtdPix + (totais.dinheiro > 0 ? 1 : 0) + (totais.requisicao > 0 ? 1 : 0) + (totais.depositoGlobal > 0 ? 1 : 0)} un',
                                style: TextStyle(color: textPri, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text('DISTRIBUIÇÃO DE FORMAS DE PAGAMENTO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSec)),
                    const SizedBox(height: 10),

                    // Barra Visual de Progresso Multicolorida
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 12,
                        child: Row(
                          children: [
                            if (percCartoes > 0)
                              Expanded(
                                flex: math.max(1, (percCartoes * 10).toInt()),
                                child: Container(color: const Color(0xFF3B82F6)),
                              ),
                            if (percPix > 0)
                              Expanded(
                                flex: math.max(1, (percPix * 10).toInt()),
                                child: Container(color: const Color(0xFF10B981)),
                              ),
                            if (percDinheiro > 0)
                              Expanded(
                                flex: math.max(1, (percDinheiro * 10).toInt()),
                                child: Container(color: const Color(0xFFF59E0B)),
                              ),
                            if (percOutros > 0)
                              Expanded(
                                flex: math.max(1, (percOutros * 10).toInt()),
                                child: Container(color: const Color(0xFFA855F7)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Itens da Distribuição
                    _itemMetrica(
                      titulo: 'Cartões',
                      valor: totais.cartoes,
                      percentual: percCartoes,
                      cor: const Color(0xFF3B82F6),
                      quantidade: '${totais.qtdCartoes} vendas',
                      isDark: isDark,
                    ),
                    _itemMetrica(
                      titulo: 'Pix (Caixa/Direto)',
                      valor: totais.pix,
                      percentual: percPix,
                      cor: const Color(0xFF10B981),
                      quantidade: totais.qtdPix > 0 ? '${totais.qtdPix} vendas' : null,
                      isDark: isDark,
                    ),
                    _itemMetrica(
                      titulo: 'Dinheiro Pista',
                      valor: totais.dinheiro,
                      percentual: percDinheiro,
                      cor: const Color(0xFFF59E0B),
                      isDark: isDark,
                    ),
                    if (totais.requisicao > 0)
                      _itemMetrica(
                        titulo: 'Requisição / Faturado',
                        valor: totais.requisicao,
                        percentual: (totais.requisicao / totalGeral) * 100,
                        cor: const Color(0xFFA855F7),
                        isDark: isDark,
                      ),
                    if (totais.depositoGlobal > 0)
                      _itemMetrica(
                        titulo: 'Depósito Global',
                        valor: totais.depositoGlobal,
                        percentual: (totais.depositoGlobal / totalGeral) * 100,
                        cor: const Color(0xFF06B6D4),
                        isDark: isDark,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textSec,
                  side: BorderSide(color: borderCol),
                ),
                child: const Text('Fechar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemMetrica({
    required String titulo,
    required double valor,
    required double percentual,
    required Color cor,
    String? quantidade,
    required bool isDark,
  }) {
    final textPri = isDark ? Colors.white : AppColors.lightTextPri;
    final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;
    final cardBg = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: TextStyle(color: textPri, fontWeight: FontWeight.bold, fontSize: 13)),
                  if (quantidade != null)
                    Text(quantidade, style: TextStyle(color: textSec, fontSize: 10)),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(CurrencyFormatter.formatar(valor), style: TextStyle(color: textPri, fontWeight: FontWeight.bold, fontSize: 13)),
              Text('${percentual.toStringAsFixed(1)}%', style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
