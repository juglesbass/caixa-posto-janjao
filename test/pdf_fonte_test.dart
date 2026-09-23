import 'dart:convert';

import 'package:caixa_posto_janjao/models/lancamento.dart';
import 'package:caixa_posto_janjao/models/totais_turno.dart';
import 'package:caixa_posto_janjao/models/turno.dart';
import 'package:caixa_posto_janjao/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

// O PDF de fechamento sai com a fonte embutida no app. Antes ela vinha do
// Google Fonts na hora: sem sinal (como aqui, onde toda chamada de rede
// falha), o PDF saía em Helvetica.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a fonte do PDF vem do próprio app, sem internet', () async {
    final fontes = await PdfService.fontesParaTeste();
    expect(fontes.regular, isA<pw.TtfFont>());
    expect(fontes.bold, isA<pw.TtfFont>());

    final bytes = await PdfService.gerarPdfFechamento(
      turno: Turno(
        id: 1,
        numero: 1,
        data: '22/09/2026 06:00',
        operador: 'Agildo Gomes',
        aberto: false,
        fechadoEm: '22/09/2026 14:00:00',
        vendasSistema: 0,
        observacao: '',
        fundoCaixa: 0,
        authHash: 'AUTH-1A2B-3C4D-5E6F',
        versao: 1,
      ),
      totais: TotaisTurno(dinheiro: 60, totalGeral: 60),
      lancamentos: [
        Lancamento(id: 1, turnoId: 1, tipo: 'Dinheiro', valor: 60, hora: '08:00:00', dataHora: '22/09/2026 08:00:00'),
      ],
    );
    final bruto = latin1.decode(bytes);
    // Fonte TrueType gravada dentro do arquivo, e nenhuma Helvetica.
    expect(bruto, contains('/FontFile2'));
    expect(bruto, isNot(contains('/Helvetica')));
  });
}
