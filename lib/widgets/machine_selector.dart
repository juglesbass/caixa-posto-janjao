import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/app_haptics.dart';
import '../utils/payment_types.dart';

class MachineSelector extends StatelessWidget {
  final String maquinaAtiva;
  final ValueChanged<String> onSelecionar;

  const MachineSelector({
    super.key,
    required this.maquinaAtiva,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'MÁQUINA ATIVA (POS)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textSec,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _BotaoMaquina(
                nome: PaymentTypes.maquinaRede,
                label: 'Máquina REDE',
                cor: AppColors.rede,
                selecionada: maquinaAtiva == PaymentTypes.maquinaRede,
                onTap: () {
                  AppHaptics.selection();
                  onSelecionar(PaymentTypes.maquinaRede);
                },
                surfaceColor: surfaceColor,
                borderColor: borderColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BotaoMaquina(
                nome: PaymentTypes.maquinaCielo,
                label: 'Máquina CIELO',
                cor: AppColors.cielo,
                selecionada: maquinaAtiva == PaymentTypes.maquinaCielo,
                onTap: () {
                  AppHaptics.selection();
                  onSelecionar(PaymentTypes.maquinaCielo);
                },
                surfaceColor: surfaceColor,
                borderColor: borderColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BotaoMaquina extends StatelessWidget {
  final String nome;
  final String label;
  final Color cor;
  final bool selecionada;
  final VoidCallback onTap;
  final Color surfaceColor;
  final Color borderColor;

  const _BotaoMaquina({
    required this.nome,
    required this.label,
    required this.cor,
    required this.selecionada,
    required this.onTap,
    required this.surfaceColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // A maquina ativa usa a mesma marca de selecao da grade de pagamento: o
    // azul do app. A cor da operadora fica no icone e no nome, entao Rede
    // continua vermelha e Cielo continua azul — sem pintar meia tela.
    final corSelecao = isDark ? AppColors.accentLight : AppColors.accent;
    final corApagada = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: selecionada
              ? corSelecao.withValues(alpha: isDark ? 0.16 : 0.08)
              : surfaceColor,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(
            color: selecionada ? corSelecao : borderColor,
            width: selecionada ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.point_of_sale_rounded,
              color: selecionada ? cor : corApagada,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: selecionada
                    ? (isDark ? AppColors.darkTextPri : AppColors.lightTextPri)
                    : corApagada,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
