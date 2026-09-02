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

  /// Gera o hash SHA-256 de um PIN
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin.trim());
    return sha256.convert(bytes).toString();
  }

  /// Valida se o PIN informado pertence à Gerência (PIN Mestre Criptografado com SHA-256)
  static Future<bool> validarPinGerente(String pinDigitado) async {
    final digitado = pinDigitado.trim();
    if (digitado.length != 4 || int.tryParse(digitado) == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final hashDigitado = hashPin(digitado);

    // Obtém o hash salvo do PIN Mestre
    String? hashSalvo = prefs.getString('pin_gerente_hash');
    if (hashSalvo == null) {
      // Migração automática caso existisse em texto plano legado
      final pinLegado = prefs.getString('pin_gerente');
      if (pinLegado != null && pinLegado.trim().length == 4) {
        hashSalvo = hashPin(pinLegado.trim());
        await prefs.setString('pin_gerente_hash', hashSalvo);
      } else {
        // Padrão inicial de fábrica: '9999'
        hashSalvo = hashPin(_pinGerentePadrao);
        await prefs.setString('pin_gerente_hash', hashSalvo);
      }
    }

    return hashDigitado == hashSalvo;
  }

  /// Altera com segurança o PIN Mestre da Gerência armazenando apenas seu hash SHA-256
  static Future<bool> alterarPinGerente(String novoPin) async {
    final limpo = novoPin.trim();
    if (limpo.length != 4 || int.tryParse(limpo) == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final novoHash = hashPin(limpo);
    await prefs.setString('pin_gerente_hash', novoHash);
    await prefs.remove('pin_gerente'); // Remove qualquer rastro de texto plano
    return true;
  }

  /// Valida o PIN digitado contra o PIN do operador ativo ou contra o PIN Mestre da Gerência
  static Future<bool> validarPin(String operador, String pinDigitado) async {
    final digitado = pinDigitado.trim();
    if (digitado.length != 4) return false;

    // 1. O PIN Mestre da Gerência é soberano e valida qualquer operação
    if (await validarPinGerente(digitado)) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();

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

  /// Retorna a lista de nomes de operadores que possuem PIN configurado no sistema
  static Future<List<String>> obterOperadoresComPin() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final List<String> operadores = [];

    for (final k in keys) {
      if (k.startsWith('pin_operador_')) {
        final rawNome = k.replaceFirst('pin_operador_', '');
        final nomeBonito = rawNome.replaceAll('_', ' ').toUpperCase();
        if (nomeBonito.isNotEmpty && !operadores.contains(nomeBonito)) {
          operadores.add(nomeBonito);
        }
      }
    }
    return operadores;
  }

  /// Permite à gerência redefinir o PIN de um operador
  static Future<bool> redefinirPinOperador(String operador, String novoPin) async {
    return cadastrarOuAlterarPin(operador, novoPin);
  }

  /// Permite à gerência excluir o PIN de um operador para que ele recadastre
  static Future<void> excluirPinOperador(String operador) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chavePinOperador(operador));
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
