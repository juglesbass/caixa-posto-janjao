/// Implementação vazia usada no Web, onde as notificações saem pela API
/// `Notification` do navegador.
Future<void> inicializarNotificacoesLocais() async {}

Future<void> solicitarPermissaoNotificacaoLocal() async {}

Future<void> mostrarNotificacaoLocal({
  required int id,
  required String titulo,
  required String corpo,
}) async {}
