import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço de Autenticação, Gestão de PIN e Assinatura Digital do Posto Janjão
class AuthService {
  static const String _pinGerentePadrao = '9999';

  /// Normaliza o nome do operador para chave única no armazenamento
  static String normalizarOperador(String operador) {
    return operador.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  }

  static String _chavePinOperador(String operador) {
    return 'pin_operador_${normalizarOperador(operador)}';
  }

  /// Verifica se o operador já possui PIN individual de 4 dígitos cadastrado
  static Future<bool> operadorTemPin(String operador) async {
    if (operador.trim().isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final chave = _chavePinOperador(operador);
    final pin = prefs.getString(chave);
    if (pin != null && pin.trim().length == 4) {
      return true;
    }
    // Fallback legado: se operador for o mesmo e houver pin_acesso global
    final pinLegado = prefs.getString('pin_acesso');
    if (pinLegado != null && pinLegado.trim().length == 4) {
      // Migra automaticamente para o operador
      await prefs.setString(chave, pinLegado.trim());
      return true;
    }
    return false;
  }

  /// Obtém o PIN do operador
  static Future<String?> obterPin(String operador) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_chavePinOperador(operador));
  }

  /// Cadastra ou altera o PIN individual do operador
  static Future<bool> cadastrarOuAlterarPin(String operador, String novoPin) async {
    final limpo = novoPin.trim();
    if (limpo.length != 4 || int.tryParse(limpo) == null) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final chave = _chavePinOperador(operador);
    await prefs.setString(chave, limpo);
    // Atualiza compatibilidade legado
    await prefs.setString('pin_acesso', limpo);
    return true;
  }

  /// Valida o PIN digitado contra o PIN do operador ativo ou contra o PIN do Gerente
  static Future<bool> validarPin(String operador, String pinDigitado) async {
    final digitado = pinDigitado.trim();
    if (digitado.length != 4) return false;

    final prefs = await SharedPreferences.getInstance();

    // 1. Verifica PIN Mestre da Gerência
    final pinGerente = prefs.getString('pin_gerente') ?? _pinGerentePadrao;
    if (digitado == pinGerente) {
      return true;
    }

    // 2. Verifica PIN individual do Operador
    final pinSalvo = prefs.getString(_chavePinOperador(operador));
    if (pinSalvo != null && pinSalvo.trim() == digitado) {
      return true;
    }

    // 3. Fallback legado
    final pinLegado = prefs.getString('pin_acesso');
    if (pinLegado != null && pinLegado.trim() == digitado) {
      return true;
    }

    return false;
  }

  /// Valida se o PIN informado pertence ao Gerente
  static Future<bool> validarPinGerente(String pinDigitado) async {
    final prefs = await SharedPreferences.getInstance();
    final pinGerente = prefs.getString('pin_gerente') ?? _pinGerentePadrao;
    return pinDigitado.trim() == pinGerente;
  }

  /// Altera o PIN do Gerente
  static Future<bool> alterarPinGerente(String novoPin) async {
    final limpo = novoPin.trim();
    if (limpo.length != 4 || int.tryParse(limpo) == null) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pin_gerente', limpo);
    return true;
  }

  /// Gera a chave de autenticação digital SHA-256 no formato AUTH-XXXX-XXXX-XXXX
  /// Fórmula: operador|turnoId|totalVendas|timestamp
  static String gerarChaveAutenticacao({
    required String operador,
    required int turnoId,
    required double totalVendas,
    required String timestamp,
  }) {
    final vendasStr = totalVendas.toStringAsFixed(2);
    final textoBase = '$operador|$turnoId|$vendasStr|$timestamp';

    try {
      final bytes = utf8.encode(textoBase);
      final digest = sha256.convert(bytes);
      final hex = digest.toString().toUpperCase();

      final bloco1 = hex.substring(0, 4);
      final bloco2 = hex.substring(4, 8);
      final bloco3 = hex.substring(8, 12);
      return 'AUTH-$bloco1-$bloco2-$bloco3';
    } catch (e) {
      debugPrint('Erro ao gerar SHA-256 via crypto: $e');
      final hashSimples = textoBase.hashCode.abs().toRadixString(16).padLeft(12, '0').toUpperCase();
      return 'AUTH-${hashSimples.substring(0, 4)}-${hashSimples.substring(4, 8)}-${hashSimples.substring(8, 12)}';
    }
  }
}
