import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:caixa_posto_janjao/services/database_service.dart';
import 'package:caixa_posto_janjao/services/drive_service.dart';
import 'package:caixa_posto_janjao/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DriveService & Modo Teste Testes', () {
    test('Constantes de homologação e produção corretas', () {
      expect(DriveService.PASTA_OFICIAL_ID, equals('1lW3RYNyOzPz1R8A-vT9t9QWoLNvkADsC'));
      expect(DriveService.PASTA_TESTES_ID, equals('1uvJ6r3ZVzfw5Qv0X471hM11jYMSdbqhM'));
      expect(DriveService.testFolderId, equals('1uvJ6r3ZVzfw5Qv0X471hM11jYMSdbqhM'));
      expect(DriveService.pastaOficialId, equals('1lW3RYNyOzPz1R8A-vT9t9QWoLNvkADsC'));
      expect(DriveService.keyModoTeste, equals('modo_teste_ativo'));
    });

    test('Alternância e persistência de Modo Teste', () async {
      SharedPreferences.setMockInitialValues({'modo_teste_ativo': false});
      expect(await DriveService.isModoTeste(), isFalse);
      expect(DriveService.modoTesteNotifier.value, isFalse);

      await DriveService.setModoTeste(true);
      expect(await DriveService.isModoTeste(), isTrue);
      expect(DriveService.modoTesteNotifier.value, isTrue);

      await DriveService.setModoTeste(false);
      expect(await DriveService.isModoTeste(), isFalse);
      expect(DriveService.modoTesteNotifier.value, isFalse);
    });

    test('Validação de resposta HTTP direta (Fonte da Verdade) - isRespostaSucesso', () {
      // 200 OK padrão
      expect(DriveService.isRespostaSucesso(http.Response('OK', 200)), isTrue);
      // 201 Created
      expect(DriveService.isRespostaSucesso(http.Response('Created', 201)), isTrue);
      // 204 No Content
      expect(DriveService.isRespostaSucesso(http.Response('', 204)), isTrue);

      // Redirecionamentos 302/303/307 do Google Apps Script (confirmação que doPost foi processado)
      expect(DriveService.isRespostaSucesso(http.Response('Moved Temporarily', 302)), isTrue);
      expect(DriveService.isRespostaSucesso(http.Response('See Other', 303)), isTrue);
      expect(DriveService.isRespostaSucesso(http.Response('Temporary Redirect', 307)), isTrue);

      // Respostas JSON do Apps Script
      expect(DriveService.isRespostaSucesso(http.Response('{"status":"success","id":"xyz"}', 200)), isTrue);
      expect(DriveService.isRespostaSucesso(http.Response('{"result":"success"}', 200)), isTrue);
      expect(DriveService.isRespostaSucesso(http.Response('{"status":"ok"}', 200)), isTrue);
      expect(
        DriveService.isRespostaSucesso(
          http.Response('{"status":"success","nome_arquivo":"Agildo 08-09-2026 T1_v2.pdf","versao_aplicada":true}', 200),
        ),
        isTrue,
      );

      // JSON de erro explícito do Apps Script
      expect(DriveService.isRespostaSucesso(http.Response('{"status":"error","message":"Falha"}', 200)), isFalse);
      expect(DriveService.isRespostaSucesso(http.Response('{"success":false}', 200)), isFalse);

      // Falhas reais do servidor
      expect(DriveService.isRespostaSucesso(http.Response('Bad Request', 400)), isFalse);
      expect(DriveService.isRespostaSucesso(http.Response('Not Found', 404)), isFalse);
      expect(DriveService.isRespostaSucesso(http.Response('Internal Error', 500)), isFalse);
    });

    test('Tela de login do Google em HTTP 200 NÃO é entrega no Drive', () {
      // Quando o Apps Script é publicado com acesso "Qualquer pessoa com conta
      // Google", o Google responde 200 com a página de login em vez de executar
      // o script. Tratar isso como sucesso apagava a pendência e dava o
      // fechamento como entregue sem que nada chegasse à pasta do gerente.
      const paginaLogin = '<html><head><title>Sign in - Google Accounts</title></head>'
          '<body><form action="https://accounts.google.com/ServiceLogin"></form></body></html>';

      expect(DriveService.isRespostaSucesso(http.Response(paginaLogin, 200)), isFalse);
      expect(DriveService.isRespostaSucesso(http.Response(paginaLogin, 302)), isFalse);
    });

    test('Página de erro de execução do Apps Script NÃO é entrega no Drive', () {
      expect(
        DriveService.isRespostaSucesso(
          http.Response('<html><body>Script function not found: doPost</body></html>', 200),
        ),
        isFalse,
      );
      expect(
        DriveService.isRespostaSucesso(
          http.Response('TypeError: Cannot read property of undefined', 200),
        ),
        isFalse,
      );
    });

    test('Backoff da fila cresce e satura, sem laço apertado de reenvio', () {
      expect(DatabaseService.backoffDaFila(0), equals(Duration.zero));

      final primeira = DatabaseService.backoffDaFila(1);
      final segunda = DatabaseService.backoffDaFila(2);
      final terceira = DatabaseService.backoffDaFila(3);

      expect(primeira, greaterThan(Duration.zero));
      expect(segunda, greaterThan(primeira));
      expect(terceira, greaterThan(segunda));

      // Satura em vez de crescer para sempre
      expect(
        DatabaseService.backoffDaFila(99),
        equals(DatabaseService.backoffDaFila(50)),
      );
      expect(DatabaseService.backoffDaFila(99), lessThanOrEqualTo(const Duration(minutes: 30)));
    });
  });

  group('NotificationService Testes', () {
    test('Contador de pendencias reativo', () {
      expect(NotificationService.pendenciasCount.value, equals(0));

      NotificationService.pendenciasCount.value = 3;
      expect(NotificationService.pendenciasCount.value, equals(3));

      NotificationService.notificarPendenciaDrive(
        turnoNumero: 10,
        operador: 'Carlos',
      );

      NotificationService.notificarSucessoDrive(totalEnviados: 2);
    });
  });
}

