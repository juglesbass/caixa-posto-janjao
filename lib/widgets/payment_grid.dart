import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/payment_types.dart';

class PaymentGrid extends StatelessWidget {
  final String tipoAtivo;
  final String bandeiraCartaoAtiva;
  final ValueChanged<String> onSelecionarTipo;
  final VoidCallback onAbrirSeletorCartoes;

  const PaymentGrid({
    super.key,
    required this.tipoAtivo,
    required this.bandeiraCartaoAtiva,
    required this.onSelecionarTipo,
    required this.onAbrirSeletorCartoes,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    final ehCartaoAtivo = PaymentTypes.ehCartao(tipoAtivo);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        // 1. Dinheiro
        _CardMetodo(
          label: 'Dinheiro',
          subtitulo: 'Espécie',
          icon: Icons.payments_rounded,
          cor: AppColors.green,
          selecionado: tipoAtivo == PaymentTypes.dinheiro,
          onTap: () => onSelecionarTipo(PaymentTypes.dinheiro),
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPri: textPri,
          textSec: textSec,
        ),

        // 2. Pag Pix
        _CardMetodo(
          label: 'Pag Pix',
          subtitulo: 'Instantâneo',
          icon: Icons.pix_rounded,
          cor: AppColors.blue,
          selecionado: tipoAtivo == PaymentTypes.pix,
          onTap: () => onSelecionarTipo(PaymentTypes.pix),
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPri: textPri,
          textSec: textSec,
        ),

        // 3. Cartões
        _CardMetodo(
          label: 'Cartões',
          subtitulo: '$bandeiraCartaoAtiva ▼',
          icon: Icons.credit_card_rounded,
          cor: AppColors.purple,
          selecionado: ehCartaoAtivo,
          onTap: onAbrirSeletorCartoes,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPri: textPri,
          textSec: textSec,
        ),

        // 4. Requisição
        _CardMetodo(
          label: 'Requisição',
          subtitulo: 'Faturado / Prazo',
          icon: Icons.receipt_long_rounded,
          cor: AppColors.amber,
          selecionado: tipoAtivo == PaymentTypes.requisicao,
          onTap: () => onSelecionarTipo(PaymentTypes.requisicao),
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPri: textPri,
          textSec: textSec,
        ),

        // 5. Depósito
        _CardMetodo(
          label: 'Depósito',
          subtitulo: 'Bancário / Global',
          icon: Icons.account_balance_rounded,
          cor: AppColors.brown,
          selecionado: tipoAtivo == PaymentTypes.depositoGlobal,
          onTap: () => onSelecionarTipo(PaymentTypes.depositoGlobal),
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPri: textPri,
          textSec: textSec,
        ),

        // 6. Despesas
        _CardMetodo(
          label: 'Despesas',
          subtitulo: 'Retirada / Gasto',
          icon: Icons.money_off_rounded,
          cor: AppColors.red,
          selecionado: tipoAtivo == PaymentTypes.despesas,
          onTap: () => onSelecionarTipo(PaymentTypes.despesas),
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPri: textPri,
          textSec: textSec,
        ),
      ],
    );
  }
}

class _CardMetodo extends StatelessWidget {
  final String label;
  final String subtitulo;
  final IconData icon;
  final Color cor;
  final bool selecionado;
  final VoidCallback onTap;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPri;
  final Color textSec;

  const _CardMetodo({
    required this.label,
    required this.subtitulo,
    required this.icon,
    required this.cor,
    required this.selecionado,
    required this.onTap,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPri,
    required this.textSec,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado ? cor.withOpacity(0.16) : surfaceColor,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(
            color: selecionado ? cor : borderColor,
            width: selecionado ? 2.0 : 1.0,
          ),
          boxShadow: selecionado
              ? [
                  BoxShadow(
                    color: cor.withOpacity(0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
              child: Icon(icon, color: cor, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: selecionado ? cor : textPri,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: TextStyle(
                      fontSize: 11,
                      color: selecionado ? cor.withOpacity(0.85) : textSec,
                      fontWeight: selecionado ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (selecionado)
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: cor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
