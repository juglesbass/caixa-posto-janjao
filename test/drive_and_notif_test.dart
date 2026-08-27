import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:caixa_posto_janjao/services/drive_service.dart';
import 'package:caixa_posto_janjao/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DriveService & Modo Teste Testes', () {
    test('Constantes de homologação corretas', () {
      expect(DriveService.testFolderId, equals('1uvJ6r3ZVzfw5Qv0X471hM11jYMSdbqhM'));
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

