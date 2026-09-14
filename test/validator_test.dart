import 'package:flutter_test/flutter_test.dart';
import 'package:caixa_posto_janjao/utils/app_haptics.dart';
import 'package:caixa_posto_janjao/utils/validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('Validator - Nomes parecidos (cadastro duplicado)', () {
    void parecidos(String a, String b) {
      expect(Validator.nomesParecidos(a, b), isTrue, reason: '"$a" x "$b"');
      expect(Validator.nomesParecidos(b, a), isTrue, reason: '"$b" x "$a"');
    }

    void diferentes(String a, String b) {
      expect(Validator.nomesParecidos(a, b), isFalse, reason: '"$a" x "$b"');
      expect(Validator.nomesParecidos(b, a), isFalse, reason: '"$b" x "$a"');
    }

    test('Mesmo nome com maiúscula, acento ou conectivo diferente', () {
      parecidos('MARCOS', 'Marcos');
      parecidos('joão victor almeida', 'Joao Victor Almeida');
      parecidos('Bruno Costa Neves', 'Bruno Costa das Neves');
      // Acento que chega separado da letra (a + ~), como alguns teclados mandam
      parecidos('Joa${String.fromCharCode(0x0303)}o', 'João');
    });

    test('Só parte do nome de quem já tem cadastro', () {
      parecidos('Joao', 'João Victor Almeida');
      parecidos('Renan Pereira', 'Renan');
      parecidos('Thiago', 'Tiago Souza');
    });

    test('Uma letra de diferença ou nome abreviado', () {
      parecidos('Joao Vitor Almeida', 'João Victor Almeida');
      parecidos('Luis Carlos', 'Luiz Carlos Pereira');
      parecidos('Robsom', 'Robson');
      parecidos('Wellingtom', 'Wellington');
      parecidos('J Silva', 'Joao Silva');
      parecidos('Pedro Henrique', 'Pedro H Rocha');
    });

    test('Pessoas diferentes não são barradas', () {
      diferentes('Joao Pedro', 'Joao Victor Almeida');
      diferentes('Luiz Fernando', 'Luiz Carlos Pereira');
      diferentes('Renan', 'Renato');
      diferentes('Josivan', 'Josenilson');
      diferentes('Franklin', 'Frankson');
      diferentes('Alexandre', 'Alessandro');
      diferentes('Joana', 'Joao');
      diferentes('Ana', 'Ane');
    });

    test('Masculino e feminino não contam como erro de digitação', () {
      diferentes('Paula', 'Paulo');
      diferentes('Daniela', 'Daniel');
      diferentes('Maria', 'Mario');
      diferentes('Carla', 'Carlos');
    });

    test('Só iniciais em comum não bastam', () {
      diferentes('Jorge', 'J Silva');
    });

    test('Nome vazio ou só com conectivos não esbarra em ninguém', () {
      diferentes('', 'Joao');
      diferentes('Da Silva', 'Joao');
    });

    test('Uma equipe sem duplicados não esbarra em si mesma', () {
      const equipe = [
        'Ana Paula',
        'Bruno Costa das Neves',
        'Carlos Eduardo',
        'Franklin',
        'Frankson',
        'Joao Victor Almeida',
        'Josenilson',
        'Josivan',
        'Luiz Carlos Pereira',
        'Marcos',
        'Pedro Henrique Rocha',
      ];
      for (var i = 0; i < equipe.length; i++) {
        for (var j = i + 1; j < equipe.length; j++) {
          diferentes(equipe[i], equipe[j]);
        }
      }
    });
  });
}
