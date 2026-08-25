import 'package:flutter/foundation.dart';
import '../utils/web_notification.dart';
import 'database_service.dart';

class NotificationService {
  /// Notifier reativo para exibir badge ou banner na interface quando houver pendências
  static final ValueNotifier<int> pendenciasCount = ValueNotifier<int>(0);

  /// Inicializa o serviço e verifica a fila
  static Future<void> inicializar() async {
    try {
      requestNotificationPermission();
      await atualizarPendencias();
    } catch (_) {}
  }

  /// Recarrega a contagem de pendências do banco de dados
  static Future<int> atualizarPendencias() async {
    try {
      final db = DatabaseService.instance;
      final lista = await db.obterPendenciasDrive();
      pendenciasCount.value = lista.length;
      return lista.length;
    } catch (_) {
      return 0;
    }
  }

  /// Notifica o usuário de que o PDF de fechamento ficou na fila pendente
  static void notificarPendenciaDrive({
    required int turnoNumero,
    required String operador,
  }) {
    showSystemNotification(
      'Posto Janjão ⛽ - Envio Pendente',
      '⚠️ O PDF do Turno #$turnoNumero ($operador) está salvo na fila aguardando conexão com a internet para envio ao Google Drive.',
    );
  }

  /// Notifica o usuário de que os PDFs pendentes foram enviados com sucesso
  static void notificarSucessoDrive({required int totalEnviados}) {
    if (totalEnviados <= 0) return;
    showSystemNotification(
      'Posto Janjão ⛽ - Drive Sincronizado',
      '✅ $totalEnviados relatório(s) PDF entregue(s) com sucesso no Google Drive do Gerente!',
    );
  }
}
