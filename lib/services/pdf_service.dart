import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/lancamento.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../utils/currency_formatter.dart';

class PdfService {
  /// Gera o arquivo PDF de Fechamento de Turno com layout de cupom térmico e A4
  static Future<Uint8List> gerarPdfFechamento({
    required Turno turno,
    required TotaisTurno totais,
    required List<Lancamento> lancamentos,
  }) async {
    final doc = pw.Document();

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.DefaultTextStyle(
            style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.black),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ── HEADER ──
                pw.Center(
                  child: pw.Text(
                    'POSTO JANJÃO',
                    style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.black),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'FECHAMENTO DE TURNO #${turno.numero}',
                    style: pw.TextStyle(font: fontBold, fontSize: 10),
                  ),
                ),
                pw.SizedBox(height: 4),
                _linhaDivisoria(),

                // ── DADOS DO TURNO ──
                _linhaDupla('Operador:', turno.operador, fontBold),
                _linhaDupla('Aberto em:', turno.data, fontBold),
                if (turno.fechadoEm != null && turno.fechadoEm!.isNotEmpty)
                  _linhaDupla('Fechado em:', turno.fechadoEm!, fontBold),
                _linhaDivisoria(),

                // ── CARTÕES E VOUCHERS ──
                pw.Text(
                  'DETALHAMENTO DE CARTÕES',
                  style: pw.TextStyle(font: fontBold, fontSize: 9),
                ),
                pw.SizedBox(height: 3),
                if (totais.detalheCartoes.isEmpty)
                  pw.Text('Nenhum cartão registrado', style: const pw.TextStyle(fontSize: 8))
                else
                  ...totais.detalheCartoes.entries.map((e) {
                    final nome = e.key;
                    final total = e.value.total;
                    final qtd = e.value.qtd;
                    return _linhaDupla(
                      '$nome ($qtd un)',
                      CurrencyFormatter.formatar(total),
                      fontRegular,
                    );
                  }),
                _linhaPontilhada(),
                _linhaDupla(
                  'Total Cartões (${totais.qtdCartoes} un):',
                  CurrencyFormatter.formatar(totais.cartoes),
                  fontBold,
                ),
                _linhaDivisoria(),

                // ── RESUMO FINANCEIRO ──
                _linhaDupla('Dinheiro em Espécie:', CurrencyFormatter.formatar(totais.dinheiro), fontRegular),
                _linhaDupla('Pagamento Pix:', CurrencyFormatter.formatar(totais.pix), fontRegular),
                if (totais.requisicao > 0)
                  _linhaDupla('Requisição (A Prazo):', CurrencyFormatter.formatar(totais.requisicao), fontRegular),
                if (totais.depositoGlobal > 0)
                  _linhaDupla('Depósito Global:', CurrencyFormatter.formatar(totais.depositoGlobal), fontRegular),
                if (totais.despesas > 0)
                  _linhaDupla('Despesas / Retiradas:', CurrencyFormatter.formatar(totais.despesas), fontRegular),
                _linhaDivisoria(),

                // ── TOTAL GERAL ──
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('TOTAL GERAL:', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                      pw.Text(
                        CurrencyFormatter.formatar(totais.totalGeral),
                        style: pw.TextStyle(font: fontBold, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                _linhaDivisoria(),

                // ── GAVETA E SANGRIA ──
                if (totais.fundoCaixa > 0)
                  _linhaDupla('Fundo de Caixa (Inicial):', CurrencyFormatter.formatar(totais.fundoCaixa), fontRegular),
                if (totais.sangrias > 0)
                  _linhaDupla('Sangrias p/ Cofre (${totais.qtdSangrias} un):', CurrencyFormatter.formatar(totais.sangrias), fontRegular),
                if (totais.fundoCaixa > 0 || totais.sangrias > 0)
                  _linhaDupla('Dinheiro na Gaveta (Atual):', CurrencyFormatter.formatar(totais.dinheiroGaveta), fontBold),
                
                // ── AUDITORIA DE PISTA ──
                if (turno.vendasSistema > 0) ...[
                  _linhaDivisoria(),
                  pw.Text('CONCILIAÇÃO COM PDV', style: pw.TextStyle(font: fontBold, fontSize: 9)),
                  _linhaDupla('Vendas Sistema (PDV):', CurrencyFormatter.formatar(turno.vendasSistema), fontRegular),
                  _linhaDupla(
                    totais.ehSobra
                        ? '▲ SOBRA NA PISTA:'
                        : totais.ehFalta
                            ? '▼ FALTA NA PISTA:'
                            : '✅ CAIXA 100% BATIDO:',
                    CurrencyFormatter.formatar(totais.diferenca),
                    fontBold,
                  ),
                ],

                if (turno.observacao.isNotEmpty) ...[
                  _linhaDivisoria(),
                  pw.Text('OBSERVAÇÕES:', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                  pw.Text(turno.observacao, style: const pw.TextStyle(fontSize: 8)),
                ],

                // ── ASSINATURAS ──
                pw.SizedBox(height: 18),
                pw.Center(
                  child: pw.Text('____________________________________', style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Center(
                  child: pw.Text('Assinatura do Operador', style: const pw.TextStyle(fontSize: 7)),
                ),
                pw.SizedBox(height: 12),
                pw.Center(
                  child: pw.Text('Documento gerado automaticamente pelo Sistema Caixa Janjão',
                      style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _linhaDivisoria() {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
      ),
    );
  }

  static pw.Widget _linhaPontilhada() {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 3),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.5, style: pw.BorderStyle.dashed)),
      ),
    );
  }

  static pw.Widget _linhaDupla(String label, String valor, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 8.5)),
          pw.Text(valor, style: pw.TextStyle(font: font, fontSize: 8.5)),
        ],
      ),
    );
  }
}
