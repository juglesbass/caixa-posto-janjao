/// Notificações do navegador. O guard é `dart.library.js_interop` (e não mais
/// `dart.library.html`) porque é ele que também vale na compilação para
/// WebAssembly — `dart:html` não existe lá.
export 'web_notification_stub.dart'
    if (dart.library.js_interop) 'web_notification_web.dart';
