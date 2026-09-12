import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Esconde o carregador do `index.html`.
///
/// Antes ele sumia no primeiro frame do Flutter, mas nesse instante o app ainda
/// estava abrindo o banco e desenhava uma rodinha própria — duas rodinhas
/// seguidas, que com a abertura rápida aparecem quase juntas e parecem erro.
/// Agora quem avisa é o app, quando já tem tela para mostrar.
///
/// Pode ser chamado quantas vezes quiser: o lado do HTML ignora repetição.
void sinalizarAppPronto() {
  try {
    final fn = globalContext.getProperty<JSFunction?>('__appPronto'.toJS);
    fn?.callAsFunction();
  } catch (_) {}
}
