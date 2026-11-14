import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Grava [bytes] na pasta de documentos do app e retorna o caminho.
Future<String?> salvarBytesDocumento({
  required Uint8List bytes,
  required String nomeArquivo,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$nomeArquivo');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// Grava [conteudo] UTF-8 em arquivo temporário para compartilhamento.
Future<String?> salvarTextoTemporario({
  required String conteudo,
  required String nomeArquivo,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$nomeArquivo');
  await file.writeAsString(conteudo, encoding: utf8);
  return file.path;
}
