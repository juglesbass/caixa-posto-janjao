import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../theme/app_colors.dart';
import '../theme/app_icones.dart';
import '../theme/app_texto.dart';
import '../utils/currency_formatter.dart';
import '../widgets/janela.dart';

class AnalyticsDialog extends StatelessWidget {
  final Turno turno;
  final TotaisTurno totais;

  const AnalyticsDialog({
    super.key,
    required this.turno,
    required this.totais,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final textTer = isDark ? AppColors.darkTextTer : AppColors.lightTextTer;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final blocoBg = isDark ? AppColors.darkBg : AppColors.lightBg;

    final totalGeral = totais.totalGeral > 0 ? totais.totalGeral : 1.0;
    final percCartoes = (totais.cartoes / totalGeral) * 100;
    final percPix = (totais.pix / totalGeral) * 100;
    final percDinheiro = (totais.dinheiro / totalGeral) * 100;
    final percRequisicao = (totais.requisicao / totalGeral) * 100;
    final percDeposito = (totais.depositoGlobal / totalGeral) * 100;
    final percDespesas = (totais.despesas / totalGeral) * 100;

    final qtdDinheiro = totais.qtdDinheiro > 0 ? totais.qtdDinheiro : (totais.dinheiro > 0 ? 1 : 0);
    final qtdRequisicao = totais.qtdRequisicao > 0 ? totais.qtdRequisicao : (totais.requisicao > 0 ? 1 : 0);
    final qtdDeposito = totais.qtdDepositoGlobal > 0 ? totais.qtdDepositoGlobal : (totais.depositoGlobal > 0 ? 1 : 0);
    final qtdDespesas = totais.qtdDespesas > 0 ? totais.qtdDespesas : (totais.despesas > 0 ? 1 : 0);
    final totalLancamentos = totais.qtdCartoes +
        totais.qtdPix +
        qtdDinheiro +
        qtdRequisicao +
        qtdDeposito +
        qtdDespesas;

    // Mesmas cores e ícones das formas de pagamento no resto do app: antes o
    // Pix saía verde e o dinheiro âmbar só aqui.
    final linhas = <Widget>[
      _itemMetrica(
        titulo: 'Cartões',
        icone: AppIcones.cartao,
        valor: totais.cartoes,
        percentual: percCartoes,
        cor: AppColors.purple,
        quantidade: '${totais.qtdCartoes} vendas',
        isDark: isDark,
      ),
      _itemMetrica(
        titulo: 'Pag Pix',
        icone: AppIcones.pix,
        valor: totais.pix,
        percentual: percPix,
        cor: AppColors.blue,
        quantidade: totais.qtdPix > 0 ? '${totais.qtdPix} vendas' : null,
        isDark: isDark,
      ),
      _itemMetrica(
        titulo: 'Dinheiro Pista',
        icone: AppIcones.dinheiro,
        valor: totais.dinheiro,
        percentual: percDinheiro,
        cor: AppColors.green,
        quantidade: qtdDinheiro > 0 ? '$qtdDinheiro vendas' : null,
        isDark: isDark,
      ),
      if (totais.requisicao > 0)
        _itemMetrica(
          titulo: 'Requisição / Faturado',
          icone: AppIcones.requisicao,
          valor: totais.requisicao,
          percentual: percRequisicao,
          cor: AppColors.amber,
          quantidade: '$qtdRequisicao vendas',
          isDark: isDark,
        ),
      if (totais.depositoGlobal > 0)
        _itemMetrica(
          titulo: 'Depósito Global',
          icone: AppIcones.deposito,
          valor: totais.depositoGlobal,
          percentual: percDeposito,
          cor: AppColors.brown,
          quantidade: '$qtdDeposito vendas',
          isDark: isDark,
        ),
      if (totais.despesas > 0)
        _itemMetrica(
          titulo: 'Despesas',
          icone: AppIcones.despesas,
          valor: totais.despesas,
          percentual: percDespesas,
          cor: AppColors.red,
          quantidade: '$qtdDespesas lançamentos',
          isDark: isDark,
        ),
    ];

    return Dialog(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          children: [
            CabecalhoJanela(
              icone: Icons.auto_graph_rounded,
              cor: AppColors.purple,
              titulo: 'Analytics & Desempenho',
              subtitulo: 'Gráficos de vendas e distribuição do turno',
              onFechar: () => Navigator.of(context).pop(),
            ),
            Divider(color: borderCol, height: 24),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Total Geral ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: blocoBg,
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                        border: Border.all(color: borderCol),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Vendido no Turno', style: TextStyle(color: textSec, fontSize: AppTexto.rotulo)),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    CurrencyFormatter.formatar(totais.totalGeral),
                                    style: TextStyle(color: textPri, fontSize: 22, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 130),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text('Qtd Lançamentos', style: TextStyle(color: textSec, fontSize: AppTexto.rotulo)),
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '$totalLancamentos un',
                                    style: TextStyle(
                                      fontFamily: AppTexto.numeros,
                                      color: textPri,
                                      fontSize: AppTexto.valor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text(
                      'DISTRIBUIÇÃO DE FORMAS DE PAGAMENTO',
                      style: TextStyle(fontSize: AppTexto.rotulo, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: textTer),
                    ),
                    const SizedBox(height: 10),

                    // Barra Visual de Progresso Multicolorida
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 12,
                        child: Row(
                          children: [
                            if (percCartoes > 0)
                              Expanded(
                                flex: math.max(1, (percCartoes * 10).toInt()),
                                child: Container(color: AppColors.purple),
                              ),
                            if (percPix > 0)
                              Expanded(
                                flex: math.max(1, (percPix * 10).toInt()),
                                child: Container(color: AppColors.blue),
                              ),
                            if (percDinheiro > 0)
                              Expanded(
                                flex: math.max(1, (percDinheiro * 10).toInt()),
                                child: Container(color: AppColors.green),
                              ),
                            if (percRequisicao > 0)
                              Expanded(
                                flex: math.max(1, (percRequisicao * 10).toInt()),
                                child: Container(color: AppColors.amber),
                              ),
                            if (percDeposito > 0)
                              Expanded(
                                flex: math.max(1, (percDeposito * 10).toInt()),
                                child: Container(color: AppColors.brown),
                              ),
                            if (percDespesas > 0)
                              Expanded(
                                flex: math.max(1, (percDespesas * 10).toInt()),
                                child: Container(color: AppColors.red),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Itens da Distribuição: um bloco só, separado por fio
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: blocoBg,
                        borderRadius: BorderRadius.circular(AppColors.radiusLg),
                        border: Border.all(color: borderCol),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < linhas.length; i++) ...[
                            if (i > 0) Divider(height: 1, thickness: 1, color: borderCol),
                            linhas[i],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: BotaoSecundario(texto: 'Fechar', onPressed: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemMetrica({
    required String titulo,
    required IconData icone,
    required double valor,
    required double percentual,
    required Color cor,
    String? quantidade,
    required bool isDark,
  }) {
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          IconeJanela(icone: icone, cor: cor, tamanho: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: TextStyle(color: textPri, fontWeight: FontWeight.w700, fontSize: AppTexto.corpo)),
                if (quantidade != null)
                  Text(quantidade, style: TextStyle(color: textSec, fontSize: AppTexto.rotulo)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 135),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    CurrencyFormatter.formatar(valor),
                    style: TextStyle(
                      fontFamily: AppTexto.numeros,
                      color: textPri,
                      fontWeight: FontWeight.w600,
                      fontSize: AppTexto.corpo,
                    ),
                  ),
                ),
                Text(
                  '${percentual.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontFamily: AppTexto.numeros,
                    color: textSec,
                    fontSize: AppTexto.rotulo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
