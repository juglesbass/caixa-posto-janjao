import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';
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

    // Segmento em vez de dois cartoes soltos: uma peca so, com a metade ativa
    // em destaque. Ocupa uma linha de 38px no lugar de dois blocos de 48.
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _BotaoMaquina(
              nome: PaymentTypes.maquinaRede,
              label: 'Rede',
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
          const SizedBox(width: 3),
          Expanded(
            child: _BotaoMaquina(
              nome: PaymentTypes.maquinaCielo,
              label: 'Cielo',
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
      borderRadius: BorderRadius.circular(AppColors.radiusXs),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selecionada
              ? (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppColors.radiusXs),
          border: Border.all(
            color: selecionada ? corSelecao : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: selecionada ? cor : AppColors.pontoApagado(isDark),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTexto.corpo,
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
