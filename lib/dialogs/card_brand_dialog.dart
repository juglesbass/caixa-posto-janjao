import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/app_haptics.dart';
import '../utils/payment_types.dart';

class CardBrandDialog extends StatelessWidget {
  final String maquinaAtiva;
  final String bandeiraSelecionada;

  const CardBrandDialog({
    super.key,
    required this.maquinaAtiva,
    required this.bandeiraSelecionada,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final corMaquina = maquinaAtiva == PaymentTypes.maquinaRede ? AppColors.rede : AppColors.cielo;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.credit_card_rounded, color: corMaquina, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cartões - Máquina $maquinaAtiva',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPri),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: PaymentTypes.bandeirasPadrao.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          itemBuilder: (context, index) {
            final bandeira = PaymentTypes.bandeirasPadrao[index];
            final selecionado = bandeira == bandeiraSelecionada;
            final corBandeira = AppColors.getCorTipo(bandeira);
            final icone = AppColors.getIconeTipo(bandeira);

            return ListTile(
              dense: true,
              leading: Icon(icone, color: corBandeira, size: 22),
              title: Text(
                bandeira,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
                  color: selecionado ? corBandeira : textPri,
                ),
              ),
              trailing: selecionado
                  ? Icon(Icons.check_circle_rounded, color: corBandeira, size: 20)
                  : null,
              onTap: () {
                AppHaptics.light();
                Navigator.of(context).pop(bandeira);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Fechar', style: TextStyle(color: textSec)),
        ),
      ],
    );
  }
}
