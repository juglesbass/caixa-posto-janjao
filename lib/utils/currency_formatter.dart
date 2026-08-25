import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  /// Formata um double para moeda brasileira (ex: 1250.50 -> "R$ 1.250,50")
  static String formatar(double valor) {
    return _formatter.format(valor).trim();
  }

  /// Converte qualquer string contendo números para double em centavos (ex: "R$ 47,75" -> 47.75)
  static double parse(String valorStr) {
    if (valorStr.isEmpty) return 0.0;
    final digitos = valorStr.replaceAll(RegExp(r'\D'), '');
    if (digitos.isEmpty) return 0.0;
    final cents = int.tryParse(digitos) ?? 0;
    return cents / 100.0;
  }
}

/// Formatter em tempo real para campos de texto monetários
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final double valor = (int.tryParse(digitos) ?? 0) / 100.0;
    final String formatted = CurrencyFormatter.formatar(valor);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
