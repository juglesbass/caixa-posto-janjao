import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:caixa_posto_janjao/models/operador_model.dart';
import 'package:caixa_posto_janjao/services/auth_service.dart';

void main() {
  group('OperadorModel e Sincronização Firestore', () {
    test('Serialização e Deserialização Map (SQLite / Cache)', () {
      final now = DateTime(2026, 9, 2, 15, 30);
      final hashPin = AuthService.hashPin('1234');

      final operador = OperadorModel(
        id: 'op_123',
        nome: 'João Victor',
        pinHash: hashPin,
        ativo: true,
        atualizadoEm: now,
      );

      final map = operador.toMap();
      expect(map['id'], equals('op_123'));
      expect(map['nome'], equals('João Victor'));
      expect(map['pin_hash'], equals(hashPin));
      expect(map['ativo'], equals(1));
      expect(map['atualizado_em'], equals(now.toIso8601String()));

      final reconstruido = OperadorModel.fromMap(map);
      expect(reconstruido.id, equals('op_123'));
      expect(reconstruido.nome, equals('João Victor'));
      expect(reconstruido.pinHash, equals(hashPin));
      expect(reconstruido.ativo, isTrue);
      expect(reconstruido.nomeExibicao, equals('João Victor'));
      expect(reconstruido.nomeNormalizado, equals('joão_victor'));
    });

    test('Serialização e Deserialização Firestore REST API', () {
      final now = DateTime.utc(2026, 9, 2, 19, 0, 0);
      final hashPin = AuthService.hashPin('5678');

      final operador = OperadorModel(
        id: 'op_teste_456',
        nome: 'Maria Silva',
        pinHash: hashPin,
        ativo: true,
        atualizadoEm: now,
      );

      final restJson = operador.toFirestoreRest();
      expect(restJson.containsKey('fields'), isTrue);

      final fields = restJson['fields'] as Map<String, dynamic>;
      expect(fields['id']['stringValue'], equals('op_teste_456'));
      expect(fields['nome']['stringValue'], equals('Maria Silva'));
      expect(fields['pin_hash']['stringValue'], equals(hashPin));
      expect(fields['ativo']['booleanValue'], isTrue);
      expect(fields['atualizado_em']['timestampValue'], equals(now.toIso8601String()));

      final mockDocFirestore = {
        'name': 'projects/caixa-posto-janjao/databases/(default)/documents/operadores/op_teste_456',
        'fields': fields,
        'updateTime': '2026-09-02T19:00:00Z',
      };

      final doFirestore = OperadorModel.fromFirestoreRest(mockDocFirestore);
      expect(doFirestore.id, equals('op_teste_456'));
      expect(doFirestore.nome, equals('Maria Silva'));
      expect(doFirestore.pinHash, equals(hashPin));
      expect(doFirestore.ativo, isTrue);
    });

    test('OperadorModel copyWith para alteração de status e PIN', () {
      final op = OperadorModel(
        id: 'op_789',
        nome: 'Carlos',
        pinHash: AuthService.hashPin('1111'),
        ativo: true,
        atualizadoEm: DateTime.now(),
      );

      final novoHash = AuthService.hashPin('2222');
      final desativado = op.copyWith(ativo: false, pinHash: novoHash);

      expect(desativado.id, equals('op_789'));
      expect(desativado.nome, equals('Carlos'));
      expect(desativado.ativo, isFalse);
      expect(desativado.pinHash, equals(novoHash));
    });

    test('Hash legado SHA-256 continua sendo aceito na validação', () {
      const pinCorreto = '4321';
      const pinIncorreto = '9999';

      final hashLegado = AuthService.hashPin(pinCorreto);

      // A fórmula legada continua sendo SHA-256 puro do PIN
      expect(hashLegado, equals(sha256.convert(utf8.encode(pinCorreto)).toString()));
      expect(AuthService.hashEhLegado(hashLegado), isTrue);

      // Credenciais antigas (na nuvem ou no cache) seguem validando
      expect(AuthService.verificarPin(pinCorreto, hashLegado), isTrue);
      expect(AuthService.verificarPin(pinIncorreto, hashLegado), isFalse);
    });

    test('Hash moderno PBKDF2 usa sal aleatório e valida corretamente', () {
      const pinCorreto = '4321';
      const pinIncorreto = '9999';

      final hash1 = AuthService.gerarHashPin(pinCorreto);
      final hash2 = AuthService.gerarHashPin(pinCorreto);

      // Formato: pbkdf2_sha256:<iteracoes>:<sal_hex>:<derivado_hex>
      expect(hash1.split(':').length, equals(4));
      expect(hash1.startsWith('pbkdf2_sha256:'), isTrue);
      expect(AuthService.hashEhLegado(hash1), isFalse);

      // O sal aleatório faz o mesmo PIN gerar hashes diferentes, o que impede
      // quebrar todos os operadores de uma vez e inutiliza rainbow tables
      expect(hash1, isNot(equals(hash2)));

      expect(AuthService.verificarPin(pinCorreto, hash1), isTrue);
      expect(AuthService.verificarPin(pinCorreto, hash2), isTrue);
      expect(AuthService.verificarPin(pinIncorreto, hash1), isFalse);
    });

    test('verificarPin rejeita hashes vazios ou corrompidos', () {
      expect(AuthService.verificarPin('1234', null), isFalse);
      expect(AuthService.verificarPin('1234', ''), isFalse);
      expect(AuthService.verificarPin('1234', 'pbkdf2_sha256:xxx'), isFalse);
      expect(AuthService.verificarPin('1234', 'pbkdf2_sha256:0::'), isFalse);
      expect(AuthService.verificarPin('1234', 'pbkdf2_sha256:1000:zz:aa'), isFalse);
    });
  });
}
