import 'package:flutter/material.dart';

import '../utils/payment_types.dart';

/// O ícone de cada forma de pagamento — o mesmo na grade, no placar e nos
/// últimos lançamentos.
///
/// Ícone no lugar do ponto de cor: o frentista reconhece a forma pela
/// silhueta, sem ler, e isso resiste a sol forte, tela suja e a quem confunde
/// cores — situações em que um ponto de 10px some.
class AppIcones {
  AppIcones._();

  static const IconData dinheiro = Icons.payments_rounded;
  static const IconData pix = Icons.pix_rounded;
  static const IconData cartao = Icons.credit_card_rounded;
  static const IconData requisicao = Icons.receipt_long_rounded;
  static const IconData deposito = Icons.account_balance_rounded;
  static const IconData despesas = Icons.money_off_rounded;

  /// Só aparece em turno antigo: a sangria saiu do app, o tipo ficou.
  static const IconData sangria = Icons.call_made_rounded;
  static const IconData suprimento = Icons.call_received_rounded;

  /// Ícone de um lançamento pelo tipo gravado. Qualquer bandeira de cartão,
  /// de qualquer máquina, usa o mesmo cartão: quem diz a bandeira é a cor
  /// ([AppColors.getCorTipo]) e o nome escrito ao lado.
  static IconData doTipo(String tipo) {
    if (PaymentTypes.ehDinheiro(tipo)) return dinheiro;
    if (PaymentTypes.ehPix(tipo)) return pix;
    if (PaymentTypes.ehCartao(tipo)) return cartao;
    if (PaymentTypes.ehRequisicao(tipo)) return requisicao;
    if (PaymentTypes.ehDeposito(tipo)) return deposito;
    if (PaymentTypes.ehDespesa(tipo)) return despesas;
    if (PaymentTypes.ehSangria(tipo)) return sangria;
    if (PaymentTypes.ehSuprimento(tipo)) return suprimento;
    return Icons.attach_money_rounded;
  }
}
