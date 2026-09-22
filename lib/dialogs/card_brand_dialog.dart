import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';
import '../utils/app_haptics.dart';
import '../utils/payment_types.dart';

/// Escolha da bandeira do cartão, na máquina ativa.
///
/// Cada bandeira na mesma linguagem da grade de formas: quadrado com o ícone
/// na cor dela, nome, e a escolhida acesa na própria cor com um ✓.
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
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final corMaquina = maquinaAtiva == PaymentTypes.maquinaRede ? AppColors.rede : AppColors.cielo;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bandeira do cartão',
                          style: TextStyle(fontSize: AppTexto.valor, fontWeight: FontWeight.w700, color: textPri),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(color: corMaquina, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Máquina $maquinaAtiva',
                              style: TextStyle(fontSize: AppTexto.rotulo, color: textSec),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: borderColor),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: PaymentTypes.bandeirasPadrao.length,
                itemBuilder: (context, index) {
                  final bandeira = PaymentTypes.bandeirasPadrao[index];
                  final sel = bandeira == bandeiraSelecionada;
                  final cor = AppColors.getCorTipo(bandeira);
                  return InkWell(
                    onTap: () {
                      AppHaptics.light();
                      Navigator.of(context).pop(bandeira);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? cor.withValues(alpha: isDark ? 0.18 : 0.10) : null,
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: cor.withValues(alpha: isDark ? 0.16 : 0.12),
                              borderRadius: BorderRadius.circular(AppColors.radiusXs),
                            ),
                            child: Icon(AppColors.getIconeTipo(bandeira), size: 18, color: cor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              bandeira,
                              style: TextStyle(
                                fontSize: AppTexto.corpo,
                                fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                                color: textPri,
                              ),
                            ),
                          ),
                          if (sel) Icon(Icons.check_circle_rounded, color: cor, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
