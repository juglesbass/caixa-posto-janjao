import 'package:caixa_posto_janjao/dialogs/analytics_dialog.dart';
import 'package:caixa_posto_janjao/models/lancamento.dart';
import 'package:caixa_posto_janjao/models/operador_model.dart';
import 'package:caixa_posto_janjao/models/totais_turno.dart';
import 'package:caixa_posto_janjao/models/turno.dart';
import 'package:caixa_posto_janjao/services/csv_service.dart';
import 'package:caixa_posto_janjao/theme/app_theme.dart';
import 'package:caixa_posto_janjao/utils/data_caixa.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataCaixa.dataParaNomeArquivo e CsvService', () {
    test('DataCaixa.curta limpa espaços e dataParaNomeArquivo formata e valida', () {
      expect(DataCaixa.curta('  12/11/2026 07:30:00  '), equals('12/11'));
      expect(DataCaixa.dataParaNomeArquivo('12/11/2026'), equals('12-11-2026'));
      expect(
        DataCaixa.dataParaNomeArquivo('invalida', agora: DateTime(2026, 11, 14)),
        equals('14-11-2026'),
      );
    });

    test('CsvService.formatarCelulaTexto neutraliza fórmula sem corromper traço', () {
      expect(CsvService.formatarCelulaTexto('-'), equals('"-"'));
      expect(CsvService.formatarCelulaTexto('=CMD()'), equals('"\'=CMD()"'));
      expect(CsvService.formatarCelulaTexto('+SUM(A1)'), equals('"\'+SUM(A1)"'));
      expect(CsvService.formatarCelulaTexto('-123.45'), equals('"-123.45"'));
      expect(CsvService.formatarCelulaTexto('-A1'), equals('"\'-A1"'));
      expect(CsvService.formatarCelulaTexto('Texto "aspas"\nlinha2'), equals('"Texto ""aspas"" linha2"'));
    });

    test('CsvService.gerarNomeArquivo inclui versão > 1 e montarCsv traz qtdPix', () {
      final turno = Turno(
        id: 7,
        numero: 2,
        data: '12/11/2026 14:00:00',
        dataCaixa: '12/11/2026',
        operador: 'Agildo',
        aberto: false,
        vendasSistema: 500,
        versao: 3,
      );
      final totais = TotaisTurno(
        dinheiro: 100,
        qtdDinheiro: 2,
        pix: 250,
        qtdPix: 4,
        cartoes: 150,
        qtdCartoes: 3,
        totalGeral: 500,
        diferenca: 0,
        detalheCartoes: {
          'Rede Visa Débito': (total: 150.0, qtd: 3),
        },
      );
      final lancamentos = [
        Lancamento(
          id: 1,
          turnoId: 7,
          hora: '14:10',
          dataHora: '12/11/2026 14:10:00',
          tipo: 'Pag Pix',
          valor: 250,
          descricao: '=EVIL()',
        ),
      ];

      expect(CsvService.gerarNomeArquivo(turno), equals('Agildo 12-11-2026_v3.csv'));

      final csv = CsvService.montarCsv(
        turno: turno,
        totais: totais,
        lancamentos: lancamentos,
        agora: DateTime(2026, 11, 12, 22, 0),
      );

      expect(csv, contains('Pagamento Pix;4;250.00'));
      expect(csv, contains('Dinheiro em Espécie;2;100.00'));
      expect(csv, contains('Total Cartões;3;150.00'));
      expect(csv, contains('"\'=EVIL()"'));
    });
  });

  group('Modelos resilientes (OperadorModel e Turno)', () {
    test('OperadorModel herda atualizadoEm quando criadoEm vazio e lida com JSON parcial', () {
      final op = OperadorModel.fromMap({
        'id': 'joão_victor',
        'nome': 'João Victor',
        'pin_hash': 'h',
        'atualizado_em': '2026-11-14T10:00:00Z',
      });
      expect(op.criadoEm, equals(DateTime.parse('2026-11-14T10:00:00Z')));

      final rest = OperadorModel.fromFirestoreRest(<String, dynamic>{}, docIdFallback: 'maria');
      expect(rest.id, equals('maria'));
      expect(rest.ativo, isTrue);
    });

    test('Turno.fromMap ignora entradas inválidas em canhotos e cai de justificativa vazia para observacao', () {
      final t = Turno.fromMap({
        'id': '9',
        'numero': 1,
        'data': '14/11/2026 07:00',
        'operador': 'Carlos',
        'aberto': 1,
        'justificativa': '   ',
        'observacao': 'Falta troco',
        'canhotos': '{"Rede Pix": "2", "Invalido": "abc"}',
      });
      expect(t.id, equals(9));
      expect(t.canhotos, equals({'Rede Pix': 2}));
      expect(t.textoJustificativa, equals('Falta troco'));
    });
  });

  group('AnalyticsDialog com Despesas', () {
    testWidgets('inclui Despesas no total de lançamentos e renderiza sem overflow em tela estreita', (tester) async {
      tester.view.physicalSize = const Size(375 * 3, 812 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final turno = Turno(
        id: 1,
        numero: 1,
        data: '14/11/2026 07:00',
        operador: 'Agildo',
        aberto: true,
      );
      final totais = TotaisTurno(
        dinheiro: 100,
        qtdDinheiro: 1,
        pix: 200,
        qtdPix: 2,
        cartoes: 300,
        qtdCartoes: 3,
        requisicao: 50,
        qtdRequisicao: 1,
        depositoGlobal: 50,
        qtdDepositoGlobal: 1,
        despesas: 40,
        qtdDespesas: 2,
        totalGeral: 740,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: AnalyticsDialog(turno: turno, totais: totais),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('10 un'), findsOneWidget);
      expect(find.text('Despesas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
