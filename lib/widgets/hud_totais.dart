import 'package:flutter/material.dart';
import '../models/totais_turno.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

class HudTotais extends StatelessWidget {
  final TotaisTurno totais;
  final VoidCallback? onTapDetalhes;

  const HudTotais({
    super.key,
    required this.totais,
    this.onTapDetalhes,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    return InkWell(
      onTap: onTapDetalhes,
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Topo do HUD: Total Geral ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL DO TURNO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: textSec,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      CurrencyFormatter.formatar(totais.totalGeral),
                      style: TextStyle(
                        fontSize: 31,
                        fontWeight: FontWeight.w900,
                        color: textPri,
                        letterSpacing: -1,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
                // O bloco inteiro abre o resumo: melhor dizer isso com palavra
                // do que com um icone de carteira que nao leva a lugar obvio.
                const Row(
                  children: [
                    Text(
                      'resumo',
                      style: TextStyle(fontSize: 11, color: AppColors.accentLight),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.accentLight),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: borderColor),
            const SizedBox(height: 12),

            // ── Grid Bento de Totais Rápidos ──
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Total(
                      label: 'DINHEIRO',
                      valor: CurrencyFormatter.formatar(totais.dinheiro),
                      cor: AppColors.green,
                    ),
                  ),
                  VerticalDivider(width: 17, thickness: 1, color: borderColor),
                  Expanded(
                    child: _Total(
                      label: 'PIX',
                      valor: CurrencyFormatter.formatar(totais.pix),
                      cor: AppColors.blue,
                    ),
                  ),
                  VerticalDivider(width: 17, thickness: 1, color: borderColor),
                  Expanded(
                    child: _Total(
                      label: 'CARTÕES',
                      valor: CurrencyFormatter.formatar(totais.cartoes),
                      cor: AppColors.purple,
                      quantidade: totais.qtdCartoes > 0 ? '${totais.qtdCartoes}un' : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Um total por forma de pagamento: rotulo em cima, valor embaixo, sem caixa.
///
/// A cor aparece num ponto de 7px. Antes cada um destes era um bloco tingido,
/// e tres blocos coloridos lado a lado brigavam com o total geral logo acima —
/// que e o numero que o frentista precisa enxergar primeiro.
class _Total extends StatelessWidget {
  final String label;
  final String valor;
  final Color cor;
  final String? quantidade;

  const _Total({
    required this.label,
    required this.valor,
    required this.cor,
    this.quantidade,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textTer = isDark ? AppColors.darkTextTer : AppColors.lightTextTer;
    final corVibrante = isDark && cor == AppColors.purple ? AppColors.purpleLight : cor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: corVibrante, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.9,
                  color: textTer,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (quantidade != null) ...[
              const SizedBox(width: 4),
              Text(
                quantidade!,
                style: TextStyle(fontSize: 9, color: textTer),
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            valor,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: textPri,
            ),
          ),
        ),
      ],
    );
  }
}
