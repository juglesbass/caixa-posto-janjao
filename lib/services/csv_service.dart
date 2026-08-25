import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/lancamento.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../utils/currency_formatter.dart';

class CsvService {
  /// Gera e compartilha o arquivo CSV do Fechamento de Turno
  static Future<void> exportarECompartilharCsv({
    required Turno turno,
    required TotaisTurno totais,
    required List<Lancamento> lancamentos,
  }) async {
    final buffer = StringBuffer();

    // UTF-8 BOM para garantir acentuação correta no Excel / Planilhas
    buffer.write('\uFEFF');

    // Metadados do Turno
    buffer.writeln('POSTO JANJÃO - RELATÓRIO DE FECHAMENTO DE TURNO');
    buffer.writeln('Turno;${turno.numero}');
    buffer.writeln('Operador;${turno.operador}');
    buffer.writeln('Aberto Em;${turno.data}');
    buffer.writeln('Fechado Em;${turno.fechadoEm ?? "Aberto"}');
    buffer.writeln('Data de Exportação;${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('');

    // Resumo Financeiro
    buffer.writeln('RESUMO FINANCEIRO');
    buffer.writeln('Item;Quantidade;Valor (R\$)');
    buffer.writeln('Dinheiro em Espécie;-;${totais.dinheiro.toStringAsFixed(2)}');
    buffer.writeln('Pagamento Pix;-;${totais.pix.toStringAsFixed(2)}');
    buffer.writeln('Total Cartões;${totais.qtdCartoes};${totais.cartoes.toStringAsFixed(2)}');
    buffer.writeln('Requisição (A Prazo);-;${totais.requisicao.toStringAsFixed(2)}');
    buffer.writeln('Depósito Global;-;${totais.depositoGlobal.toStringAsFixed(2)}');
    buffer.writeln('Despesas;-;${totais.despesas.toStringAsFixed(2)}');
    buffer.writeln('TOTAL GERAL (PISTA);-;${totais.totalGeral.toStringAsFixed(2)}');
    buffer.writeln('Vendas Sistema (PDV);-;${turno.vendasSistema.toStringAsFixed(2)}');
    buffer.writeln('Diferença;-;${totais.diferenca.toStringAsFixed(2)}');
    buffer.writeln('');

    // Detalhamento de Cartões
    buffer.writeln('DETALHAMENTO DE CARTÕES');
    buffer.writeln('Bandeira / Tipo;Quantidade;Total (R\$)');
    if (totais.detalheCartoes.isEmpty) {
      buffer.writeln('Nenhum cartão lançado;0;0.00');
    } else {
      for (final e in totais.detalheCartoes.entries) {
        buffer.writeln('${e.key};${e.value.qtd};${e.value.total.toStringAsFixed(2)}');
      }
    }
    buffer.writeln('');

    // Lista de Lançamentos Individuais
    buffer.writeln('TODOS OS LANÇAMENTOS DO TURNO');
    buffer.writeln('ID;Hora;Tipo de Pagamento;Descrição / Observação;Valor (R\$)');
    for (final l in lancamentos) {
      final desc = (l.descricao?.trim().isNotEmpty ?? false) ? l.descricao! : '-';
      buffer.writeln('${l.id};${l.hora};${l.tipo};$desc;${l.valor.toStringAsFixed(2)}');
    }

    final csvContent = buffer.toString();
    final operadorLimpo = turno.operador.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    final dataHojeStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final nomeArquivo = '$operadorLimpo $dataHojeStr.csv';

    if (kIsWeb) {
      // No Web compartilha como texto
      await Share.share(csvContent, subject: 'Fechamento CSV - $operadorLimpo');
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$nomeArquivo');
      await file.writeAsString(csvContent, encoding: utf8);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Fechamento CSV - $operadorLimpo',
      );
    }
  }
}
