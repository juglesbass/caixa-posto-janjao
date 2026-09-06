import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Vibração no navegador via `dart:js_interop`.
///
/// Substitui o antigo `dart:js`, descontinuado e indisponível na compilação para
/// WebAssembly. `navigator.vibrate` não existe no iOS e é ignorado por vários
/// navegadores — por isso toda a função é best-effort e silenciosa.
void triggerWebVibrate(dynamic pattern) {
  try {
    final navigator = globalContext.getProperty<JSObject?>('navigator'.toJS);
    if (navigator == null) return;
    if (!navigator.hasProperty('vibrate'.toJS).toDart) return;

    if (pattern is int) {
      navigator.callMethod<JSAny?>('vibrate'.toJS, pattern.toJS);
    } else if (pattern is List<int>) {
      navigator.callMethod<JSAny?>(
        'vibrate'.toJS,
        pattern.map((ms) => ms.toJS).toList().toJS,
      );
    }
  } catch (_) {}
}
