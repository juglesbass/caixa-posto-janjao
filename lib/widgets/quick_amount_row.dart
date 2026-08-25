import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class QuickAmountRow extends StatelessWidget {
  final ValueChanged<double> onSelecionarValor;

  const QuickAmountRow({
    super.key,
    required this.onSelecionarValor,
  });

  static const List<double> valores = [10, 20, 30, 40, 50, 100, 200, 500];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: valores.map((v) {
        final label = v >= 100 ? '+ R\$ ${v.toInt()}' : '+ R\$ ${v.toInt()}';
        return InkWell(
          onTap: () => onSelecionarValor(v),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textPri,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
