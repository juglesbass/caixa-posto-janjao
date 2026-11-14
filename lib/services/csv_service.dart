import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/lancamento.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../utils/arquivo_local.dart';
import '../utils/data_caixa.dart';
import '../utils/payment_types.dart';

class CsvService {
  /// Escapa célula textual para CSV (separador `;`) e neutraliza injeção de
  /// fórmulas em planilhas (`=`, `+`, `-`, `@`, TAB) preservando números e `-`.
  static String formatarCelulaTexto(String valor) {
    var limpo = valor.replaceAll(RegExp(r'[\r\n]+'), ' ');
    if (limpo.isNotEmpty && limpo != '-') {
      final primeiro = limpo[0];
      if ((primeiro == '=' ||
              primeiro == '+' ||
              primeiro == '-' ||
              primeiro == '@' ||
              primeiro == '\t') &&
          double.tryParse(limpo.trim()) == null) {
        limpo = "'$limpo";
      }
    }
    return '"${limpo.replaceAll('"', '""')}"';
  }

  /// Gera o nome do arquivo CSV do Fechamento de Turno.
  static String gerarNomeArquivo(Turno turno) {
    final operadorLimpo = turno.operador.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    final dataCaixaStr = DataCaixa.dataParaNomeArquivo(turno.dataCaixa);
    final sufixoVersao = (turno.versao > 1) ? '_v${turno.versao}' : '';
    final baseNome = operadorLimpo.isNotEmpty ? '$operadorLimpo $dataCaixaStr' : dataCaixaStr;
    return '$baseNome$sufixoVersao.csv';
  }

  /// Monta o conteúdo CSV do Fechamento de Turno.
  static String montarCsv({
    required Turno turno,
    required TotaisTurno totais,
    required List<Lancamento> lancamentos,
    DateTime? agora,
  }) {
    final buffer = StringBuffer();

    // UTF-8 BOM para garantir acentuação correta no Excel / Planilhas
    buffer.write('\uFEFF');

    // Metadados do Turno
    buffer.writeln('POSTO JANJÃO - RELATÓRIO DE FECHAMENTO DE TURNO');
    buffer.writeln('Turno;${turno.numero}');
    buffer.writeln('Operador;${formatarCelulaTexto(turno.operador)}');
    buffer.writeln('Caixa do Dia;${formatarCelulaTexto(turno.dataCaixa)}');
    buffer.writeln('Aberto Em;${formatarCelulaTexto(turno.data)}');
    buffer.writeln('Fechado Em;${formatarCelulaTexto(turno.fechadoEm ?? 'Aberto')}');
    buffer.writeln('Data de Exportação;${DateFormat('dd/MM/yyyy HH:mm:ss').format(agora ?? DateTime.now())}');
    buffer.writeln('');

    // Resumo Financeiro
    buffer.writeln('RESUMO FINANCEIRO');
    buffer.writeln('Item;Quantidade;Valor (R\$)');
    buffer.writeln('Dinheiro em Espécie;${totais.qtdDinheiro};${totais.dinheiro.toStringAsFixed(2)}');
    buffer.writeln('Pagamento Pix;${totais.qtdPix};${totais.pix.toStringAsFixed(2)}');
    buffer.writeln('Total Cartões;${totais.qtdCartoes};${totais.cartoes.toStringAsFixed(2)}');
    buffer.writeln('Requisição (A Prazo);${totais.qtdRequisicao};${totais.requisicao.toStringAsFixed(2)}');
    buffer.writeln('Depósito Global;${totais.qtdDepositoGlobal};${totais.depositoGlobal.toStringAsFixed(2)}');
    buffer.writeln('Despesas;${totais.qtdDespesas};${totais.despesas.toStringAsFixed(2)}');
    buffer.writeln('TOTAL GERAL (PISTA);-;${totais.totalGeral.toStringAsFixed(2)}');
    // Sem a venda do sistema nao ha conferencia: nada de "diferenca" igual ao
    // total inteiro (ver Conciliacao).
    if (turno.vendasSistema > 0) {
      buffer.writeln('Vendas Sistema (PDV);-;${turno.vendasSistema.toStringAsFixed(2)}');
      buffer.writeln('Diferença;-;${totais.diferenca.toStringAsFixed(2)}');
    } else {
      buffer.writeln('Vendas Sistema (PDV);-;não informado');
      buffer.writeln('Diferença;-;não conferida');
    }
    buffer.writeln('');

    // Detalhamento de Cartões
    buffer.writeln('DETALHAMENTO DE CARTÕES');
    buffer.writeln('Bandeira / Tipo;Quantidade;Total (R\$)');
    if (totais.detalheCartoes.isEmpty) {
      buffer.writeln('Nenhum cartão lançado;0;0.00');
    } else {
      for (final e in PaymentTypes.ordenarCartoes(totais.detalheCartoes.entries)) {
        buffer.writeln('${formatarCelulaTexto(e.key)};${e.value.qtd};${e.value.total.toStringAsFixed(2)}');
      }
    }
    buffer.writeln('');

    // Lista de Lançamentos Individuais
    buffer.writeln('TODOS OS LANÇAMENTOS DO TURNO');
    buffer.writeln('ID;Hora;Tipo de Pagamento;Descrição / Observação;Valor (R\$)');
    for (final l in lancamentos) {
      final desc = l.descricao.trim().isNotEmpty ? l.descricao : '-';
      buffer.writeln(
        '${l.id};${l.hora};${formatarCelulaTexto(l.tipo)};${formatarCelulaTexto(desc)};${l.valor.toStringAsFixed(2)}',
      );
    }

    return buffer.toString();
  }

  /// Gera e compartilha o arquivo CSV do Fechamento de Turno
  static Future<void> exportarECompartilharCsv({
    required Turno turno,
    required TotaisTurno totais,
    required List<Lancamento> lancamentos,
  }) async {
    final csvContent = montarCsv(
      turno: turno,
      totais: totais,
      lancamentos: lancamentos,
    );
    final operadorLimpo = turno.operador.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    final nomeArquivo = gerarNomeArquivo(turno);

    const origem = ui.Rect.fromLTWH(0, 0, 100, 100);

    if (kIsWeb) {
      // No Web o arquivo vai em memória (não há sistema de arquivos gravável)
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(csvContent),
              name: nomeArquivo,
              mimeType: 'text/csv',
            ),
          ],
          fileNameOverrides: [nomeArquivo],
          subject: 'Fechamento CSV - $operadorLimpo',
          sharePositionOrigin: origem,
        ),
      );
    } else {
      final caminho = await salvarTextoTemporario(
        conteudo: csvContent,
        nomeArquivo: nomeArquivo,
      );
      if (caminho == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(caminho, mimeType: 'text/csv')],
          subject: 'Fechamento CSV - $operadorLimpo',
          sharePositionOrigin: origem,
        ),
      );
    }
  }
}
