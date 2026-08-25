import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BottomNavBar extends StatelessWidget {
  final int indiceAtual;
  final ValueChanged<int> onTrocarAba;
  final VoidCallback onAbrirLancamentoRapido;

  const BottomNavBar({
    super.key,
    required this.indiceAtual,
    required this.onTrocarAba,
    required this.onAbrirLancamentoRapido,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ItemNav(
                icon: Icons.home_rounded,
                label: 'Início',
                ativo: indiceAtual == 0,
                onTap: () => onTrocarAba(0),
                textSec: textSec,
              ),
              _ItemNav(
                icon: Icons.receipt_long_rounded,
                label: 'Histórico',
                ativo: indiceAtual == 1,
                onTap: () => onTrocarAba(1),
                textSec: textSec,
              ),

              // Botão Flutuante Central de Lançamento (+)
              GestureDetector(
                onTap: onAbrirLancamentoRapido,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                ),
              ),

              _ItemNav(
                icon: Icons.bar_chart_rounded,
                label: 'Resumo',
                ativo: indiceAtual == 2,
                onTap: () => onTrocarAba(2),
                textSec: textSec,
              ),
              _ItemNav(
                icon: Icons.more_horiz_rounded,
                label: 'Menu',
                ativo: indiceAtual == 3,
                onTap: () => onTrocarAba(3),
                textSec: textSec,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemNav extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ativo;
  final VoidCallback onTap;
  final Color textSec;

  const _ItemNav({
    required this.icon,
    required this.label,
    required this.ativo,
    required this.onTap,
    required this.textSec,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: ativo ? AppColors.accentLight : textSec,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: ativo ? FontWeight.bold : FontWeight.normal,
                color: ativo ? AppColors.accentLight : textSec,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
