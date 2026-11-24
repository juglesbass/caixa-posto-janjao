/// Download direto de arquivos em memória no navegador.
///
/// Usa `dart.library.js_interop` para compatibilidade tanto com `dart2js`
/// quanto com WebAssembly (`flutter build web --wasm`).
library;

export 'web_download_stub.dart'
    if (dart.library.js_interop) 'web_download_web.dart';
