import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/lancamento.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../utils/currency_formatter.dart';

class PdfService {
  /// Gera o nome do arquivo dinâmico no formato: "${operador} ${data_dd-MM-yyyy}.pdf"
  static String gerarNomeArquivo({required Turno turno}) {
    // Normalizar nome do operador (ex: "João Victor")
    final operadorLimpo = turno.operador.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    
    // Extrair data no formato dd-MM-yyyy
    String dataFormatada;
    try {
      if (turno.data.contains('/')) {
        final partes = turno.data.split(' ')[0].split('/');
        if (partes.length >= 3) {
          dataFormatada = '${partes[0].padLeft(2, '0')}-${partes[1].padLeft(2, '0')}-${partes[2]}';
        } else {
          dataFormatada = DateFormat('dd-MM-yyyy').format(DateTime.now());
        }
      } else {
        dataFormatada = DateFormat('dd-MM-yyyy').format(DateTime.now());
      }
    } catch (_) {
      dataFormatada = DateFormat('dd-MM-yyyy').format(DateTime.now());
    }

    return '$operadorLimpo $dataFormatada.pdf';
  }

  /// Salva os bytes do PDF em arquivo local antes do compartilhamento
  static Future<String?> salvarArquivoLocal({
    required Uint8List pdfBytes,
    required String nomeArquivo,
  }) async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$nomeArquivo');
      await file.writeAsBytes(pdfBytes, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('Erro ao salvar PDF localmente: $e');
      return null;
    }
  }

  /// Gera o PDF corporativo estruturado do Posto Janjão
  static Future<Uint8List> gerarPdfFechamento({
    required Turno turno,
    required TotaisTurno totais,
    required List<Lancamento> lancamentos,
  }) async {
    final doc = pw.Document();

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final corAzulEscuro = PdfColor.fromHex('#1e3a8a');
    final corVerde = PdfColor.fromHex('#16a34a');
    final corCinzaBorda = PdfColor.fromHex('#cbd5e1');
    final corCinzaFundo = PdfColor.fromHex('#f8fafc');
    final corCinzaTexto = PdfColor.fromHex('#64748b');
    final corTextoEscuro = PdfColor.fromHex('#0f172a');

    final dataEmissao = DateFormat('dd/MM/yyyy à\'s\' HH:mm').format(DateTime.now());
    final fechadoEmTexto = (turno.fechadoEm != null && turno.fechadoEm!.trim().isNotEmpty)
        ? turno.fechadoEm!
        : (turno.aberto ? 'Em Aberto' : DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()));

    final idDoc = 'Documento #PDF-${turno.numero.toString().padLeft(4, '0')}';

    // Contagem de Pix
    int qtdPix = 0;
    for (final l in lancamentos) {
      if (l.tipo.toLowerCase().contains('pix')) qtdPix++;
    }

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          380 * PdfPageFormat.point,
          680 * PdfPageFormat.point,
          marginAll: 14 * PdfPageFormat.point,
        ),
        build: (pw.Context context) {
          return pw.DefaultTextStyle(
            style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: corTextoEscuro),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ── 1. CABEÇALHO CORPORATIVO AZUL ESCURO (#1e3a8a) ──
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: corAzulEscuro,
                    borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'POSTO JANJÃO',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 13,
                              color: PdfColors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'FECHAMENTO DE TURNO · RELATÓRIO FINANCEIRO',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 6.5,
                              color: PdfColor.fromHex('#93c5fd'),
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Emitido em: $dataEmissao',
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 7.2,
                              color: PdfColor.fromHex('#e2e8f0'),
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            idDoc,
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 7.5,
                              color: PdfColor.fromHex('#e2e8f0'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Linha de Destaque Verde
                pw.Container(
                  height: 2.2,
                  color: corVerde,
                ),
                pw.SizedBox(height: 6),

                // ── 2. QUADRO INFORMATIVO DO TURNO / OPERADOR (4 COLUNAS) ──
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: corCinzaFundo,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: corCinzaBorda, width: 0.8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // Nº TURNO
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Nº TURNO', style: pw.TextStyle(font: fontBold, fontSize: 6.2, color: corCinzaTexto)),
                            pw.SizedBox(height: 2),
                            pw.Text('Turno #${turno.numero}', style: pw.TextStyle(font: fontBold, fontSize: 8.2, color: corTextoEscuro)),
                          ],
                        ),
                      ),
                      // OPERADOR CAIXA
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('OPERADOR CAIXA', style: pw.TextStyle(font: fontBold, fontSize: 6.2, color: corCinzaTexto)),
                            pw.SizedBox(height: 2),
                            pw.Text(turno.operador, style: pw.TextStyle(font: fontBold, fontSize: 8.2, color: corTextoEscuro)),
                          ],
                        ),
                      ),
                      // ABERTURA
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('ABERTURA', style: pw.TextStyle(font: fontBold, fontSize: 6.2, color: corCinzaTexto)),
                            pw.SizedBox(height: 2),
                            pw.Text(turno.data, style: pw.TextStyle(font: fontBold, fontSize: 8.2, color: corTextoEscuro)),
                          ],
                        ),
                      ),
                      // FECHAMENTO
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('FECHAMENTO', style: pw.TextStyle(font: fontBold, fontSize: 6.2, color: corVerde)),
                            pw.SizedBox(height: 2),
                            pw.Text(fechadoEmTexto, style: pw.TextStyle(font: fontBold, fontSize: 8.2, color: corTextoEscuro)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),

                // ── 3. SEÇÃO 1: CARTÕES E VOUCHERS ──
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1e293b'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('CARTÕES E VOUCHERS', style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.white)),
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 35,
                            alignment: pw.Alignment.center,
                            child: pw.Text('QTD', style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.white)),
                          ),
                          pw.Container(
                            width: 65,
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text('VALOR (R\$)', style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 2),

                // Listagem de Cartões
                if (totais.detalheCartoes.isEmpty)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    decoration: pw.BoxDecoration(
                      color: corCinzaFundo,
                      border: pw.Border.all(color: corCinzaBorda, width: 0.5),
                    ),
                    child: pw.Text('Nenhum cartão registrado neste turno', style: pw.TextStyle(fontSize: 7.5, color: corCinzaTexto)),
                  )
                else
                  ...totais.detalheCartoes.entries.map((e) {
                    final nome = e.key;
                    final total = e.value.total;
                    final qtd = e.value.qtd;

                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('#f1f5f9'), width: 0.5)),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Text(nome, style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#334155'))),
                          ),
                          pw.Container(
                            width: 35,
                            alignment: pw.Alignment.center,
                            child: pw.Text('$qtd un', style: pw.TextStyle(fontSize: 7.5, color: corCinzaTexto)),
                          ),
                          pw.Container(
                            width: 65,
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(CurrencyFormatter.formatar(total), style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
                          ),
                        ],
                      ),
                    );
                  }),

                // Total Cartões
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#eff6ff'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                    border: pw.Border.all(color: PdfColor.fromHex('#93c5fd'), width: 0.8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('TOTAL CARTÕES', style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColor.fromHex('#1e40af'))),
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 35,
                            alignment: pw.Alignment.center,
                            child: pw.Text('${totais.qtdCartoes} un', style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColor.fromHex('#1e40af'))),
                          ),
                          pw.Container(
                            width: 65,
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(CurrencyFormatter.formatar(totais.cartoes), style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColor.fromHex('#1e40af'))),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),

                // ── 4. SEÇÃO 2: OUTROS MEIOS DE PAGAMENTO ──
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1e293b'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('OUTROS MEIOS DE PAGAMENTO', style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.white)),
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 35,
                            alignment: pw.Alignment.center,
                            child: pw.Text('QTD', style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.white)),
                          ),
                          pw.Container(
                            width: 65,
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text('VALOR (R\$)', style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 2),

                _itemOutroMeio('Pag Pix', totais.pix, qtdPix > 0 ? '$qtdPix un' : null, PdfColor.fromHex('#2563eb'), fontBold, fontRegular),
                _itemOutroMeio('Sobra de Dinheiro', totais.dinheiro, null, PdfColor.fromHex('#16a34a'), fontBold, fontRegular),
                _itemOutroMeio('Requisição', totais.requisicao, null, PdfColor.fromHex('#7c3aed'), fontBold, fontRegular),
                _itemOutroMeio('Depósito Global', totais.depositoGlobal, null, PdfColor.fromHex('#d97706'), fontBold, fontRegular),
                _itemOutroMeio('Despesas', totais.despesas, null, PdfColor.fromHex('#dc2626'), fontBold, fontRegular),
                pw.SizedBox(height: 6),

                // ── 5. SEÇÃO 3: CONCILIAÇÃO DE VENDAS ──
                // Total Pista
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#3730a3'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    border: pw.Border.all(color: PdfColor.fromHex('#6366f1'), width: 1.0),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('TOTAL DE VENDAS PISTA:', style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColor.fromHex('#e0e7ff'))),
                      pw.Text(CurrencyFormatter.formatar(totais.totalGeral), style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 3),

                // Total Sistema (PDV)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1e293b'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    border: pw.Border.all(color: PdfColor.fromHex('#475569'), width: 0.8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('TOTAL DE VENDAS SISTEMA (PDV):', style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColor.fromHex('#cbd5e1'))),
                      pw.Text(CurrencyFormatter.formatar(turno.vendasSistema), style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColor.fromHex('#f8fafc'))),
                    ],
                  ),
                ),
                pw.SizedBox(height: 3),

                // Diferença
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: totais.diferenca.abs() < 0.01
                        ? PdfColor.fromHex('#064e3b')
                        : (totais.diferenca > 0 ? PdfColor.fromHex('#78350f') : PdfColor.fromHex('#7f1d1d')),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    border: pw.Border.all(
                      color: totais.diferenca.abs() < 0.01
                          ? PdfColor.fromHex('#10b981')
                          : (totais.diferenca > 0 ? PdfColor.fromHex('#f59e0b') : PdfColor.fromHex('#ef4444')),
                      width: 1.0,
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        totais.diferenca.abs() < 0.01
                            ? 'CAIXA 100% BATIDO (SEM DIFERENÇA):'
                            : (totais.diferenca > 0 ? 'SOBRA NA PISTA:' : 'FALTA NA PISTA:'),
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 8,
                          color: totais.diferenca.abs() < 0.01
                              ? PdfColor.fromHex('#d1fae5')
                              : (totais.diferenca > 0 ? PdfColor.fromHex('#fef3c7') : PdfColor.fromHex('#fee2e2')),
                        ),
                      ),
                      pw.Text(
                        CurrencyFormatter.formatar(totais.diferenca),
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: totais.diferenca.abs() < 0.01
                              ? PdfColor.fromHex('#d1fae5')
                              : (totais.diferenca > 0 ? PdfColor.fromHex('#fef3c7') : PdfColor.fromHex('#fee2e2')),
                        ),
                      ),
                    ],
                  ),
                ),

                if (turno.observacao.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(
                      color: corCinzaFundo,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                      border: pw.Border.all(color: corCinzaBorda, width: 0.5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('OBSERVAÇÕES / JUSTIFICATIVA:', style: pw.TextStyle(font: fontBold, fontSize: 6.5, color: corCinzaTexto)),
                        pw.Text(turno.observacao, style: pw.TextStyle(fontSize: 7.5, color: corTextoEscuro)),
                      ],
                    ),
                  ),
                ],

                pw.Spacer(),

                // ── 6. ASSINATURAS DO OPERADOR E GERÊNCIA ──
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Container(height: 0.6, color: corCinzaBorda),
                          pw.SizedBox(height: 3),
                          pw.Text('Assinatura: ${turno.operador}', style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: corCinzaTexto)),
                          pw.Text('Operador do Caixa', style: pw.TextStyle(font: fontBold, fontSize: 6, color: corCinzaTexto)),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Container(height: 0.6, color: corCinzaBorda),
                          pw.SizedBox(height: 3),
                          pw.Text('Assinatura: Gerência', style: pw.TextStyle(font: fontRegular, fontSize: 6.5, color: corCinzaTexto)),
                          pw.Text('Conferência do Fechamento', style: pw.TextStyle(font: fontBold, fontSize: 6, color: corCinzaTexto)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),

                // ── 7. RODAPÉ ──
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Posto Janjão · Sistema de Gestão de Caixa', style: pw.TextStyle(fontSize: 6, color: corCinzaTexto)),
                    pw.Text('Documento Autenticado · 1/1', style: pw.TextStyle(fontSize: 6, color: corCinzaTexto)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _itemOutroMeio(
    String label,
    double valor,
    String? qtd,
    PdfColor corBarra,
    pw.Font fontBold,
    pw.Font fontRegular,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 2),
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColor.fromHex('#e2e8f0'), width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(width: 3, height: 10, color: corBarra, margin: const pw.EdgeInsets.only(right: 6)),
              pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColor.fromHex('#1e293b'))),
            ],
          ),
          pw.Row(
            children: [
              pw.Container(
                width: 35,
                alignment: pw.Alignment.center,
                child: pw.Text(qtd ?? '-', style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromHex('#64748b'))),
              ),
              pw.Container(
                width: 65,
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  CurrencyFormatter.formatar(valor),
                  style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: valor > 0 ? corBarra : PdfColor.fromHex('#94a3b8')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
