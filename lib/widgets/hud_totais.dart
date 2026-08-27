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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [AppColors.darkSurfaceElevated, AppColors.darkSurface]
                : [AppColors.lightSurface, AppColors.lightSurfaceSubtle],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
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
                      'TOTAL GERAL DO TURNO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textSec,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.formatar(totais.totalGeral),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: textPri,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppColors.accentLight,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: borderColor),
            const SizedBox(height: 12),

            // ── Grid Bento de Totais Rápidos ──
            Row(
              children: [
                Expanded(
                  child: _MiniCardTotais(
                    icon: Icons.payments_rounded,
                    label: 'Dinheiro',
                    valor: CurrencyFormatter.formatar(totais.dinheiro),
                    cor: AppColors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniCardTotais(
                    icon: Icons.pix_rounded,
                    label: 'Pix',
                    valor: CurrencyFormatter.formatar(totais.pix),
                    cor: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniCardTotais(
                    icon: Icons.credit_card_rounded,
                    label: 'Cartões',
                    valor: CurrencyFormatter.formatar(totais.cartoes),
                    cor: AppColors.purple,
                    badge: totais.qtdCartoes > 0 ? '${totais.qtdCartoes} un' : null,
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

class _MiniCardTotais extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valor;
  final Color cor;
  final String? badge;

  const _MiniCardTotais({
    required this.icon,
    required this.label,
    required this.valor,
    required this.cor,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final corVibrante = isDark && cor == AppColors.purple ? AppColors.purpleLight : cor;
    final corTextoLabel = isDark
        ? (cor == AppColors.purple ? const Color(0xFFE9D5FF) : corVibrante)
        : cor;
    final corBadge = isDark
        ? (cor == AppColors.purple ? const Color(0xFFDDD6FE) : corVibrante.withOpacity(0.9))
        : cor.withOpacity(0.85);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: corVibrante.withOpacity(isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: corVibrante.withOpacity(isDark ? 0.40 : 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: corVibrante),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: corTextoLabel,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: corVibrante.withOpacity(isDark ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: corBadge,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: textPri,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
