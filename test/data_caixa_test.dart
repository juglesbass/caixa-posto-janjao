import 'package:flutter_test/flutter_test.dart';
import 'package:caixa_posto_janjao/utils/data_caixa.dart';

void main() {
  group('DataCaixa - de qual dia é o caixa', () {
    test('Pergunta só de madrugada, das 00h às 05h59', () {
      expect(DataCaixa.aberturaDeMadrugada(DateTime(2026, 9, 15, 0, 0)), isTrue);
      expect(DataCaixa.aberturaDeMadrugada(DateTime(2026, 9, 15, 0, 40)), isTrue);
      expect(DataCaixa.aberturaDeMadrugada(DateTime(2026, 9, 15, 5, 59)), isTrue);

      // Turno do dia e caixa aberto na hora certa: não perguntar nada
      expect(DataCaixa.aberturaDeMadrugada(DateTime(2026, 9, 15, 6, 0)), isFalse);
      expect(DataCaixa.aberturaDeMadrugada(DateTime(2026, 9, 14, 18, 0)), isFalse);
      expect(DataCaixa.aberturaDeMadrugada(DateTime(2026, 9, 14, 23, 59)), isFalse);
    });

    test('Opções são o dia anterior e o próprio dia da abertura', () {
      final opcoes = DataCaixa.opcoes('15/09/2026 00:40')!;
      expect(opcoes.anterior, '14/09/2026');
      expect(opcoes.doDia, '15/09/2026');
    });

    test('Vira mês e ano pelo calendário', () {
      expect(DataCaixa.opcoes('01/03/2026')!.anterior, '28/02/2026');
      expect(DataCaixa.opcoes('01/03/2028')!.anterior, '29/02/2028');
      expect(DataCaixa.opcoes('01/01/2027 02:10')!.anterior, '31/12/2026');
      expect(
        DataCaixa.formatar(DataCaixa.diaAnterior(DateTime(2026, 10, 1, 1, 30))),
        '30/09/2026',
      );
    });

    test('Data ilegível não inventa opções', () {
      expect(DataCaixa.opcoes(''), isNull);
      expect(DataCaixa.opcoes('ontem'), isNull);
    });

    test('Caixa aberto num dia e usado dias depois é detectado depois das 6h', () {
      // Fechou o caixa dia 15, abriu o app de novo no mesmo dia e só voltou dia 17
      expect(DataCaixa.caixaDeDiaAnterior('15/09/2026', DateTime(2026, 9, 17, 6, 30)), isTrue);
      expect(DataCaixa.caixaDeDiaAnterior('15/09/2026', DateTime(2026, 9, 16, 14, 0)), isTrue);
      // Caixa do dia esquecido aberto até a manhã seguinte também é perguntado
      expect(DataCaixa.caixaDeDiaAnterior('14/09/2026', DateTime(2026, 9, 15, 7, 0)), isTrue);
    });

    test('Não pergunta de madrugada nem para caixa de hoje', () {
      // Caixa da meia-noite com data de ontem, ainda de madrugada: é o certo
      expect(DataCaixa.caixaDeDiaAnterior('14/09/2026', DateTime(2026, 9, 15, 1, 0)), isFalse);
      expect(DataCaixa.caixaDeDiaAnterior('14/09/2026', DateTime(2026, 9, 15, 5, 59)), isFalse);
      // Caixa de hoje
      expect(DataCaixa.caixaDeDiaAnterior('17/09/2026', DateTime(2026, 9, 17, 10, 0)), isFalse);
      // Data ilegível não dispara pergunta
      expect(DataCaixa.caixaDeDiaAnterior('', DateTime(2026, 9, 17, 10, 0)), isFalse);
    });

    test('Trocar oferece hoje quando o caixa foi aberto dias antes', () {
      final opcoes = DataCaixa.opcoesParaTroca('15/09/2026 14:10', DateTime(2026, 9, 17, 6, 30));
      expect(opcoes.map((o) => o.data).toList(), ['14/09/2026', '15/09/2026', '17/09/2026']);
      expect(opcoes.last.rotulo, 'Hoje');
    });

    test('Trocar não repete a data de hoje', () {
      final opcoes = DataCaixa.opcoesParaTroca('15/09/2026 00:40', DateTime(2026, 9, 15, 0, 50));
      expect(opcoes.map((o) => o.data).toList(), ['14/09/2026', '15/09/2026']);
    });

    group('Troca automática do caixa aberto de dia anterior', () {
      AcaoCaixaAntigo decidir({
        String abertura = '15/09/2026 14:10',
        String caixa = '15/09/2026',
        List<String> lancamentos = const [],
        bool encerrantes = false,
        required DateTime agora,
      }) =>
          DataCaixa.decidirCaixaAberto(
            dataAbertura: abertura,
            dataCaixa: caixa,
            datasHoraLancamentos: lancamentos,
            temEncerrantes: encerrantes,
            agora: agora,
          );

      test('Aberto sem querer no dia 15 e sem uso: recomeça no dia 17', () {
        expect(decidir(agora: DateTime(2026, 9, 17, 6, 30)), AcaoCaixaAntigo.recomecar);
      });

      test('Já com lançamentos só de hoje: a data vira hoje', () {
        expect(
          decidir(lancamentos: ['2026-09-17 06:35:10'], agora: DateTime(2026, 9, 17, 7, 0)),
          AcaoCaixaAntigo.mudarParaHoje,
        );
      });

      test('Caixa do dia 15 esquecido aberto com vendas: NÃO troca, só avisa', () {
        // Trocar mandaria as vendas do dia 15 para o PDF do dia 16
        expect(
          decidir(
            abertura: '15/09/2026 06:02',
            lancamentos: ['2026-09-15 08:00:00', '2026-09-15 17:40:00'],
            agora: DateTime(2026, 9, 16, 6, 10),
          ),
          AcaoCaixaAntigo.avisarCaixaAntigo,
        );
      });

      test('Vendas de dias diferentes no mesmo caixa: avisa', () {
        expect(
          decidir(
            lancamentos: ['2026-09-15 20:00:00', '2026-09-17 07:00:00'],
            agora: DateTime(2026, 9, 17, 7, 30),
          ),
          AcaoCaixaAntigo.avisarCaixaAntigo,
        );
      });

      test('Só encerrante salvo, que não tem data: avisa', () {
        expect(
          decidir(encerrantes: true, agora: DateTime(2026, 9, 17, 6, 30)),
          AcaoCaixaAntigo.avisarCaixaAntigo,
        );
      });

      test('Lançamento com data ilegível: na dúvida não troca', () {
        expect(
          decidir(lancamentos: ['???'], agora: DateTime(2026, 9, 17, 6, 30)),
          AcaoCaixaAntigo.avisarCaixaAntigo,
        );
      });

      test('Turno da noite: "Ontem" escolhido na madrugada nunca é trocado', () {
        // Aberto 00:40 do dia 15 como caixa do dia 14, lançado depois da meia-noite
        final antesDas6 = decidir(
          abertura: '15/09/2026 00:40',
          caixa: '14/09/2026',
          lancamentos: ['2026-09-15 00:45:00'],
          agora: DateTime(2026, 9, 15, 5, 30),
        );
        expect(antesDas6, AcaoCaixaAntigo.nenhuma);

        // Ainda aberto às 7h: é o caixa da meia-noite esquecido (o da madrugada
        // nem foi aberto). A data escolhida continua intocada — só avisa.
        final as7 = decidir(
          abertura: '15/09/2026 00:40',
          caixa: '14/09/2026',
          lancamentos: ['2026-09-15 00:45:00'],
          agora: DateTime(2026, 9, 15, 7, 0),
        );
        expect(as7, isNot(AcaoCaixaAntigo.mudarParaHoje));
        expect(as7, isNot(AcaoCaixaAntigo.recomecar));
        expect(as7, AcaoCaixaAntigo.avisarCaixaAntigo);
      });

      test('Caixa da noite aberto antes da meia-noite e lançado só de madrugada: não vira do dia', () {
        // Abriu 23:50 do dia 14 (sem pergunta), lançou tudo depois da meia-noite
        // e não fechou até as 6h30. Os lançamentos têm data do dia 15, mas o
        // caixa é o da meia-noite, do dia 14.
        expect(
          decidir(
            abertura: '14/09/2026 23:50',
            caixa: '14/09/2026',
            lancamentos: ['2026-09-15 00:10:00', '2026-09-15 03:00:00'],
            agora: DateTime(2026, 9, 15, 6, 30),
          ),
          AcaoCaixaAntigo.avisarCaixaAntigo,
        );
      });

      test('Lançamento de hoje às 06:00 em ponto já conta como do dia', () {
        expect(
          decidir(lancamentos: ['2026-09-17 06:00:00'], agora: DateTime(2026, 9, 17, 6, 30)),
          AcaoCaixaAntigo.mudarParaHoje,
        );
        expect(
          decidir(lancamentos: ['2026-09-17 05:59:59'], agora: DateTime(2026, 9, 17, 6, 30)),
          AcaoCaixaAntigo.avisarCaixaAntigo,
        );
      });

      test('Caixa da meia-noite esquecido até o outro dia: avisa, sem trocar', () {
        expect(
          decidir(
            abertura: '15/09/2026 00:40',
            caixa: '14/09/2026',
            lancamentos: ['2026-09-15 00:45:00'],
            agora: DateTime(2026, 9, 16, 7, 0),
          ),
          AcaoCaixaAntigo.avisarCaixaAntigo,
        );
      });

      test('De madrugada nunca troca nada', () {
        expect(decidir(agora: DateTime(2026, 9, 17, 5, 59)), AcaoCaixaAntigo.nenhuma);
      });

      test('Caixa de hoje não é mexido', () {
        expect(
          decidir(abertura: '17/09/2026 06:05', caixa: '17/09/2026', agora: DateTime(2026, 9, 17, 15, 0)),
          AcaoCaixaAntigo.nenhuma,
        );
      });
    });

    test('Formato curto dos botões', () {
      expect(DataCaixa.curta('14/09/2026'), '14/09');
    });
  });
}
