import 'package:flutter_test/flutter_test.dart';
import 'package:caixa_posto_janjao/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
