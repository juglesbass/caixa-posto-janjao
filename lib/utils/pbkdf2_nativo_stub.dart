/// Fora do Web não há WebCrypto. Devolver `null` faz quem chama usar a
/// implementação em Dart, que no celular roda em isolate próprio do sistema e
/// nunca foi o gargalo.
Future<List<int>?> derivarPbkdf2Sha256({
  required List<int> senha,
  required List<int> sal,
  required int iteracoes,
  required int tamanho,
}) async =>
    null;
