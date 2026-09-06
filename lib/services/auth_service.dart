import 'dart:async';
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

  /// Cadastra ou altera o PIN individual do operador e sincroniza com o Firestore
  static Future<bool> cadastrarOuAlterarPin(String operador, String novoPin) async {
    final limpo = novoPin.trim();
    if (limpo.length != 4 || int.tryParse(limpo) == null) {
      return false;
    }
    final hash = gerarHashPin(limpo);
    await salvarHashLocal(operador, hash);

    // Sincroniza em tempo real com o Cloud Firestore e adiciona à fila offline se não houver rede
    unawaited(OperadoresSyncService.sincronizarCadastroOperador(
      nome: operador,
      pin: limpo,
      perfil: 'operador',
    ));

    return true;
  }

  /// Salva o hash do operador no SharedPreferences local
  static Future<void> salvarHashLocal(String operador, String hash) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveHashOperador(operador), hash);
    await prefs.remove(_chavePinOperador(operador));
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
  // 600 iterações no Web (PWA) e 1.200 no nativo: executa em <15ms sem travar a UI thread,
  // mantendo a proteção criptográfica do sal aleatório por PIN contra ataques em lote
  static const int _iteracoesPbkdf2Web = 600;
  static const int _iteracoesPbkdf2Nativo = 1200;
  static int get _iteracoesPbkdf2 => kIsWeb ? _iteracoesPbkdf2Web : _iteracoesPbkdf2Nativo;
  static final Random _random = Random.secure();

  // Cache em memória de validação de PIN (chave: '$pin|$hash' -> bool)
  // Elimina completamente recomputação de PBKDF2 repetida, respondendo em 0ms
  static final Map<String, bool> _cacheVerificacao = {};

  // Cache em memória do status do PIN Mestre para resposta instantânea ao abrir o painel
  static bool? _cachePinGerenteEhPadrao;

  /// Limpa o cache de verificação (ex: ao alterar PIN)
  static void limparCache() {
    _cacheVerificacao.clear();
    _cachePinGerenteEhPadrao = null;
  }

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
    final iteracoes = _iteracoesPbkdf2;
    final derivado = _pbkdf2(utf8.encode(pin.trim()), sal, iteracoes, 32);
    final hashGerado = [
      _prefixoPbkdf2,
      '$iteracoes',
      _paraHex(sal),
      _paraHex(derivado),
    ].join(':');

    // Popula o cache imediatamente para este par pin/hash
    _cacheVerificacao['${pin.trim()}|$hashGerado'] = true;
    return hashGerado;
  }

  /// Confere um PIN contra um hash armazenado, aceitando o formato moderno e o legado
  static bool verificarPin(String pin, String? hashArmazenado) {
    if (hashArmazenado == null || hashArmazenado.trim().isEmpty) return false;
    final limpo = pin.trim();
    final armazenado = hashArmazenado.trim();

    // Cache hit: resposta instantânea (0ms)
    final cacheKey = '$limpo|$armazenado';
    if (_cacheVerificacao.containsKey(cacheKey)) {
      return _cacheVerificacao[cacheKey]!;
    }

    bool resultado = false;
    if (armazenado.startsWith('$_prefixoPbkdf2:')) {
      final partes = armazenado.split(':');
      if (partes.length == 4) {
        final iteracoes = int.tryParse(partes[1]);
        final sal = _deHex(partes[2]);
        if (iteracoes != null && iteracoes > 0 && sal.isNotEmpty) {
          final derivado = _pbkdf2(utf8.encode(limpo), sal, iteracoes, 32);
          resultado = _comparacaoSegura(_paraHex(derivado), partes[3]);
        }
      }
    } else {
      resultado = _comparacaoSegura(hashPin(limpo), armazenado);
    }

    // Mantém o cache limitado a 300 itens para não acumular memória
    if (_cacheVerificacao.length > 300) {
      _cacheVerificacao.clear();
    }
    _cacheVerificacao[cacheKey] = resultado;
    return resultado;
  }

  /// Indica que o hash está no formato antigo ou com iterações pesadas e merece ser regravado
  static bool hashEhLegado(String? hashArmazenado) {
    if (hashArmazenado == null || hashArmazenado.trim().isEmpty) return false;
    final armazenado = hashArmazenado.trim();
    if (!armazenado.startsWith('$_prefixoPbkdf2:')) return true;
    final partes = armazenado.split(':');
    if (partes.length == 4) {
      final iteracoes = int.tryParse(partes[1]) ?? 0;
      // Hashes com mais de 2000 iterações foram criados na versão anterior e travam o PWA;
      // devem ser re-gravados no novo formato leve
      if (iteracoes > 2000) return true;
    }
    return false;
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

  /// Valida se o PIN informado pertence à Gerência (PIN Mestre Criptografado com PBKDF2/SHA-256)
  static Future<bool> validarPinGerente(String pinDigitado) async {
    final digitado = pinDigitado.trim();
    if (digitado.length != 4 || int.tryParse(digitado) == null) return false;

    // Fast-path imediato (0ms): se o PIN ainda é o de fábrica e o usuário digitou '9999'
    if (_cachePinGerenteEhPadrao == true && digitado == _pinGerentePadrao) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final personalizado = prefs.getBool('pin_gerente_personalizado') ?? false;

    if (!personalizado && digitado == _pinGerentePadrao) {
      _cachePinGerenteEhPadrao = true;
      return true;
    }

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

    // Acertou: reescreve hashes antigos ou pesados (>2000 iterações) no novo formato veloz
    if (hashEhLegado(hashSalvo)) {
      await prefs.setString('pin_gerente_hash', gerarHashPin(digitado));
    }
    return true;
  }

  /// Informa se o PIN Mestre ainda é o padrão de fábrica ('9999'), para que a
  /// tela da Gerência possa cobrar a troca
  static Future<bool> pinGerenteEhPadrao() async {
    if (_cachePinGerenteEhPadrao != null) {
      return _cachePinGerenteEhPadrao!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('pin_gerente_personalizado') == true) {
        _cachePinGerenteEhPadrao = false;
        return false;
      }
      final hashSalvo = prefs.getString('pin_gerente_hash');
      if (hashSalvo == null) {
        _cachePinGerenteEhPadrao = true;
        return true;
      }
      final ehPadrao = verificarPin(_pinGerentePadrao, hashSalvo);
      _cachePinGerenteEhPadrao = ehPadrao;
      return ehPadrao;
    } catch (_) {
      return false;
    }
  }

  /// Altera com segurança o PIN Mestre da Gerência armazenando apenas seu hash PBKDF2 veloz
  static Future<bool> alterarPinGerente(String novoPin) async {
    final limpo = novoPin.trim();
    if (limpo.length != 4 || int.tryParse(limpo) == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final novoHash = gerarHashPin(limpo);
    await prefs.setString('pin_gerente_hash', novoHash);
    await prefs.setBool('pin_gerente_personalizado', limpo != _pinGerentePadrao);
    await prefs.remove('pin_gerente'); // Remove qualquer rastro de texto plano
    _cachePinGerenteEhPadrao = (limpo == _pinGerentePadrao);
    _cacheVerificacao.clear();
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
      // Sincroniza em segundo plano com o Cloud Firestore para garantir presença na nuvem
      unawaited(OperadoresSyncService.sincronizarCadastroOperador(
        nome: operador,
        pin: digitado,
        perfil: 'operador',
      ));
      return true;
    }

    // 4. PIN legado em texto plano deste operador: valida e migra para hash
    final pinPlano = prefs.getString(_chavePinOperador(operador));
    if (pinPlano != null && pinPlano.trim() == digitado) {
      await _migrarPinLegado(prefs, operador, digitado);
      unawaited(OperadoresSyncService.sincronizarCadastroOperador(
        nome: operador,
        pin: digitado,
        perfil: 'operador',
      ));
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
