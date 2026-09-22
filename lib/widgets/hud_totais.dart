import 'package:flutter/material.dart';
import '../models/totais_turno.dart';
import '../theme/app_colors.dart';
import '../theme/app_icones.dart';
import '../theme/app_texto.dart';
import '../utils/currency_formatter.dart';

class HudTotais extends StatelessWidget {
  final TotaisTurno totais;
  final VoidCallback? onTapDetalhes;

  const HudTotais({
    super.key,
    required this.totais,
    this.onTapDetalhes,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    return InkWell(
      onTap: onTapDetalhes,
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Topo do HUD: Total Geral ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL DO TURNO',
                      style: TextStyle(
                        fontSize: AppTexto.rotulo,
                        fontWeight: FontWeight.bold,
                        color: textSec,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      CurrencyFormatter.formatar(totais.totalGeral),
                      // Fonte comum e bem pesada no numero grande: a
                      // monoespacada deixava o total com cara de terminal.
                      style: TextStyle(
                        fontSize: AppTexto.total,
                        fontWeight: FontWeight.w800,
                        color: textPri,
                        letterSpacing: -0.5,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
                // O bloco inteiro abre o resumo: melhor dizer isso com palavra
                // do que com um icone de carteira que nao leva a lugar obvio.
                const Row(
                  children: [
                    Text(
                      'resumo',
                      style: TextStyle(fontSize: AppTexto.rotulo, color: AppColors.accentLight),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.accentLight),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: borderColor),
            const SizedBox(height: 12),

            // ── Totais por forma de pagamento ──
            //
            // Divisórias de altura fixa, e não IntrinsicHeight: a medição
            // automática contava o valor no tamanho de antes de o FittedBox
            // encolher, e sobrava um vão vazio embaixo dos números.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Total(
                    label: 'DINHEIRO',
                    valor: CurrencyFormatter.formatar(totais.dinheiro),
                    cor: AppColors.green,
                    icone: AppIcones.dinheiro,
                  ),
                ),
                _Divisoria(cor: borderColor),
                Expanded(
                  child: _Total(
                    label: 'PIX',
                    valor: CurrencyFormatter.formatar(totais.pix),
                    cor: AppColors.blue,
                    icone: AppIcones.pix,
                  ),
                ),
                _Divisoria(cor: borderColor),
                Expanded(
                  child: _Total(
                    label: 'CARTÕES',
                    valor: CurrencyFormatter.formatar(totais.cartoes),
                    cor: AppColors.purple,
                    icone: AppIcones.cartao,
                    quantidade: totais.qtdCartoes > 0 ? '${totais.qtdCartoes}×' : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Um total por forma de pagamento: rotulo em cima, valor embaixo, sem caixa.
///
/// A cor aparece num ponto de 7px. Antes cada um destes era um bloco tingido,
/// e tres blocos coloridos lado a lado brigavam com o total geral logo acima —
/// que e o numero que o frentista precisa enxergar primeiro.
class _Total extends StatelessWidget {
  final String label;
  final String valor;
  final Color cor;
  final String? quantidade;
  final IconData icone;

  const _Total({
    required this.label,
    required this.valor,
    required this.cor,
    this.quantidade,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textTer = isDark ? AppColors.darkTextTer : AppColors.lightTextTer;
    final corVibrante = isDark && cor == AppColors.purple ? AppColors.purpleLight : cor;

    // Alinhado pelo topo: em celular estreito cada coluna encolhe numa
    // proporcao diferente, e centralizado os tres rotulos saiam desnivelados.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // Encolhe em vez de cortar: num celular de 375px, "CARTOES 12x" passa
        // uns pixels do terco da largura, e rotulo cortado ("CARTO...") e pior
        // que rotulo 2% menor. Com o que cabe, nada muda de tamanho.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // O mesmo icone da grade, pequeno: liga o subtotal a forma.
              Icon(icone, size: 14, color: corVibrante),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTexto.rotulo,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                  color: textTer,
                ),
              ),
              if (quantidade != null) ...[
                const SizedBox(width: 4),
                Text(
                  quantidade!,
                  style: TextStyle(fontSize: AppTexto.rotulo, color: textTer),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            valor,
            style: TextStyle(
              // Fonte comum, que e mais estreita que a monoespacada: em 16
              // "R$ 9.999,99" cabe num terco de um celular de 375px.
              fontSize: AppTexto.valor,
              fontWeight: FontWeight.w800,
              color: textPri,
            ),
          ),
        ),
      ],
    );
  }
}

/// Linha vertical entre os totais, na altura do rótulo mais o valor.
class _Divisoria extends StatelessWidget {
  final Color cor;
  const _Divisoria({required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: cor,
    );
  }
}
