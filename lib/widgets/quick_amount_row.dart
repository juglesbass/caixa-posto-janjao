import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class QuickAmountRow extends StatelessWidget {
  final ValueChanged<double> onSelecionarValor;

  const QuickAmountRow({
    super.key,
    required this.onSelecionarValor,
  });

  static const List<double> valores = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 150, 200, 500];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: valores.map((v) {
        final label = '+ R\$ ${v.toInt()}';
        return InkWell(
          onTap: () => onSelecionarValor(v),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: textPri,
                letterSpacing: 0.2,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
