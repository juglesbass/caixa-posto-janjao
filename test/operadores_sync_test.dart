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

    test('Exclusão reversível sobrevive à ida e volta do Firestore', () {
      final op = OperadorModel(
        id: 'op_excluido',
        nome: 'Ex Operador',
        pinHash: AuthService.gerarHashPin('3333'),
        ativo: true,
        atualizadoEm: DateTime.utc(2026, 9, 6),
        criadoEm: DateTime.utc(2026, 1, 1),
      );

      expect(op.removido, isFalse);

      final marcado = op.copyWith(ativo: false, removido: true);
      expect(marcado.removido, isTrue);
      expect(marcado.ativo, isFalse);

      // SQLite / SharedPreferences
      expect(OperadorModel.fromMap(marcado.toMap()).removido, isTrue);

      // Firestore REST: o documento continua existindo, só marcado.
      final fields = marcado.toFirestoreRest()['fields'] as Map<String, dynamic>;
      expect(fields['removido']['booleanValue'], isTrue);

      final daNuvem = OperadorModel.fromFirestoreRest({
        'name': 'projects/x/databases/(default)/documents/operadores/op_excluido',
        'fields': fields,
      });
      expect(daNuvem.removido, isTrue);
      expect(daNuvem.ativo, isFalse);
    });

    test('Documento antigo sem o campo removido é lido como não removido', () {
      // Compatibilidade com os operadores que já estão na nuvem desde antes da
      // exclusão reversível existir.
      final antigo = OperadorModel.fromFirestoreRest({
        'name': 'projects/x/databases/(default)/documents/operadores/op_antigo',
        'fields': {
          'nome': {'stringValue': 'Antigo'},
          'pin_hash': {'stringValue': AuthService.hashPin('1234')},
          'ativo': {'booleanValue': true},
        },
      });

      expect(antigo.removido, isFalse);
      expect(antigo.ativo, isTrue);
      expect(OperadorModel.fromMap({'id': 'x', 'nome': 'Y', 'pin_hash': 'z'}).removido, isFalse);
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

    test('hashEhLegado marca hashes fracos e poupa os fortes', () {
      // Formato antigo (SHA-256 puro)
      expect(AuthService.hashEhLegado(AuthService.hashPin('1234')), isTrue);

      // PBKDF2 com contagem de iterações das versões anteriores
      const hashFraco = 'pbkdf2_sha256:600:aabb:ccdd';
      expect(AuthService.hashEhLegado(hashFraco), isTrue);

      // Um hash gerado agora nunca pode ser considerado legado — se fosse, o app
      // o reescreveria a cada login, sem fim.
      final atual = AuthService.gerarHashPin('1234');
      expect(AuthService.hashEhLegado(atual), isFalse);

      // Hash mais forte que o alvo desta plataforma também não é legado: marcar
      // como legado faria o app enfraquecê-lo sozinho.
      final maisForte = AuthService.gerarHashPin('1234', iteracoes: 200000);
      expect(AuthService.hashEhLegado(maisForte), isFalse);
      expect(AuthService.verificarPin('1234', maisForte), isTrue);
    });

    test('verificarPin rejeita hashes vazios ou corrompidos', () {
      expect(AuthService.verificarPin('1234', null), isFalse);
      expect(AuthService.verificarPin('1234', ''), isFalse);
      expect(AuthService.verificarPin('1234', 'pbkdf2_sha256:xxx'), isFalse);
      expect(AuthService.verificarPin('1234', 'pbkdf2_sha256:0::'), isFalse);
      expect(AuthService.verificarPin('1234', 'pbkdf2_sha256:1000:zz:aa'), isFalse);
    });
  });

  group('Chave de autenticacao - identidade do FECHAMENTO', () {
    // A chave de autenticacao identifica de forma unica cada fechamento.
    // O backend do Drive e o app usam essa unicidade para rastreabilidade,
    // garantindo que cada evento de fechamento tenha identidade e hash proprios.

    test('Reenvio do mesmo fechamento produz a mesma chave', () {
      final a = AuthService.gerarChaveAutenticacao(
        operador: 'Agildo',
        turnoId: 7,
        totalVendas: 1234.56,
        timestamp: '06/09/2026 14:30:00',
      );
      final b = AuthService.gerarChaveAutenticacao(
        operador: 'Agildo',
        turnoId: 7,
        totalVendas: 1234.56,
        timestamp: '06/09/2026 14:30:00',
      );

      expect(a, equals(b));
      expect(a, startsWith('AUTH-'));
    });

    test('Fechar o mesmo turno de novo gera chave diferente', () {
      const operador = 'Agildo';
      const turnoId = 7;

      // Fechamento original
      final original = AuthService.gerarChaveAutenticacao(
        operador: operador,
        turnoId: turnoId,
        totalVendas: 1234.56,
        timestamp: '06/09/2026 14:30:00',
      );

      // Operador reabre "só para mexer" e fecha de novo, minutos depois
      final refeito = AuthService.gerarChaveAutenticacao(
        operador: operador,
        turnoId: turnoId,
        totalVendas: 1234.56,
        timestamp: '06/09/2026 14:45:00',
      );

      expect(refeito, isNot(equals(original)),
          reason: 'Cada fechamento deve possuir autenticação e identidade únicas');
    });

    test('Mudar o total tambem muda a chave', () {
      final antes = AuthService.gerarChaveAutenticacao(
        operador: 'Agildo',
        turnoId: 7,
        totalVendas: 1234.56,
        timestamp: '06/09/2026 14:30:00',
      );
      // Ex.: um lancamento foi apagado antes de fechar de novo
      final depois = AuthService.gerarChaveAutenticacao(
        operador: 'Agildo',
        turnoId: 7,
        totalVendas: 1000.00,
        timestamp: '06/09/2026 14:30:00',
      );

      expect(depois, isNot(equals(antes)));
    });

    test('Turnos diferentes nunca compartilham chave', () {
      final t1 = AuthService.gerarChaveAutenticacao(
        operador: 'Agildo',
        turnoId: 1,
        totalVendas: 500.00,
        timestamp: '06/09/2026 14:30:00',
      );
      final t2 = AuthService.gerarChaveAutenticacao(
        operador: 'Agildo',
        turnoId: 2,
        totalVendas: 500.00,
        timestamp: '06/09/2026 14:30:00',
      );

      expect(t1, isNot(equals(t2)));
    });
  });
}
