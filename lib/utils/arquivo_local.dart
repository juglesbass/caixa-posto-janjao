/// Leitura/gravação de arquivos locais fora do Web (Android/iOS/Desktop).
///
/// Usa `dart.library.io` para evitar importar `dart:io` em serviços comuns,
/// permitindo compilar o app para WebAssembly (`flutter build web --wasm`).
library;

export 'arquivo_local_stub.dart'
    if (dart.library.io) 'arquivo_local_io.dart';
