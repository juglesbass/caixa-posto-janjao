import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// PBKDF2-HMAC-SHA256 via `crypto.subtle`, o motor de criptografia do navegador.
///
/// O resultado é byte a byte o mesmo da implementação em Dart: PBKDF2 é
/// determinístico (RFC 8018), então um hash gravado por um caminho confere pelo
/// outro, nos dois sentidos e entre plataformas. Nada no formato armazenado
/// muda — continua `pbkdf2_sha256:<iteracoes>:<sal>:<derivado>`.
///
/// O que muda é onde a conta roda. Em Dart compilado para JavaScript, as 4.000
/// iterações do PIN do operador custam centenas de milissegundos num iPhone mais
/// fraco, e um PIN errado paga ainda as 20.000 do PIN Mestre — mais de um
/// segundo de tela totalmente congelada, na mesma thread que desenha e recebe os
/// toques. Aqui a conta é feita em código nativo do navegador, fora do
/// interpretador, e o `await` devolve a thread para a interface enquanto isso.
///
/// Devolve `null` quando o caminho nativo não existe — sem contexto seguro
/// (HTTPS) o navegador não expõe `crypto.subtle` — e aí quem chama cai na
/// implementação em Dart, exatamente como antes.
Future<List<int>?> derivarPbkdf2Sha256({
  required List<int> senha,
  required List<int> sal,
  required int iteracoes,
  required int tamanho,
}) async {
  try {
    final crypto = globalContext.getProperty<JSObject?>('crypto'.toJS);
    if (crypto == null) return null;
    final subtle = crypto.getProperty<JSObject?>('subtle'.toJS);
    if (subtle == null) return null;

    final chave = await subtle.callMethodVarArgs<JSPromise<JSObject>>(
      'importKey'.toJS,
      <JSAny?>[
        'raw'.toJS,
        Uint8List.fromList(senha).toJS,
        'PBKDF2'.toJS,
        false.toJS,
        <JSString>['deriveBits'.toJS].toJS,
      ],
    ).toDart;

    final parametros = JSObject()
      ..setProperty('name'.toJS, 'PBKDF2'.toJS)
      ..setProperty('salt'.toJS, Uint8List.fromList(sal).toJS)
      ..setProperty('iterations'.toJS, iteracoes.toJS)
      ..setProperty('hash'.toJS, 'SHA-256'.toJS);

    final bits = await subtle.callMethodVarArgs<JSPromise<JSArrayBuffer>>(
      'deriveBits'.toJS,
      <JSAny?>[parametros, chave, (tamanho * 8).toJS],
    ).toDart;

    return bits.toDart.asUint8List();
  } catch (_) {
    // Navegador sem suporte, chave recusada, contexto inseguro: qualquer falha
    // aqui é tratada como "não disponível", nunca como PIN inválido.
    return null;
  }
}
