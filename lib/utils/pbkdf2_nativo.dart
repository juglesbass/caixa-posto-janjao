/// PBKDF2-HMAC-SHA256 pelo motor de criptografia do próprio navegador.
///
/// O guard é `dart.library.js_interop` pelo mesmo motivo das notificações: é ele
/// que também vale quando o app é compilado para WebAssembly, onde `dart:html`
/// não existe.
export 'pbkdf2_nativo_stub.dart'
    if (dart.library.js_interop) 'pbkdf2_nativo_web.dart';
