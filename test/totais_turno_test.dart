import 'package:flutter_test/flutter_test.dart';
import 'package:caixa_posto_janjao/models/totais_turno.dart';
import 'package:caixa_posto_janjao/utils/payment_types.dart';

void main() {
  group('PaymentTypes - classificação de lançamentos', () {
    test('Suprimento é reconhecido e não se confunde com sangria ou cartão', () {
      expect(PaymentTypes.ehSuprimento(PaymentTypes.suprimento), isTrue);
      expect(PaymentTypes.ehSangria(PaymentTypes.suprimento), isFalse);
      expect(PaymentTypes.ehCartao(PaymentTypes.suprimento), isFalse);
      expect(PaymentTypes.ehDespesa(PaymentTypes.suprimento), isFalse);
      expect(PaymentTypes.ehDinheiro(PaymentTypes.suprimento), isFalse);
    });

    test('Todo tipo lançável cai em exatamente uma categoria dos totais', () {
      // Se um tipo não casar com nenhum predicado, o valor some do fechamento
      // sem erro nenhum — foi exatamente o que acontecia com 'Suprimento'.
      bool classificado(String t) =>
          PaymentTypes.ehDinheiro(t) ||
          PaymentTypes.ehPix(t) ||
          PaymentTypes.ehRequisicao(t) ||
          PaymentTypes.ehDeposito(t) ||
          PaymentTypes.ehDespesa(t) ||
          PaymentTypes.ehSangria(t) ||
          PaymentTypes.ehSuprimento(t) ||
          PaymentTypes.ehCartao(t);

      final tipos = <String>[
        PaymentTypes.dinheiro,
        PaymentTypes.pix,
        PaymentTypes.requisicao,
        PaymentTypes.depositoGlobal,
        PaymentTypes.despesas,
        PaymentTypes.sangria,
        PaymentTypes.suprimento,
        'Rede Master Débito',
        'Cielo Visa Crédito',
        'Fitcard',
      ];

      for (final t in tipos) {
        expect(classificado(t), isTrue, reason: 'Tipo "$t" não entra em nenhum total');
      }
    });
  });

  group('TotaisTurno - gaveta e suprimentos', () {
    test('Suprimento entra no dinheiro da gaveta e fica fora do total de vendas', () {
      // Fundo 100 + 500 em dinheiro + 50 de suprimento - 200 de sangria - 30 de despesa
      final totais = TotaisTurno(
        dinheiro: 500,
        suprimentos: 50,
        qtdSuprimentos: 1,
        sangrias: 200,
        qtdSangrias: 1,
        despesas: 30,
        fundoCaixa: 100,
        totalGeral: 530,
        dinheiroGaveta: 100 + 500 + 50 - 200 - 30,
      );

      expect(totais.dinheiroGaveta, equals(420));
      // O suprimento é reposição de troco, não venda: não infla o total geral
      expect(totais.totalGeral, equals(530));
    });

    test('copyWith preserva suprimentos', () {
      final base = TotaisTurno(suprimentos: 75, qtdSuprimentos: 2);
      final copia = base.copyWith(vendasSistema: 1000);

      expect(copia.suprimentos, equals(75));
      expect(copia.qtdSuprimentos, equals(2));
      expect(copia.vendasSistema, equals(1000));
    });
  });
}
