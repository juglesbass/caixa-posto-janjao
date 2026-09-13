import 'package:flutter_test/flutter_test.dart';
import 'package:caixa_posto_janjao/models/motivo_pendencia.dart';

void main() {
  group('MotivoPendencia - o banner precisa dizer a verdade', () {
    test('Timeout não é tratado como falta de internet', () {
      final texto = MotivoPendencia.descricao(MotivoPendencia.servidorDemorou);

      // O sintoma original: aparelho em 5G e o app afirmando "sem internet"
      expect(texto.toLowerCase(), isNot(contains('sem internet')));
      expect(texto.toLowerCase(), isNot(contains('sem conexão')));

      // E precisa avisar que o PDF pode já estar no Drive, senão o operador
      // acha que o fechamento se perdeu
      expect(texto.toLowerCase(), contains('pode já ter sido entregue'));
    });

    test('Tela de login aponta para a gerência, não para a rede', () {
      final texto = MotivoPendencia.descricao(MotivoPendencia.precisaLogin);

      expect(texto.toLowerCase(), contains('login'));
      expect(texto.toLowerCase(), contains('gerência'));
      // Mandar esperar a internet voltar seria o conselho errado aqui
      expect(texto.toLowerCase(), isNot(contains('sem internet')));
    });

    test('Erro do servidor não vira problema de rede', () {
      final texto = MotivoPendencia.descricao(MotivoPendencia.erroServidor);

      expect(texto.toLowerCase(), contains('servidor'));
      expect(texto.toLowerCase(), isNot(contains('sem internet')));
    });

    test('Falta de rede real continua sendo dita como tal', () {
      expect(
        MotivoPendencia.descricao(MotivoPendencia.semConexao).toLowerCase(),
        contains('sem internet'),
      );
    });

    test('Motivos novos não culpam a internet', () {
      for (final codigo in [
        MotivoPendencia.naoConfirmado,
        MotivoPendencia.erroApp,
        MotivoPendencia.envioInterrompido,
      ]) {
        final texto = MotivoPendencia.descricao(codigo).toLowerCase();
        expect(texto, isNot(contains('sem internet')), reason: codigo);
        expect(texto, isNot(contains('sem conexão')), reason: codigo);
        expect(texto, isNot(contains('aguardando envio')),
            reason: '$codigo caiu no texto genérico');
      }
    });

    test('Servidor demorou não manda mais o operador reenviar por conta própria', () {
      final texto = MotivoPendencia.descricao(MotivoPendencia.servidorDemorou).toLowerCase();
      expect(texto, isNot(contains('reenvie')));
      expect(texto, contains('confere'));
    });

    test('Pendência antiga (sem motivo gravado) não inventa uma causa', () {
      // Pendências enfileiradas antes da migração têm motivo nulo: o texto
      // precisa ser neutro em vez de chutar "sem internet".
      for (final desconhecido in <String?>[null, '', 'motivo_que_nao_existe']) {
        final texto = MotivoPendencia.descricao(desconhecido).toLowerCase();
        expect(texto, isNot(contains('sem internet')));
        expect(texto, contains('aguardando envio'));
      }
    });

    test('Todo motivo conhecido tem texto próprio e não se repete', () {
      final codigos = <String>[
        MotivoPendencia.semConexao,
        MotivoPendencia.servidorDemorou,
        MotivoPendencia.precisaLogin,
        MotivoPendencia.erroServidor,
        MotivoPendencia.naoConfirmado,
        MotivoPendencia.erroApp,
        MotivoPendencia.envioInterrompido,
      ];
      final textos = codigos.map(MotivoPendencia.descricao).toSet();

      expect(textos.length, equals(codigos.length),
          reason: 'Dois motivos diferentes estão mostrando a mesma mensagem');
      for (final t in textos) {
        expect(t.trim(), isNotEmpty);
      }
    });
  });
}
