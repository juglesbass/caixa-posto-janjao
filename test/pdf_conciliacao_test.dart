import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:caixa_posto_janjao/models/lancamento.dart';
import 'package:caixa_posto_janjao/models/totais_turno.dart';
import 'package:caixa_posto_janjao/models/turno.dart';
import 'package:caixa_posto_janjao/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Texto de um PDF, palavra por palavra, na ordem em que foi escrito.
///
/// O gerador de PDF grava cada palavra num pedaco separado — "(SOBRA) (NA)
/// (PISTA)" — entao a frase inteira nunca aparece no arquivo: e preciso
/// descompactar cada stream, pegar os pedacos e juntar com espaco.
String _textoDoPdf(Uint8List bytes) {
  final bruto = latin1.decode(bytes);
  final palavras = <String>[];
  for (final m in RegExp(r'stream\r?\n').allMatches(bruto)) {
    var fim = bruto.indexOf('endstream', m.end);
    if (fim < 0) continue;
    // Tira a quebra de linha que antecede o "endstream".
    while (fim > m.end && (bruto[fim - 1] == '\n' || bruto[fim - 1] == '\r')) {
      fim--;
    }
    List<int> dados;
    try {
      dados = ZLibCodec().decode(bytes.sublist(m.end, fim));
    } catch (_) {
      continue; // stream binario (fonte, imagem)
    }
    final conteudo = latin1.decode(dados);
    for (final t in RegExp(r'\(((?:\\.|[^\\)])*)\)').allMatches(conteudo)) {
      palavras.add(t.group(1)!);
    }
  }
  return palavras.join(' ');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Turno turno({required double sistema}) => Turno(
        id: 1,
        numero: 1,
        data: '22/09/2026 06:00',
        operador: 'Agildo Gomes',
        aberto: false,
        fechadoEm: '22/09/2026 14:00:00',
        vendasSistema: sistema,
        observacao: '',
        fundoCaixa: 0,
        authHash: 'AUTH-TESTE-0001',
        versao: 1,
      );

  final lancamentos = [
    Lancamento(id: 1, turnoId: 1, tipo: 'Dinheiro', valor: 2884.97, hora: '08:00:00', dataHora: '22/09/2026 08:00:00'),
  ];

  Future<String> pdf({required double sistema}) async {
    final t = turno(sistema: sistema);
    final bytes = await PdfService.gerarPdfFechamento(
      turno: t,
      totais: TotaisTurno(
        dinheiro: 2884.97,
        totalGeral: 2884.97,
        vendasSistema: sistema,
        diferenca: 2884.97 - sistema,
      ),
      lancamentos: lancamentos,
    );
    return _textoDoPdf(bytes);
  }

  group('PDF do fechamento: conferência pista x sistema', () {
    // O caso que confundia o gerente: sistema esquecido virava "sobra" do
    // total inteiro.
    test('sem venda do sistema, não sai sobra nem falta', () async {
      final texto = await pdf(sistema: 0);
      expect(texto, isNot(contains('SOBRA NA PISTA')));
      expect(texto, isNot(contains('FALTA NA PISTA')));
      expect(texto, contains('SISTEMA NÃO INFORMADO'));
    });

    test('com venda do sistema menor, sai a sobra', () async {
      final texto = await pdf(sistema: 2800);
      expect(texto, contains('SOBRA NA PISTA'));
    });

    test('com venda do sistema igual, sai caixa exato', () async {
      final texto = await pdf(sistema: 2884.97);
      expect(texto, contains('CAIXA EXATO'));
      expect(texto, isNot(contains('SOBRA NA PISTA')));
    });
  });
}
