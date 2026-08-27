import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class QuickAmountRow extends StatelessWidget {
  final ValueChanged<double> onSelecionarValor;

  const QuickAmountRow({
    super.key,
    required this.onSelecionarValor,
  });

  static const List<List<double>> linhasValores = [
    [10, 20, 30, 40, 50],
    [60, 70, 80, 90, 100],
    [150, 200, 250, 300, 500],
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: linhasValores.asMap().entries.map((entry) {
        final rowIndex = entry.key;
        final rowList = entry.value;

        return Padding(
          padding: EdgeInsets.only(bottom: rowIndex < linhasValores.length - 1 ? 6 : 0),
          child: Row(
            children: rowList.asMap().entries.map((itemEntry) {
              final colIndex = itemEntry.key;
              final valor = itemEntry.value;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: colIndex < rowList.length - 1 ? 5 : 0),
                  child: InkWell(
                    onTap: () => onSelecionarValor(valor),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        border: Border.all(color: borderColor),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '+ R\$ ${valor.toInt()}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textPri,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
