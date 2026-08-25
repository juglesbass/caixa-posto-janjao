import 'package:flutter/material.dart';

/// Cores e constantes de design do sistema Caixa Posto Janjão.
class AppColors {
  // Cores de Destaque
  static const Color accent = Color(0xFF2563EB); // Azul Cobalto Elétrico
  static const Color accentDark = Color(0xFF1D4ED8);
  static const Color accentLight = Color(0xFF38BDF8); // Sky Blue / Ciano Claro
  static const Color lime = Color(0xFF84CC16);

  // Cores Semânticas por Tipo de Pagamento
  static const Color green = Color(0xFF10B981); // Dinheiro / Sucesso
  static const Color blue = Color(0xFF06B6D4); // Pix
  static const Color purple = Color(0xFF8B5CF6); // Cartões / Vouchers
  static const Color orange = Color(0xFFF97316); // Sangrias / Master Débito
  static const Color brown = Color(0xFFB45309); // Depósito Global
  static const Color teal = Color(0xFF14B8A6); // Sodexo / Fitcard
  static const Color red = Color(0xFFEF4444); // Despesas / Falta / Alertas
  static const Color indigo = Color(0xFF6366F1); // Visa Crédito
  static const Color indigo2 = Color(0xFF818CF8); // Visa Débito
  static const Color amber = Color(0xFFF59E0B); // Requisição / Elo Crédito / Sobra
  static const Color amber2 = Color(0xFFFBBF24); // Elo Débito

  // Cores de Máquinas
  static const Color rede = Color(0xFFEF4444); // Vermelho Rede
  static const Color cielo = Color(0xFF0284C7); // Azul Cielo

  // Raios de Curvatura (Bento Grid)
  static const double radiusXl = 24.0;
  static const double radiusLg = 18.0;
  static const double radiusMd = 14.0;
  static const double radiusSm = 10.0;
  static const double radiusXs = 6.0;

  // Tema Escuro (Obsidian)
  static const Color darkBg = Color(0xFF08090F);
  static const Color darkSurface = Color(0xFF111420);
  static const Color darkSurfaceSubtle = Color(0xFF181D2E);
  static const Color darkSurfaceElevated = Color(0xFF20273D);
  static const Color darkBorder = Color(0x1AFFFFFF); // 10% branco
  static const Color darkBorderStrong = Color(0x5938BDF8); // 35% Sky Blue
  static const Color darkTextPri = Color(0xFFF8FAFC);
  static const Color darkTextSec = Color(0xFF94A3B8);
  static const Color darkTextTer = Color(0xFF64748B);
  static const Color darkSheetBg = Color(0xFF0D101A);

  // Tema Claro (Clean iOS)
  static const Color lightBg = Color(0xFFF4F6FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSubtle = Color(0xFFF1F5F9);
  static const Color lightSurfaceElevated = Color(0xFFE2E8F0);
  static const Color lightBorder = Color(0x14000000); // 8% preto
  static const Color lightBorderStrong = Color(0x402563EB); // 25% Azul
  static const Color lightTextPri = Color(0xFF0F172A);
  static const Color lightTextSec = Color(0xFF475569);
  static const Color lightTextTer = Color(0xFF94A3B8);
  static const Color lightSheetBg = Color(0xFFFFFFFF);

  /// Retorna a cor associada a um tipo de pagamento
  static Color getCorTipo(String tipo) {
    if (tipo.startsWith('Rede ')) {
      final bandeira = tipo.substring(5);
      return _coresPorTipo[bandeira] ?? rede;
    }
    if (tipo.startsWith('Cielo ')) {
      final bandeira = tipo.substring(6);
      return _coresPorTipo[bandeira] ?? cielo;
    }
    return _coresPorTipo[tipo] ?? accent;
  }

  /// Retorna o ícone associado a um tipo de pagamento
  static IconData getIconeTipo(String tipo) {
    var limpo = tipo;
    if (tipo.startsWith('Rede ')) {
      limpo = tipo.substring(5);
    } else if (tipo.startsWith('Cielo ')) {
      limpo = tipo.substring(6);
    }
    return _iconesPorTipo[limpo] ?? Icons.credit_card_rounded;
  }

  static const Map<String, Color> _coresPorTipo = {
    'Dinheiro': green,
    'Pix': blue,
    'Pag Pix': blue,
    'Requisição': amber,
    'Sodexo': teal,
    'Depósito': brown,
    'Depósito Global': brown,
    'Despesas': red,
    'Sangria': orange,
    'Suprimento': green,
    'Fitcard': teal,
    'Excard': indigo,
    'Amex': blue,
    'Eucard': purple,
    'Avancard': indigo2,
    'Master Crédito': red,
    'Master Débito': orange,
    'Visa Crédito': indigo,
    'Visa Débito': indigo2,
    'Elo Crédito': amber,
    'Elo Débito': amber2,
    'Alelo Multibenefícios': purple,
    'VR Multibenefícios': lime,
  };

  static const Map<String, IconData> _iconesPorTipo = {
    'Dinheiro': Icons.payments_rounded,
    'Pix': Icons.pix_rounded,
    'Pag Pix': Icons.pix_rounded,
    'Requisição': Icons.receipt_long_rounded,
    'Sodexo': Icons.lunch_dining_rounded,
    'Depósito': Icons.account_balance_rounded,
    'Depósito Global': Icons.account_balance_rounded,
    'Despesas': Icons.money_off_rounded,
    'Sangria': Icons.call_made_rounded,
    'Suprimento': Icons.call_received_rounded,
    'Fitcard': Icons.directions_car_rounded,
    'Excard': Icons.credit_card_rounded,
    'Amex': Icons.contactless_rounded,
    'Eucard': Icons.card_membership_rounded,
    'Avancard': Icons.credit_score_rounded,
    'Master Crédito': Icons.credit_card_rounded,
    'Master Débito': Icons.credit_card_rounded,
    'Visa Crédito': Icons.credit_card_rounded,
    'Visa Débito': Icons.credit_card_rounded,
    'Elo Crédito': Icons.credit_card_rounded,
    'Elo Débito': Icons.credit_card_rounded,
    'Alelo Multibenefícios': Icons.local_grocery_store_rounded,
    'VR Multibenefícios': Icons.card_membership_rounded,
  };
}
