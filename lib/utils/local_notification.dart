/// Notificações do sistema em Android e iOS.
///
/// No Web o caminho continua sendo a API `Notification` do navegador
/// (ver `web_notification.dart`): a implementação web do
/// flutter_local_notifications substitui o service worker do Flutter pelo dela,
/// e trocar isso mexeria na instalação e no cache do PWA sem necessidade.
export 'local_notification_stub.dart'
    if (dart.library.io) 'local_notification_io.dart';
