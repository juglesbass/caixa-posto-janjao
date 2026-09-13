import 'package:flutter/foundation.dart';
import '../models/motivo_pendencia.dart';
import '../utils/local_notification.dart';
import '../utils/web_notification.dart';
import 'database_service.dart';

class NotificationService {
  /// Notifier reativo para exibir badge ou banner na interface quando houver pendências
  static final ValueNotifier<int> pendenciasCount = ValueNotifier<int>(0);

  /// Causa da pendência mais recente da fila, para o banner explicar o que houve
  /// em vez de sempre culpar a internet
  static final ValueNotifier<String?> motivoPendencia = ValueNotifier<String?>(null);

  /// IDs fixos: cada aviso substitui o anterior em vez de empilhar na bandeja
  static const int _idPendencia = 1001;
  static const int _idSucesso = 1002;

  /// Inicializa o serviço e verifica a fila.
  ///
  /// Só prepara o canal de notificação: a permissão em si é pedida em
  /// [solicitarPermissao], a partir de uma ação do usuário.
  static Future<void> inicializar() async {
    try {
      await inicializarNotificacoesLocais();
      requestNotificationPermission();
      await atualizarPendencias();
    } catch (_) {}
  }

  /// Pede a permissão de notificação ao usuário.
  ///
  /// Deve ser chamada a partir de uma ação dele (abrir turno, por exemplo), e
  /// não na inicialização: no Android 13+ e no iOS o prompt aparece na hora, e
  /// dispará-lo na primeira tela é o jeito mais rápido de o usuário negar.
  static Future<void> solicitarPermissao() async {
    try {
      await solicitarPermissaoNotificacaoLocal();
      requestNotificationPermission();
    } catch (_) {}
  }

  /// Recarrega a contagem de pendências do banco de dados
  static Future<int> atualizarPendencias() async {
    try {
      final db = DatabaseService.instance;
      // Envio em andamento não é pendência para o operador: a linha já existe
      // no banco (nasce com o fechamento), mas só vira aviso se o envio falhar
      // ou não terminar. Ver [DatabaseService.enviosDriveEmCurso].
      final lista = (await db.obterPendenciasDrive())
          .where((p) => !DatabaseService.enviosDriveEmCurso.contains(p['turno_id']))
          .toList();
      pendenciasCount.value = lista.length;
      // A lista vem ordenada por id ASC: a última é a pendência mais recente
      motivoPendencia.value =
          lista.isNotEmpty ? lista.last['motivo'] as String? : null;
      return lista.length;
    } catch (_) {
      return 0;
    }
  }

  /// Notifica o usuário de que o PDF de fechamento ficou na fila pendente
  ///
  /// O texto vem do [motivo] real. Antes era fixo em "aguardando conexão com a
  /// internet" para qualquer falha — inclusive quando havia sinal e o PDF
  /// provavelmente já estava no Drive.
  static void notificarPendenciaDrive({
    required int turnoNumero,
    required String operador,
    String? motivo,
  }) {
    const titulo = 'Posto Janjão ⛽ - Envio Pendente';
    final corpo =
        '⚠️ PDF do Turno #$turnoNumero ($operador) na fila. ${MotivoPendencia.descricao(motivo)}';

    showSystemNotification(titulo, corpo);
    mostrarNotificacaoLocal(id: _idPendencia, titulo: titulo, corpo: corpo);
  }

  /// Notifica o usuário de que os PDFs pendentes foram enviados com sucesso
  static void notificarSucessoDrive({required int totalEnviados}) {
    if (totalEnviados <= 0) return;
    const titulo = 'Posto Janjão ⛽ - Drive Sincronizado';
    final corpo =
        '✅ $totalEnviados relatório(s) PDF entregue(s) com sucesso no Google Drive do Gerente!';

    showSystemNotification(titulo, corpo);
    mostrarNotificacaoLocal(id: _idSucesso, titulo: titulo, corpo: corpo);
  }
}
