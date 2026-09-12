import 'package:flutter_test/flutter_test.dart';
import 'package:caixa_posto_janjao/services/auth_service.dart';

/// Costura entre o PBKDF2 síncrono (em Dart) e o assíncrono.
///
/// No PWA o caminho assíncrono entrega a derivação ao `crypto.subtle` do
/// navegador, para não congelar a thread que desenha a tela e recebe os toques.
/// Aqui, na VM, ele cai na implementação em Dart — então o que estes testes
/// garantem não é a velocidade, é a compatibilidade: os dois caminhos têm de
/// produzir e aceitar exatamente o mesmo hash, em qualquer combinação.
///
/// Isso importa porque o hash do PIN é gravado no aparelho e no Firestore, e é
/// lido por aparelhos diferentes. Um erro de iterações, de sal ou de tamanho no
/// caminho novo trancaria operadores fora do próprio caixa — e apareceria aqui.
///
/// O [AuthService.limparCache] antes de cada conferência não é enfeite: gerar um
/// hash já popula o cache em memória para aquele par PIN/hash, e sem limpar o
/// teste passaria pelo cache sem derivar nada — verificando coisa nenhuma.
void main() {
  group('PBKDF2 assíncrono (caminho do PWA)', () {
    test('hash gerado de forma síncrona valida de forma assíncrona', () async {
      final hash = AuthService.gerarHashPin('4321');
      AuthService.limparCache();

      expect(await AuthService.verificarPinAsync('4321', hash), isTrue);
      expect(await AuthService.verificarPinAsync('9999', hash), isFalse);
    });

    test('hash gerado de forma assíncrona valida de forma síncrona', () async {
      final hash = await AuthService.gerarHashPinAsync('4321');
      AuthService.limparCache();

      expect(AuthService.verificarPin('4321', hash), isTrue);
      expect(AuthService.verificarPin('9999', hash), isFalse);
    });

    test('formato e força do hash assíncrono são os mesmos do síncrono', () async {
      final hash = await AuthService.gerarHashPinAsync('1234');

      expect(hash.split(':').length, equals(4));
      expect(hash.startsWith('pbkdf2_sha256:'), isTrue);
      // Se fosse considerado legado, o app o reescreveria a cada login, sem fim
      expect(AuthService.hashEhLegado(hash), isFalse);
    });

    test('sal aleatório também no caminho assíncrono', () async {
      final hash1 = await AuthService.gerarHashPinAsync('4321');
      final hash2 = await AuthService.gerarHashPinAsync('4321');

      expect(hash1, isNot(equals(hash2)));
      AuthService.limparCache();
      expect(await AuthService.verificarPinAsync('4321', hash1), isTrue);
      expect(await AuthService.verificarPinAsync('4321', hash2), isTrue);
    });

    test('iterações explícitas são respeitadas e conferem nos dois caminhos', () async {
      final hash = await AuthService.gerarHashPinAsync('1234', iteracoes: 7777);
      expect(hash.split(':')[1], equals('7777'));

      AuthService.limparCache();
      expect(AuthService.verificarPin('1234', hash), isTrue);
      AuthService.limparCache();
      expect(await AuthService.verificarPinAsync('1234', hash), isTrue);
    });

    test('caminho assíncrono aceita o hash legado SHA-256 puro', () async {
      final legado = AuthService.hashPin('5555');
      AuthService.limparCache();

      expect(await AuthService.verificarPinAsync('5555', legado), isTrue);
      expect(await AuthService.verificarPinAsync('1111', legado), isFalse);
    });

    test('verificarPinAsync rejeita hashes vazios ou corrompidos', () async {
      expect(await AuthService.verificarPinAsync('1234', null), isFalse);
      expect(await AuthService.verificarPinAsync('1234', ''), isFalse);
      expect(await AuthService.verificarPinAsync('1234', 'pbkdf2_sha256:xxx'), isFalse);
      expect(await AuthService.verificarPinAsync('1234', 'pbkdf2_sha256:0::'), isFalse);
      expect(await AuthService.verificarPinAsync('1234', 'pbkdf2_sha256:1000:zz:aa'), isFalse);
    });
  });
}
