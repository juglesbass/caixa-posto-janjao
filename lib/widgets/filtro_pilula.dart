import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';

/// Um filtro em pílula (Histórico, Consulta de Produtos): borda fina; o
/// escolhido acende no azul do app. A altura vem de quem o põe na tela.
class FiltroPilula extends StatelessWidget {
  final String texto;
  final bool selecionado;
  final VoidCallback onTap;

  const FiltroPilula({super.key, required this.texto, required this.selecionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final corSel = isDark ? AppColors.accentLight : AppColors.accent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selecionado ? corSel.withValues(alpha: isDark ? 0.16 : 0.10) : surfaceColor,
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          border: Border.all(color: selecionado ? corSel : borderColor, width: selecionado ? 1.5 : 1),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: AppTexto.rotulo + 1,
            fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
            color: selecionado ? corSel : textSec,
          ),
        ),
      ),
    );
  }
}
