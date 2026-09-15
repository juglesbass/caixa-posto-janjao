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

    test('Formato curto dos botões', () {
      expect(DataCaixa.curta('14/09/2026'), '14/09');
    });
  });
}
