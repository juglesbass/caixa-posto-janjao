import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import 'operadores_sync_service.dart';

/// Serviço de Autenticação, Gestão de PIN e Assinatura Digital do Posto Janjão
class AuthService {
  static const String _pinGerentePadrao = '9999';

  /// Normaliza o nome do operador para chave única no armazenamento
  static String normalizarOperador(String operador) {
    return operador.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  }

  /// Chave legada, que guardava o PIN em texto plano (mantida só para migração)
  static String _chavePinOperador(String operador) {
    return 'pin_operador_${normalizarOperador(operador)}';
  }

  /// Chave oficial: guarda apenas o hash SHA-256 do PIN do operador
  static String _chaveHashOperador(String operador) {
    return 'pin_operador_${normalizarOperador(operador)}_hash';
  }

  /// Migra um PIN legado em texto plano para hash e apaga o texto plano
  static Future<void> _migrarPinLegado(SharedPreferences prefs, String operador, String pinPlano) async {
    await prefs.setString(_chaveHashOperador(operador), gerarHashPin(pinPlano));
    await prefs.remove(_chavePinOperador(operador));
  }

  /// Verifica se o operador já possui PIN individual de 4 dígitos cadastrado
  static Future<bool> operadorTemPin(String operador) async {
    if (operador.trim().isEmpty) return false;

    // 1. Verifica no cache de Operadores sincronizados via Firestore
    try {
      final db = DatabaseService.instance;
      final op = await db.obterOperadorCachePorNome(operador);
      if (op != null && op.pinHash.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    // 2. Verifica o hash local do próprio operador
    final prefs = await SharedPreferences.getInstance();
    final hashLocal = prefs.getString(_chaveHashOperador(operador));
    if (hashLocal != null && hashLocal.trim().isNotEmpty) {
      return true;
    }

    // 3. PIN legado em texto plano deste operador: migra para hash na hora
    final pinPlano = prefs.getString(_chavePinOperador(operador));
    if (pinPlano != null && pinPlano.trim().length == 4) {
      await _migrarPinLegado(prefs, operador, pinPlano.trim());
      return true;
    }

    // Não existe mais fallback para 'pin_acesso' global: ele fazia o PIN do
    // último operador cadastrado valer para qualquer outro operador.
    return false;
  }

  /// Obtém o hash SHA-256 do PIN do operador (o PIN em si nunca é armazenado)
  static Future<String?> obterHashPin(String operador) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_chaveHashOperador(operador));
  }

  /// Cadastra ou altera o PIN individual do operador
  static Future<bool> cadastrarOuAlterarPin(String operador, String novoPin) async {
    final limpo = novoPin.trim();
    if (limpo.length != 4 || int.tryParse(limpo) == null) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveHashOperador(operador), gerarHashPin(limpo));
    // Remove qualquer resquício do PIN em texto plano deste operador
    await prefs.remove(_chavePinOperador(operador));
    return true;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DERIVAÇÃO DE PIN (PBKDF2-HMAC-SHA256 com sal aleatório)
  //
  // O hash de PIN viaja até o Firestore e fica legível para quem tiver acesso à
  // coleção. Com SHA-256 puro, um PIN de 4 dígitos caía em milissegundos e um
  // único passe quebrava todos os operadores de uma vez. O sal por operador
  // elimina o ataque em lote e as rainbow tables; as iterações encarecem cada
  // tentativa. O número de iterações é moderado de propósito: o PIN é validado
  // na abertura e no fechamento de turno, inclusive no PWA (dart2js, celular
  // simples), e travar o caixa por segundos seria pior que o ganho marginal
  // sobre um espaço de apenas 10.000 combinações.
  // ──────────────────────────────────────────────────────────────────────────

  static const String _prefixoPbkdf2 = 'pbkdf2_sha256';
  static const int _iteracoesPbkdf2 = 25000;
  static final Random _random = Random.secure();

  /// Gera o hash SHA-256 simples de um PIN (formato legado, mantido para
  /// validar credenciais criadas antes da migração para PBKDF2)
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin.trim());
    return sha256.convert(bytes).toString();
  }

  /// Gera o hash moderno de um PIN no formato
  /// `pbkdf2_sha256:<iteracoes>:<sal_hex>:<derivado_hex>`
  static String gerarHashPin(String pin) {
    final sal = List<int>.generate(16, (_) => _random.nextInt(256));
    final derivado = _pbkdf2(utf8.encode(pin.trim()), sal, _iteracoesPbkdf2, 32);
    return [
      _prefixoPbkdf2,
      '$_iteracoesPbkdf2',
      _paraHex(sal),
      _paraHex(derivado),
    ].join(':');
  }

  /// Confere um PIN contra um hash armazenado, aceitando o formato moderno e o legado
  static bool verificarPin(String pin, String? hashArmazenado) {
    if (hashArmazenado == null || hashArmazenado.trim().isEmpty) return false;
    final limpo = pin.trim();
    final armazenado = hashArmazenado.trim();

    if (armazenado.startsWith('$_prefixoPbkdf2:')) {
      final partes = armazenado.split(':');
      if (partes.length != 4) return false;
      final iteracoes = int.tryParse(partes[1]);
      final sal = _deHex(partes[2]);
      if (iteracoes == null || iteracoes <= 0 || sal.isEmpty) return false;
      final derivado = _pbkdf2(utf8.encode(limpo), sal, iteracoes, 32);
      return _comparacaoSegura(_paraHex(derivado), partes[3]);
    }

    return _comparacaoSegura(hashPin(limpo), armazenado);
  }

  /// Indica que o hash está no formato antigo e merece ser regravado
  static bool hashEhLegado(String? hashArmazenado) {
    if (hashArmazenado == null || hashArmazenado.trim().isEmpty) return false;
    return !hashArmazenado.trim().startsWith('$_prefixoPbkdf2:');
  }

  /// Comparação em tempo constante, para não vazar o hash por timing
  static bool _comparacaoSegura(String a, String b) {
    if (a.length != b.length) return false;
    var diferenca = 0;
    for (var i = 0; i < a.length; i++) {
      diferenca |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diferenca == 0;
  }

  static String _paraHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _deHex(String hex) {
    if (hex.length.isOdd) return const [];
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      final b = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (b == null) return const [];
      bytes.add(b);
    }
    return bytes;
  }

  /// PBKDF2-HMAC-SHA256 (RFC 2898)
  static List<int> _pbkdf2(List<int> senha, List<int> sal, int iteracoes, int tamanho) {
    final hmac = Hmac(sha256, senha);
    const hLen = 32;
    final blocos = (tamanho / hLen).ceil();
    final saida = <int>[];

    for (var i = 1; i <= blocos; i++) {
      var u = hmac.convert([
        ...sal,
        (i >> 24) & 0xff,
        (i >> 16) & 0xff,
        (i >> 8) & 0xff,
        i & 0xff,
      ]).bytes;
      final t = List<int>.from(u);
      for (var j = 1; j < iteracoes; j++) {
        u = hmac.convert(u).bytes;
        for (var k = 0; k < hLen; k++) {
          t[k] ^= u[k];
        }
      }
      saida.addAll(t);
    }
    return saida.sublist(0, tamanho);
  }

  /// Valida se o PIN informado pertence à Gerência (PIN Mestre Criptografado com SHA-256)
  static Future<bool> validarPinGerente(String pinDigitado) async {
    final digitado = pinDigitado.trim();
    if (digitado.length != 4 || int.tryParse(digitado) == null) return false;

    final prefs = await SharedPreferences.getInstance();

    // Obtém o hash salvo do PIN Mestre
    String? hashSalvo = prefs.getString('pin_gerente_hash');
    if (hashSalvo == null) {
      // Migração automática caso existisse em texto plano legado
      final pinLegado = prefs.getString('pin_gerente');
      if (pinLegado != null && pinLegado.trim().length == 4) {
        hashSalvo = gerarHashPin(pinLegado.trim());
      } else {
        // Padrão inicial de fábrica: '9999'
        hashSalvo = gerarHashPin(_pinGerentePadrao);
      }
      await prefs.setString('pin_gerente_hash', hashSalvo);
      await prefs.remove('pin_gerente');
    }

    if (!verificarPin(digitado, hashSalvo)) return false;

    // Acertou: aproveita para reescrever hashes antigos no formato forte
    if (hashEhLegado(hashSalvo)) {
      await prefs.setString('pin_gerente_hash', gerarHashPin(digitado));
    }
    return true;
  }

  /// Informa se o PIN Mestre ainda é o padrão de fábrica ('9999'), para que a
  /// tela da Gerência possa cobrar a troca
  static Future<bool> pinGerenteEhPadrao() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hashSalvo = prefs.getString('pin_gerente_hash');
      if (hashSalvo == null) return true;
      return verificarPin(_pinGerentePadrao, hashSalvo);
    } catch (_) {
      return false;
    }
  }

  /// Altera com segurança o PIN Mestre da Gerência armazenando apenas seu hash SHA-256
  static Future<bool> alterarPinGerente(String novoPin) async {
    final limpo = novoPin.trim();
    if (limpo.length != 4 || int.tryParse(limpo) == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final novoHash = gerarHashPin(limpo);
    await prefs.setString('pin_gerente_hash', novoHash);
    await prefs.remove('pin_gerente'); // Remove qualquer rastro de texto plano
    return true;
  }

  /// Valida o PIN digitado contra o PIN do operador ativo ou contra o PIN Mestre da Gerência
  static Future<bool> validarPin(String operador, String pinDigitado) async {
    final digitado = pinDigitado.trim();
    if (digitado.length != 4) return false;

    // 1. O PIN Mestre da Gerência é soberano e valida qualquer operação (fallback de emergência)
    if (await validarPinGerente(digitado)) {
      return true;
    }

    // 2. Valida contra o hash SHA-256 no cache de operadores sincronizados via Firestore
    try {
      final validoSync = await OperadoresSyncService.validarPin(operador, digitado);
      if (validoSync) {
        return true;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();

    // 3. Hash local do próprio operador
    final hashSalvo = prefs.getString(_chaveHashOperador(operador));
    if (verificarPin(digitado, hashSalvo)) {
      if (hashEhLegado(hashSalvo)) {
        await prefs.setString(_chaveHashOperador(operador), gerarHashPin(digitado));
      }
      return true;
    }

    // 4. PIN legado em texto plano deste operador: valida e migra para hash
    final pinPlano = prefs.getString(_chavePinOperador(operador));
    if (pinPlano != null && pinPlano.trim() == digitado) {
      await _migrarPinLegado(prefs, operador, digitado);
      return true;
    }

    // O antigo fallback em 'pin_acesso' foi removido de propósito: ele aceitava
    // o PIN de um operador para autenticar qualquer outro.
    return false;
  }

  /// Retorna a lista de nomes de operadores que possuem PIN configurado no sistema
  static Future<List<String>> obterOperadoresComPin() async {
    final Set<String> operadores = {};

    // 1. Carrega do cache de operadores sincronizados via Firestore
    try {
      final db = DatabaseService.instance;
      final lista = await db.obterOperadoresCache();
      for (final o in lista) {
        if (o.nome.trim().isNotEmpty && o.ativo) {
          operadores.add(o.nomeExibicao);
        }
      }
    } catch (_) {}

    // 2. Fallback para chaves locais legadas
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final k in keys) {
      if (!k.startsWith('pin_operador_')) continue;
      final rawNome = k
          .replaceFirst('pin_operador_', '')
          .replaceFirst(RegExp(r'_hash$'), '');
      final nomeBonito = rawNome.replaceAll('_', ' ').toUpperCase();
      if (nomeBonito.isNotEmpty) {
        operadores.add(nomeBonito);
      }
    }
    return operadores.toList()..sort();
  }

  /// Permite à gerência redefinir o PIN de um operador
  static Future<bool> redefinirPinOperador(String operador, String novoPin) async {
    return cadastrarOuAlterarPin(operador, novoPin);
  }

  /// Permite à gerência excluir o PIN de um operador para que ele recadastre
  static Future<void> excluirPinOperador(String operador) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chavePinOperador(operador));
    await prefs.remove(_chaveHashOperador(operador));
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
