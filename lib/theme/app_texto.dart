/// Escala de texto do app.
///
/// A maquete (Caixa Janjão v2) fala em três tamanhos — 11 / 13 / 25 — mas
/// desenha as telas numa moldura de celular de uns 320px. Num aparelho de
/// verdade, com uns 390px, os mesmos números ficariam menores do que a maquete
/// mostra: foi assim que rótulos de 9px entraram no app. Convertidos para o
/// tamanho real, os três viram 12 / 14 / 30.
///
/// Dois degraus a mais, de propósito:
/// - [valor], 16: o número que o frentista confere de relance numa linha
///   (últimos lançamentos, subtotais). É o que erra quando se erra — 380 no
///   lugar de 38 —, então tem que ser o maior da linha.
/// - [entrada], 24: o valor sendo digitado. Não sobe para 30 porque o campo
///   divide a largura com o botão Lançar, e "R$ 1.234,56" em 30 não cabe num
///   celular de 375px.
class AppTexto {
  AppTexto._();

  /// Rótulos em caixa alta, horários, selos.
  static const double rotulo = 12;

  /// Nomes, formas de pagamento, botões.
  static const double corpo = 14;

  /// Valores em linha e subtotais.
  static const double valor = 16;

  /// O valor sendo digitado no campo de venda.
  static const double entrada = 24;

  /// O total do turno.
  static const double total = 30;
}
