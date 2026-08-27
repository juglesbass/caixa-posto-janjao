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
          isCartao: true,
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
  final bool isCartao;

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
    this.isCartao = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final corVibrante = isDark && cor == AppColors.purple ? AppColors.purpleLight : cor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado
              ? corVibrante.withOpacity(isDark ? 0.20 : 0.14)
              : surfaceColor,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(
            color: selecionado
                ? (isDark ? corVibrante : cor)
                : borderColor,
            width: selecionado ? 2.0 : 1.0,
          ),
          boxShadow: selecionado
              ? [
                  BoxShadow(
                    color: corVibrante.withOpacity(0.35),
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
                color: corVibrante.withOpacity(isDark ? 0.25 : 0.18),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
              child: Icon(icon, color: corVibrante, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: isCartao
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: selecionado ? (isDark ? Colors.white : cor) : textPri,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: selecionado
                                ? (isDark ? corVibrante.withOpacity(0.25) : cor.withOpacity(0.12))
                                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: selecionado
                                  ? (isDark ? corVibrante.withOpacity(0.6) : cor.withOpacity(0.4))
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  subtitulo.replaceAll(' ▼', ''),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: selecionado
                                        ? (isDark ? const Color(0xFFF1F5F9) : cor)
                                        : textSec,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 14,
                                color: selecionado
                                    ? (isDark ? const Color(0xFFF1F5F9) : cor)
                                    : textSec,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: selecionado ? (isDark ? Colors.white : cor) : textPri,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitulo,
                          style: TextStyle(
                            fontSize: 11,
                            color: selecionado ? (isDark ? const Color(0xFFE2E8F0) : cor) : textSec,
                            fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
            ),
            if (selecionado)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isDark ? (cor == AppColors.purple ? AppColors.purpleLight : cor) : cor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: corVibrante.withOpacity(0.6),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
