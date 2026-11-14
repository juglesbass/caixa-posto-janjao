import 'dart:typed_data';

/// Grava [bytes] na pasta de documentos do app. No Web retorna null.
Future<String?> salvarBytesDocumento({
  required Uint8List bytes,
  required String nomeArquivo,
}) async =>
    null;

/// Grava [conteudo] UTF-8 em arquivo temporário. No Web retorna null.
Future<String?> salvarTextoTemporario({
  required String conteudo,
  required String nomeArquivo,
}) async =>
    null;
