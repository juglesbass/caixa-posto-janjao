import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// Dispara o download direto de [bytes] no navegador via Blob URL.
///
/// Serve como fallback confiável no Safari (iOS/macOS) e navegadores desktop
/// quando `navigator.share({ files })` falha por expiração de gesto após um
/// `await` no banco ou falta de suporte a compartilhamento de arquivos.
bool baixarArquivoWeb({
  required Uint8List bytes,
  required String nomeArquivo,
  required String mimeType,
}) {
  try {
    final blobCtor = globalContext.getProperty<JSFunction?>('Blob'.toJS);
    final urlApi = globalContext.getProperty<JSObject?>('URL'.toJS);
    final doc = globalContext.getProperty<JSObject?>('document'.toJS);
    if (blobCtor == null || urlApi == null || doc == null) return false;

    final partes = <JSAny?>[bytes.toJS].toJS;
    final opcoes = <String, String>{'type': mimeType}.jsify();
    final blob = blobCtor.callAsConstructor<JSObject>(partes, opcoes);

    final objectUrl =
        urlApi.callMethod<JSString?>('createObjectURL'.toJS, blob);
    if (objectUrl == null) return false;

    final anchor = doc.callMethod<JSObject?>('createElement'.toJS, 'a'.toJS);
    if (anchor == null) return false;

    anchor.setProperty('href'.toJS, objectUrl);
    anchor.setProperty('download'.toJS, nomeArquivo.toJS);
    anchor.setProperty('rel'.toJS, 'noopener'.toJS);

    final body = doc.getProperty<JSObject?>('body'.toJS);
    body?.callMethod<JSAny?>('appendChild'.toJS, anchor);
    anchor.callMethod<JSAny?>('click'.toJS);
    body?.callMethod<JSAny?>('removeChild'.toJS, anchor);

    Timer(const Duration(seconds: 3), () {
      try {
        urlApi.callMethod<JSAny?>('revokeObjectURL'.toJS, objectUrl);
      } catch (_) {}
    });
    return true;
  } catch (_) {
    return false;
  }
}
