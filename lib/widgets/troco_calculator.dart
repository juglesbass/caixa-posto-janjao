import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

class TrocoCalculator extends StatelessWidget {
  final double valorVenda;
  final double valorRecebido;
  final TextEditingController controllerRecebido;
  final ValueChanged<String> onChanged;

  const TrocoCalculator({
    super.key,
    required this.valorVenda,
    required this.valorRecebido,
    required this.controllerRecebido,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    final troco = valorRecebido - valorVenda;
    final temValorParaComparar = valorRecebido > 0 && valorVenda > 0;
    final faltaValor = temValorParaComparar && troco < 0;
    final corResultado = faltaValor ? AppColors.amber : AppColors.green;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controllerRecebido,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Valor Recebido em Dinheiro',
                labelStyle: TextStyle(fontSize: 12, color: textSec),
                hintText: 'R\$ 0,00',
                hintStyle: TextStyle(color: textSec.withValues(alpha: 0.5)),
                isDense: true,
                filled: true,
                fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  borderSide: const BorderSide(color: AppColors.green),
                ),
              ),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPri),
              onChanged: onChanged,
            ),
          ),
          if (temValorParaComparar) ...[
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: corResultado.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  border: Border.all(color: corResultado.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        faltaValor ? 'FALTA RECEBER:' : 'TROCO A DEVOLVER:',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: corResultado,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        CurrencyFormatter.formatar(troco.abs()),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: corResultado,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
