import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Notificações do navegador via `dart:js_interop`.
///
/// A versão anterior usava `dart:html`, que está descontinuada e simplesmente
/// não existe quando o app é compilado para WebAssembly (`flutter build web
/// --wasm`). Com `dart:js_interop` o mesmo código serve para os dois alvos.
///
/// Tudo aqui é tolerante a falha: notificação é conveniência, e navegador sem
/// suporte (ou com a API bloqueada) não pode derrubar o caixa.

JSObject? _construtorNotification() {
  if (!globalContext.hasProperty('Notification'.toJS).toDart) return null;
  return globalContext.getProperty<JSObject?>('Notification'.toJS);
}

String? _permissaoAtual(JSObject ctor) {
  return ctor.getProperty<JSString?>('permission'.toJS)?.toDart;
}

void requestNotificationPermission() {
  try {
    final ctor = _construtorNotification();
    if (ctor == null) return;

    // Só pede quando o usuário ainda não decidiu. Chamar repetidamente (ou já
    // negado/concedido) só gera ruído e alguns navegadores penalizam pedidos
    // feitos fora de um gesto do usuário.
    if (_permissaoAtual(ctor) == 'default') {
      ctor.callMethod<JSAny?>('requestPermission'.toJS);
    }
  } catch (_) {}
}

void showSystemNotification(String title, String body) {
  try {
    final ctor = _construtorNotification();
    if (ctor == null) return;
    if (_permissaoAtual(ctor) != 'granted') return;

    final opcoes = <String, String>{
      'body': body,
      'icon': 'icons/Icon-192.png',
    }.jsify();

    (ctor as JSFunction).callAsConstructor<JSObject>(title.toJS, opcoes);
  } catch (_) {}
}
