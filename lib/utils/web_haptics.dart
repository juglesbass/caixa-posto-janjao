/// Vibração no Web. O guard é `dart.library.js_interop` (e não mais
/// `dart.library.js`) porque é ele que também vale na compilação para
/// WebAssembly — `dart:js` não existe lá.
export 'web_haptics_stub.dart'
    if (dart.library.js_interop) 'web_haptics_web.dart';
