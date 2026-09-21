import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';
import '../utils/app_haptics.dart';
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

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Linha, nao cartao: baixa o bastante para as seis formas caberem sem
      // empurrar o campo de valor para fora da tela, alta o bastante para dar
      // alvo confortavel ao dedo no meio do movimento.
      //
      // Altura fixa, e nao proporcao da largura: com proporcao, o botao
      // encolhia junto com o celular, e num aparelho de 375px (iPhone SE,
      // 12 mini) o de Cartoes — nome em cima, bandeira embaixo — ficava mais
      // baixo que o proprio conteudo.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 62,
      ),
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

  /// "Master Débito" nao cabe na pastilha de uma linha de 46px, e cortado no
  /// meio ("Master Dé...") e pior que abreviado. Crédito e Débito viram Créd. e
  /// Déb., que e como o pessoal fala e como sai na maquininha.
  static String _bandeiraCurta(String bandeira) {
    return bandeira
        .replaceAll(' \u25BC', '')
        .replaceAll('Crédito', 'Créd.')
        .replaceAll('Débito', 'Déb.')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final corVibrante = isDark && cor == AppColors.purple ? AppColors.purpleLight : cor;
    // Selecionado fala sempre a mesma lingua, o azul do app, seja qual for a
    // forma de pagamento. A cor do tipo continua no icone e no ponto da
    // direita, entao nada de identificacao se perde — o que sai e a tela
    // inteira mudando de personalidade a cada toque.
    final corSelecao = isDark ? AppColors.accentLight : AppColors.accent;

    return InkWell(
      onTap: () {
        AppHaptics.light();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selecionado
              ? corSelecao.withValues(alpha: isDark ? 0.16 : 0.08)
              : surfaceColor,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(
            color: selecionado ? corSelecao : borderColor,
            width: selecionado ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // O ponto no lugar da caixa de icone: mesma identificacao por cor,
            // numa linha que ocupa metade da altura.
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: corVibrante, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: isCartao
                  // Nome em cima, bandeira embaixo: lado a lado, "Master Déb."
                  // nao cabia na largura de meia tela e saia cortado.
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: AppTexto.corpo,
                            fontWeight: FontWeight.bold,
                            color: selecionado
                                ? (isDark ? Colors.white : AppColors.accentDark)
                                : textPri,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: selecionado
                                  ? corSelecao.withValues(alpha: isDark ? 0.22 : 0.12)
                                  : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: selecionado
                                    ? corSelecao.withValues(alpha: 0.5)
                                    : borderColor,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _bandeiraCurta(subtitulo),
                                    style: TextStyle(
                                      fontSize: AppTexto.rotulo,
                                      fontWeight: FontWeight.w600,
                                      color: selecionado
                                          ? (isDark ? AppColors.darkTextPri : AppColors.accentDark)
                                          : textSec,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  size: 12,
                                  color: selecionado
                                      ? (isDark ? AppColors.darkTextPri : AppColors.accentDark)
                                      : textSec,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontSize: AppTexto.corpo,
                        fontWeight: FontWeight.bold,
                        color: selecionado
                            ? (isDark ? Colors.white : AppColors.accentDark)
                            : textPri,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
