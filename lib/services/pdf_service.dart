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
import '../utils/conciliacao.dart';
import '../utils/currency_formatter.dart';
import '../utils/payment_types.dart';
import 'auth_service.dart';

class PdfService {
  static pw.Font? _cachedFontRegular;
  static pw.Font? _cachedFontBold;

  static Future<({pw.Font regular, pw.Font bold})> _obterFontes() async {
    if (_cachedFontRegular != null && _cachedFontBold != null) {
      return (regular: _cachedFontRegular!, bold: _cachedFontBold!);
    }
    try {
      _cachedFontRegular ??= await PdfGoogleFonts.robotoRegular().timeout(const Duration(milliseconds: 1500));
      _cachedFontBold ??= await PdfGoogleFonts.robotoBold().timeout(const Duration(milliseconds: 1500));
      return (regular: _cachedFontRegular!, bold: _cachedFontBold!);
    } catch (_) {
      _cachedFontRegular ??= pw.Font.helvetica();
      _cachedFontBold ??= pw.Font.helveticaBold();
      return (regular: _cachedFontRegular!, bold: _cachedFontBold!);
    }
  }

  /// Dia da semana de uma data “dd/MM/yyyy”, em caixa alta.
  ///
  /// Nomes fixos em vez de DateFormat('EEEE', 'pt_BR'): o app nunca chama
  /// initializeDateFormatting, e pedir a locale sem isso lança exceção.
  static String _diaDaSemana(String data) {
    const nomes = [
      'SEGUNDA-FEIRA',
      'TERÇA-FEIRA',
      'QUARTA-FEIRA',
      'QUINTA-FEIRA',
      'SEXTA-FEIRA',
      'SÁBADO',
      'DOMINGO',
    ];
    try {
      final dia = DateFormat('dd/MM/yyyy').parseStrict(data.trim().split(' ').first);
      return nomes[dia.weekday - 1];
    } catch (_) {
      return '-';
    }
  }

  /// Gera o nome do arquivo no formato: "${operador} ${data_dd-MM-yyyy}.pdf",
  /// com sufixo "_v2", "_v3"... quando o turno já foi reaberto e fechado antes.
  ///
  /// A data é a do CAIXA ([Turno.dataCaixa]), não a hora em que o app foi
  /// aberto. O funcionário da noite fecha dois caixas — até a meia-noite e até
  /// as 6h — e, abrindo o app só depois da meia-noite, os dois saíam com a
  /// mesma data e o mesmo nome. O segundo chegava ao Drive como "_v2", que o
  /// gerente lê como correção do primeiro. Com a data do caixa, cada um tem o
  /// seu dia e o seu nome.
  ///
  /// Nome repetido não destrói nada: o webhook do Drive é estritamente aditivo
  /// e, se o nome já existir na pasta, cria o próximo "_vN" em vez de
  /// sobrescrever ou mandar o anterior para a lixeira.
  static String gerarNomeArquivo({required Turno turno}) {
    // Normalizar nome do operador (ex: "João Victor")
    final operadorLimpo = turno.operador.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    
    // Extrair data no formato dd-MM-yyyy
    String dataFormatada;
    final dataBase = turno.dataCaixa;
    try {
      if (dataBase.contains('/')) {
        final partes = dataBase.split(' ')[0].split('/');
        if (partes.length >= 3) {
          dataFormatada = '${partes[0].padLeft(2, '0')}-${partes[1].padLeft(2, '0')}-${partes[2]}';
        } else {
          dataFormatada = DateFormat('dd-MM-yyyy').format(DateTime.now());
        }
      } else if (dataBase.contains('-')) {
        final partes = dataBase.split(' ')[0].split('-');
        if (partes.length >= 3) {
          if (partes[0].length == 4) {
            // ISO yyyy-MM-dd
            dataFormatada = '${partes[2].padLeft(2, '0')}-${partes[1].padLeft(2, '0')}-${partes[0]}';
          } else {
            dataFormatada = '${partes[0].padLeft(2, '0')}-${partes[1].padLeft(2, '0')}-${partes[2]}';
          }
        } else {
          dataFormatada = DateFormat('dd-MM-yyyy').format(DateTime.now());
        }
      } else {
        dataFormatada = DateFormat('dd-MM-yyyy').format(DateTime.now());
      }
    } catch (_) {
      dataFormatada = DateFormat('dd-MM-yyyy').format(DateTime.now());
    }

    final sufixoVersao = (turno.versao > 1) ? '_v${turno.versao}' : '';
    final baseNome = operadorLimpo.isNotEmpty ? '$operadorLimpo $dataFormatada' : dataFormatada;
    return '$baseNome$sufixoVersao.pdf';
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

    final fontes = await _obterFontes();
    final fontRegular = fontes.regular;
    final fontBold = fontes.bold;

    final corAzulEscuro = PdfColor.fromHex('#1e3a8a');
    final corVerde = PdfColor.fromHex('#16a34a');
    final corCinzaBorda = PdfColor.fromHex('#cbd5e1');
    final corCinzaFundo = PdfColor.fromHex('#f8fafc');
    final corCinzaTexto = PdfColor.fromHex('#64748b');
    final corTextoEscuro = PdfColor.fromHex('#0f172a');

    final dataEmissao = DateFormat('dd/MM/yyyy à\'s\' HH:mm').format(DateTime.now());

    final idDoc = 'Documento #PDF-${turno.numero.toString().padLeft(4, '0')}';

    // Contagem de Pix
    int qtdPix = 0;
    for (final l in lancamentos) {
      if (l.tipo.toLowerCase().contains('pix')) qtdPix++;
    }

    // Dimensões otimizadas para tela de smartphone (380pt) com altura proporcional que preenche a tela
    final qtdItensCartoes = totais.detalheCartoes.length;
    const double alturaBase = 680.0;
    final double alturaExtraCartoes = qtdItensCartoes > 5 ? (qtdItensCartoes - 5) * 15.0 : 0.0;
    final textoJustificativa = turno.textoJustificativa;
    final double alturaExtraObs = textoJustificativa.trim().isNotEmpty ? 26.0 : 0.0;
    final double alturaTotalCalculada = alturaBase + alturaExtraCartoes + alturaExtraObs;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          380 * PdfPageFormat.point,
          alturaTotalCalculada * PdfPageFormat.point,
          marginAll: 14 * PdfPageFormat.point,
        ),
        build: (pw.Context context) {
          final dataHoraAuth = turno.fechadoEm ?? DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
          final chaveAuth = turno.authHash ??
              AuthService.gerarChaveAutenticacao(
                operador: turno.operador,
                turnoId: turno.id ?? 1,
                totalVendas: totais.totalGeral,
                timestamp: dataHoraAuth,
              );

          final String hashSeguro = (turno.authHash != null && turno.authHash!.trim().isNotEmpty)
              ? turno.authHash!
              : chaveAuth;

          // Domínio base oficial da aplicação Web/PWA do Posto Janjão
          const String dominioApp = 'https://juglesbass.github.io/caixa-posto-janjao';

          // Conteúdo do QR Code:
          // 1. URL Completa codificada com dados reais do turno para validação universal:
          //    https://[SEU_LINK_DO_APP]/#/validar?auth=${turno.authHash}&op=${Uri.encodeComponent(turno.operador)}&turno=${turno.numeroTurno}&total=${totais.totalPista.toStringAsFixed(2)}&data=${Uri.encodeComponent(dataFormatada)}
          // 2. Ajuste de Fallback caso não haja domínio configurado:
          //    POSTO JANJÃO\nTurno: #${turno.numeroTurno}\nOperador: ${turno.operador}\nTotal: R$ ${totais.totalPista}\nChave: ${turno.authHash}
          final String qrData = dominioApp.trim().isNotEmpty
              ? '$dominioApp/#/validar?auth=$hashSeguro&op=${Uri.encodeComponent(turno.operador)}&turno=${turno.numero}&total=${totais.totalGeral.toStringAsFixed(2)}&data=${Uri.encodeComponent(dataHoraAuth)}'
              : 'POSTO JANJÃO\nTurno: #${turno.numero}\nOperador: ${turno.operador}\nTotal: R\$ ${totais.totalGeral.toStringAsFixed(2)}\nChave: $hashSeguro';

          // Faixa de resultado (pista x sistema). Sem a venda do sistema
          // informada nao ha conferencia: antes, o total inteiro saia aqui como
          // "sobra na pista" e confundia o gerente. Ver Conciliacao.
          final diferencaValor = totais.totalGeral - turno.vendasSistema;
          final estado = Conciliacao.estado(
            totalPista: totais.totalGeral,
            vendasSistema: turno.vendasSistema,
          );

          final PdfColor faixaBg = switch (estado) {
            EstadoConciliacao.semSistema => PdfColor.fromHex('#475569'),
            EstadoConciliacao.fechada => PdfColors.green800,
            EstadoConciliacao.sobra => PdfColors.orange900,
            EstadoConciliacao.falta => PdfColors.red800,
          };

          final PdfColor faixaBorder = switch (estado) {
            EstadoConciliacao.semSistema => PdfColor.fromHex('#334155'),
            EstadoConciliacao.fechada => PdfColor.fromHex('#14532d'),
            EstadoConciliacao.sobra => PdfColor.fromHex('#7c2d12'),
            EstadoConciliacao.falta => PdfColor.fromHex('#7f1d1d'),
          };

          final String faixaLabel = switch (estado) {
            EstadoConciliacao.semSistema => 'CONFERÊNCIA PISTA X SISTEMA:',
            EstadoConciliacao.fechada => 'CAIXA EXATO (ZERADO):',
            EstadoConciliacao.sobra => 'SOBRA NA PISTA:',
            EstadoConciliacao.falta => 'FALTA NA PISTA:',
          };

          final String faixaValorTexto = switch (estado) {
            EstadoConciliacao.semSistema => 'SISTEMA NÃO INFORMADO',
            EstadoConciliacao.fechada => 'R\$ 0,00',
            _ => CurrencyFormatter.formatar(diferencaValor),
          };

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
                      // Larguras desiguais de propósito. Coladas, um valor que enchia a coluna
                      // encostava no da coluna seguinte — nome grande de operador batendo no
                      // dia da semana. Sao 336pt uteis aqui dentro: o nome leva a maior fatia,
                      // o turno a menor, e os SizedBox garantem o respiro entre elas.
                      //
                      // CAIXA DO DIA em destaque: é por esta data que a gerência confere. Os
                      // horários de abertura e de fechamento seguem gravados no banco, para
                      // auditoria, mas fora do relatório.
                      pw.Expanded(
                        flex: 6,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('CAIXA DO DIA', style: pw.TextStyle(font: fontBold, fontSize: 6.2, color: corCinzaTexto)),
                            pw.SizedBox(height: 1),
                            pw.Text(turno.dataCaixa, style: pw.TextStyle(font: fontBold, fontSize: 14, color: corTextoEscuro)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      // OPERADOR CAIXA — a maior fatia: nome grande quebra em duas linhas,
                      // como fazia antes, em vez de invadir a coluna vizinha.
                      pw.Expanded(
                        flex: 9,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('OPERADOR CAIXA', style: pw.TextStyle(font: fontBold, fontSize: 6.2, color: corCinzaTexto)),
                            pw.SizedBox(height: 2),
                            pw.Text(turno.operador, style: pw.TextStyle(font: fontBold, fontSize: 8.2, color: corTextoEscuro)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      // DIA DA SEMANA — contexto da data, sem hora nenhuma
                      pw.Expanded(
                        flex: 6,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('DIA DA SEMANA', style: pw.TextStyle(font: fontBold, fontSize: 6.2, color: corCinzaTexto)),
                            pw.SizedBox(height: 2),
                            pw.Text(_diaDaSemana(turno.dataCaixa), style: pw.TextStyle(font: fontBold, fontSize: 8.2, color: corTextoEscuro)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      // TURNO — sempre o 1º, fixo. O posto trabalha com o WebPost, que
                      // reinicia a contagem a cada dia: nunca existe um segundo turno no mesmo
                      // dia, então o número que o app incrementa não diz nada ao gerente. Esse
                      // contador continua no banco, identificando cada turno.
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('TURNO', style: pw.TextStyle(font: fontBold, fontSize: 6.2, color: corVerde)),
                            pw.SizedBox(height: 2),
                            pw.Text('1º', style: pw.TextStyle(font: fontBold, fontSize: 8.2, color: corTextoEscuro)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),

                // ── 3. SEÇÃO 1: CARTÕES E VOUCHERS ──
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1e293b'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('CARTÕES E VOUCHERS', style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.white)),
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 40,
                            alignment: pw.Alignment.center,
                            child: pw.Text('QTD', style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.white)),
                          ),
                          pw.Container(
                            width: 75,
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text('VALOR (R\$)', style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.white)),
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
                  ...PaymentTypes.ordenarCartoes(totais.detalheCartoes.entries).map((e) {
                    final nome = e.key;
                    final total = e.value.total;
                    final qtd = turno.canhotos[nome] ?? e.value.qtd;

                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2.8, horizontal: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('#f1f5f9'), width: 0.5)),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Text(nome, style: pw.TextStyle(fontSize: 7.8, color: PdfColor.fromHex('#334155'))),
                          ),
                          pw.Container(
                            width: 40,
                            alignment: pw.Alignment.center,
                            child: pw.Text('$qtd un', style: pw.TextStyle(fontSize: 7.8, color: corCinzaTexto)),
                          ),
                          pw.Container(
                            width: 75,
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(CurrencyFormatter.formatar(total), style: pw.TextStyle(font: fontBold, fontSize: 7.8)),
                          ),
                        ],
                      ),
                    );
                  }),

                // Total Cartões
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#eff6ff'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    border: pw.Border.all(color: PdfColor.fromHex('#93c5fd'), width: 0.8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('TOTAL CARTÕES', style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColor.fromHex('#1e40af'))),
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 40,
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              '${totais.detalheCartoes.entries.fold<int>(0, (acc, e) => acc + (turno.canhotos[e.key] ?? e.value.qtd))} un',
                              style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColor.fromHex('#1e40af')),
                            ),
                          ),
                          pw.Container(
                            width: 75,
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(CurrencyFormatter.formatar(totais.cartoes), style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColor.fromHex('#1e40af'))),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),

                // ── 4. SEÇÃO 2: OUTROS MEIOS DE PAGAMENTO ──
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1e293b'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('OUTROS MEIOS DE PAGAMENTO', style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.white)),
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 40,
                            alignment: pw.Alignment.center,
                            child: pw.Text('QTD', style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.white)),
                          ),
                          pw.Container(
                            width: 75,
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text('VALOR (R\$)', style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.white)),
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
                      pw.Text(
                        turno.vendasSistema > 0 ? CurrencyFormatter.formatar(turno.vendasSistema) : 'NÃO INFORMADO',
                        style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: PdfColor.fromHex('#f8fafc')),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 3),

                // ── 5. FAIXA DE RESULTADO (PISTA VS PDV) COM CORES DINÂMICAS ──

                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: faixaBg,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    border: pw.Border.all(color: faixaBorder, width: 1.0),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        faixaLabel,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 8,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        faixaValorTexto,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                if (textoJustificativa.trim().isNotEmpty) ...[
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
                        pw.Text(textoJustificativa, style: pw.TextStyle(fontSize: 7.5, color: corTextoEscuro)),
                      ],
                    ),
                  ),
                ],

                pw.Spacer(),

                // ── 6. AUTENTICAÇÃO DIGITAL & CONFERÊNCIA DA GERÊNCIA (SIMETRIA TOTAL) ──
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Quadro de Autenticação Digital do Operador (com Mini QR Code)
                    pw.Expanded(
                      flex: 12,
                      child: pw.Container(
                        height: 60,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#f8fafc'),
                          border: pw.Border.all(color: PdfColor.fromHex('#0284c7'), width: 0.8),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Row(
                              children: [
                                pw.Container(
                                  width: 4.5,
                                  height: 4.5,
                                  decoration: pw.BoxDecoration(
                                    color: PdfColor.fromHex('#0284c7'),
                                    shape: pw.BoxShape.circle,
                                  ),
                                ),
                                pw.SizedBox(width: 3.5),
                                pw.Text(
                                  'DOCUMENTO AUTENTICADO DIGITALMENTE',
                                  style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: 6.5,
                                    color: PdfColor.fromHex('#0369a1'),
                                  ),
                                ),
                              ],
                            ),
                            pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Expanded(
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(
                                        'Operador: ${turno.operador}',
                                        style: pw.TextStyle(font: fontBold, fontSize: 6.5, color: corTextoEscuro),
                                        maxLines: 1,
                                      ),
                                      pw.Text(
                                        'Data/Hora: $dataHoraAuth',
                                        style: pw.TextStyle(font: fontRegular, fontSize: 5.8, color: corCinzaTexto),
                                      ),
                                      pw.Text(
                                        'Chave: $chaveAuth',
                                        style: pw.TextStyle(font: fontBold, fontSize: 6.2, color: PdfColor.fromHex('#0f172a')),
                                      ),
                                      pw.Text(
                                        'Status: Homologado via PIN Individual',
                                        style: pw.TextStyle(font: fontBold, fontSize: 5.8, color: PdfColor.fromHex('#15803d')),
                                      ),
                                    ],
                                  ),
                                ),
                                pw.SizedBox(width: 4),
                                pw.Container(
                                  width: 36,
                                  height: 36,
                                  child: pw.BarcodeWidget(
                                    barcode: pw.Barcode.qrCode(),
                                    data: qrData,
                                    drawText: false,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 10),

                    // Quadro Simétrico de Conferência da Gerência
                    pw.Expanded(
                      flex: 8,
                      child: pw.Container(
                        height: 60,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#f8fafc'),
                          border: pw.Border.all(color: PdfColor.fromHex('#cbd5e1'), width: 0.8),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Row(
                              children: [
                                pw.Container(
                                  width: 4.5,
                                  height: 4.5,
                                  decoration: pw.BoxDecoration(
                                    color: PdfColor.fromHex('#64748b'),
                                    shape: pw.BoxShape.circle,
                                  ),
                                ),
                                pw.SizedBox(width: 3.5),
                                pw.Text(
                                  'CONFERÊNCIA DA GERÊNCIA',
                                  style: pw.TextStyle(
                                    font: fontBold,
                                    fontSize: 6.5,
                                    color: PdfColor.fromHex('#334155'),
                                  ),
                                ),
                              ],
                            ),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                // Campo de data para a gerência preencher junto da rubrica.
                                // Aqui dizia “Status: Conferência Pendente”, em âmbar: o PDF nasce
                                // no fechamento do caixa, sempre antes de o gerente olhar, então
                                // todo relatório saía acusando uma pendência que era só a ordem
                                // natural das coisas — e que numa auditoria pesaria contra ele.
                                // O app ainda não registra a conferência; enquanto não registrar,
                                // o documento não afirma nada sobre ela.
                                pw.Text(
                                  'Data: ___ / ___ / ______',
                                  style: pw.TextStyle(font: fontRegular, fontSize: 6, color: corCinzaTexto),
                                ),
                                pw.Text(
                                  'Visto Interno',
                                  style: pw.TextStyle(font: fontRegular, fontSize: 5.6, color: corCinzaTexto),
                                ),
                              ],
                            ),
                            pw.Column(
                              children: [
                                pw.Container(height: 0.6, color: PdfColor.fromHex('#94a3b8')),
                                pw.SizedBox(height: 2),
                                pw.Center(
                                  child: pw.Text(
                                    'Rubrica / Assinatura da Gerência',
                                    style: pw.TextStyle(font: fontRegular, fontSize: 5.6, color: corCinzaTexto),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),

                // ── 7. RODAPÉ ──
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Posto Janjão · Sistema de Gestão de Caixa', style: pw.TextStyle(fontSize: 6.5, color: corCinzaTexto)),
                    pw.Text('Documento Autenticado · 1/1', style: pw.TextStyle(fontSize: 6.5, color: corCinzaTexto)),
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
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColor.fromHex('#e2e8f0'), width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(width: 3.5, height: 12, color: corBarra, margin: const pw.EdgeInsets.only(right: 7)),
              pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: PdfColor.fromHex('#1e293b'))),
            ],
          ),
          pw.Row(
            children: [
              pw.Container(
                width: 40,
                alignment: pw.Alignment.center,
                child: pw.Text(qtd ?? '-', style: pw.TextStyle(fontSize: 7.8, color: PdfColor.fromHex('#64748b'))),
              ),
              pw.Container(
                width: 75,
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  CurrencyFormatter.formatar(valor),
                  style: pw.TextStyle(font: fontBold, fontSize: 7.8, color: valor > 0 ? corBarra : PdfColor.fromHex('#94a3b8')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
