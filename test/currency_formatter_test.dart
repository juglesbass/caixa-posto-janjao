import 'package:flutter_test/flutter_test.dart';
import 'package:caixa_posto_janjao/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter - Formatação e Parse de Moeda', () {
    test('Formata valores simples para Real brasileiro', () {
      expect(CurrencyFormatter.formatar(0.0), contains('0,00'));
      expect(CurrencyFormatter.formatar(50.0), contains('50,00'));
      expect(CurrencyFormatter.formatar(47.75), contains('47,75'));
      expect(CurrencyFormatter.formatar(1250.50), contains('1.250,50'));
    });

    test('Faz parse de strings para float com centavos', () {
      expect(CurrencyFormatter.parse(''), equals(0.0));
      expect(CurrencyFormatter.parse('0'), equals(0.0));
      expect(CurrencyFormatter.parse('5000'), equals(50.0));
      expect(CurrencyFormatter.parse('4775'), equals(47.75));
      expect(CurrencyFormatter.parse('R\$ 1.250,50'), equals(1250.50));
      expect(CurrencyFormatter.parse('R\$ 47,75'), equals(47.75));
    });
  });
}
