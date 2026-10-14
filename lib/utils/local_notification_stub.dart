/// Implementação vazia usada no Web, onde as notificações saem pela API
/// `Notification` do navegador.
Future<void> inicializarNotificacoesLocais() async {}

Future<void> solicitarPermissaoNotificacaoLocal() async {}

Future<void> mostrarNotificacaoLocal({
  required int id,
  required String titulo,
  required String corpo,
}) async {}

/// No PWA o navegador não deixa agendar aviso com a página fechada, então o
/// lembrete de envio só existe no app instalado.
Future<void> agendarNotificacaoLocal({
  required int id,
  required String titulo,
  required String corpo,
  required Duration daqui,
}) async {}

Future<void> cancelarNotificacaoLocal(int id) async {}
