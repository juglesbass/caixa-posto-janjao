import 'package:flutter_test/flutter_test.dart';
import 'package:caixa_posto_janjao/utils/app_haptics.dart';
import 'package:caixa_posto_janjao/utils/validator.dart';

void main() {
  group('Validator - Validação de Nome de Operador', () {
    test('Rejeita nomes vazios ou com espaços em branco', () {
      expect(Validator.validarNomeOperador(''), isNotNull);
      expect(Validator.validarNomeOperador('   '), isNotNull);
      expect(Validator.validarNomeOperador(null), isNotNull);
    });

    test('Rejeita iniciais de 1 ou 2 letras', () {
      expect(Validator.validarNomeOperador('J'), isNotNull);
      expect(Validator.validarNomeOperador('Al'), isNotNull);
      expect(Validator.validarNomeOperador(' a '), isNotNull);
    });

    test('Rejeita apenas números ou caracteres especiais', () {
      expect(Validator.validarNomeOperador('123'), isNotNull);
      expect(Validator.validarNomeOperador('12345'), isNotNull);
      expect(Validator.validarNomeOperador('@#\$%'), isNotNull);
    });

    test('Aceita nomes válidos com 3 ou mais letras alfabéticas', () {
      expect(Validator.validarNomeOperador('Ana'), isNull);
      expect(Validator.validarNomeOperador('João'), isNull);
      expect(Validator.validarNomeOperador('joão victor'), isNull);
      expect(Validator.validarNomeOperador('MARIA CLARA'), isNull);
      expect(Validator.validarNomeOperador('José Carlos'), isNull);
    });

    test('Formata nomes corretamente em Title Case', () {
      expect(Validator.formatarNomeOperador('joão victor'), equals('João Victor'));
      expect(Validator.formatarNomeOperador('MARIA SILVA'), equals('Maria Silva'));
      expect(Validator.formatarNomeOperador('pedro'), equals('Pedro'));
    });

    test('AppHaptics executa sem exceção', () {
      expect(() => AppHaptics.light(), returnsNormally);
      expect(() => AppHaptics.selection(), returnsNormally);
      expect(() => AppHaptics.medium(), returnsNormally);
      expect(() => AppHaptics.heavy(), returnsNormally);
    });
  });
}
