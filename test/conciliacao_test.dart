import 'package:caixa_posto_janjao/utils/conciliacao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  EstadoConciliacao e(double pista, double sistema) =>
      Conciliacao.estado(totalPista: pista, vendasSistema: sistema);

  group('Conciliação pista × sistema', () {
    // O caso que confundia o gerente: frentista esqueceu de digitar o sistema.
    test('sem venda do sistema não há sobra nem falta', () {
      expect(e(2884.97, 0), EstadoConciliacao.semSistema);
      expect(e(0, 0), EstadoConciliacao.semSistema);
    });

    test('valores iguais fecham a pista', () {
      expect(e(2884.97, 2884.97), EstadoConciliacao.fechada);
      // Soma com arredondamento de ponto flutuante continua fechando.
      expect(e(0.1 + 0.2, 0.3), EstadoConciliacao.fechada);
    });

    test('pista maior que o sistema é sobra; menor é falta', () {
      expect(e(2900, 2884.97), EstadoConciliacao.sobra);
      expect(e(2800, 2884.97), EstadoConciliacao.falta);
    });

    // Antes, um centavo exato caía no meio das regras e virava "falta" com
    // valor positivo no PDF.
    test('um centavo de diferença já conta, para o lado certo', () {
      expect(e(100.01, 100.00), EstadoConciliacao.sobra);
      expect(e(99.99, 100.00), EstadoConciliacao.falta);
    });
  });
}
