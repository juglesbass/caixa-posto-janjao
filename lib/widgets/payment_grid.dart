import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icones.dart';
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
        mainAxisExtent: 64,
      ),
      children: [
        // 1. Dinheiro
        _CardMetodo(
          label: 'Dinheiro',
          subtitulo: 'Espécie',
          icon: AppIcones.dinheiro,
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
          icon: AppIcones.pix,
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
          icon: AppIcones.cartao,
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
          icon: AppIcones.requisicao,
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
          icon: AppIcones.deposito,
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
          icon: AppIcones.despesas,
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
    // forma de pagamento — a tela nao muda de personalidade a cada toque. A
    // cor do tipo fica no quadradinho do icone, sempre acesa: presa a uma
    // forma com significado, ela identifica em vez de enfeitar.
    final corSelecao = isDark ? AppColors.accentLight : AppColors.accent;

    return InkWell(
      onTap: () {
        AppHaptics.light();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        // A borda do selecionado tem 2px, e o Container desconta a borda do
        // espaco interno. Sem compensar, o conteudo pulava 1px ao tocar,
        // saia da linha dos outros blocos e — no Cartoes, que tem nome e
        // bandeira — estourava a altura em 1 a 2px.
        padding: EdgeInsets.symmetric(
          horizontal: selecionado ? 15 : 16,
          vertical: selecionado ? 9 : 10,
        ),
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
            // Quadradinho com o icone da forma, na cor dela. O frentista
            // reconhece pela silhueta, sem ler.
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: corVibrante.withValues(alpha: isDark ? 0.16 : 0.12),
                borderRadius: BorderRadius.circular(AppColors.radiusXs),
              ),
              child: Icon(icon, size: 18, color: corVibrante),
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
                            // Altura de linha propria: sem ela o texto herda
                            // 1,43 do tema e nome + bandeira passavam da
                            // altura do botao.
                            height: 1.2,
                            color: selecionado
                                ? (isDark ? Colors.white : AppColors.accentDark)
                                : textPri,
                          ),
                        ),
                        const SizedBox(height: 2),
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
                                      height: 1.2,
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
                        height: 1.2,
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
