import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/operador_model.dart';
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

    // 1. Verifica no cache de Operadores sincronizados via Firestore.
    //    O cadastro sincronizado é a fonte da verdade: se ele diz que o operador
    //    foi excluído ou desativado, não existe PIN válido para ele, por mais
    //    que sobre um hash antigo neste aparelho.
    try {
      final db = DatabaseService.instance;
      final op = await db.obterOperadorCachePorNome(operador);
      if (op != null) {
        if (op.removido || !op.ativo) {
          await _revogarCredenciaisLocais(operador);
          return false;
        }
        if (op.pinHash.isNotEmpty) {
          return true;
        }
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

    // Sincroniza em tempo real com o Cloud Firestore e adiciona à fila offline
    // se não houver rede. Sem `perfil`, o cadastro existente é preservado.
    unawaited(OperadoresSyncService.sincronizarCadastroOperador(
      nome: operador,
      pin: limpo,
    ));

    return true;
  }

  /// Salva o hash do operador no SharedPreferences local
  static Future<void> salvarHashLocal(String operador, String hash) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveHashOperador(operador), hash);
    await prefs.remove(_chavePinOperador(operador));
  }

  /// Apaga qualquer credencial local do operador neste aparelho.
  ///
  /// Chamado assim que a sincronização revela que ele foi excluído ou
  /// desativado. Sem isso o hash local sobrevivia e continuava autenticando —
  /// e pior, era reenviado ao Firestore, reativando quem a gerência tinha
  /// acabado de bloquear.
  static Future<void> _revogarCredenciaisLocais(String operador) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chaveHashOperador(operador));
      await prefs.remove(_chavePinOperador(operador));
    } catch (_) {}
  }

  /// Versão pública da revogação, usada pela sincronização de operadores.
  static Future<void> revogarCredenciaisLocais(String operador) =>
      _revogarCredenciaisLocais(operador);

  // ──────────────────────────────────────────────────────────────────────────
  // DERIVAÇÃO DE PIN (PBKDF2-HMAC-SHA256 com sal aleatório)
  //
  // O hash de PIN viaja até o Firestore e fica legível para quem tiver acesso à
  // coleção. Com SHA-256 puro, um PIN de 4 dígitos caía em milissegundos e um
  // único passe quebrava todos os operadores de uma vez. O sal por operador
  // elimina o ataque em lote e as rainbow tables; as iterações encarecem cada
  // tentativa. O número de iterações é um meio-termo deliberado: o PIN é
  // validado na abertura e no fechamento de turno, inclusive no PWA (dart2js,
  // celular simples), e travar o caixa por segundos seria pior que o ganho
  // marginal sobre um espaço de apenas 10.000 combinações.
  //
  // Nenhum número de iterações resolve o problema de fundo: enquanto a leitura
  // da coleção 'operadores' estiver aberta, o hash é público e 10.000
  // combinações caem com tempo de máquina. O fechamento real é Firebase App
  // Check ou validar o PIN numa Cloud Function (ver firestore.rules).
  // ──────────────────────────────────────────────────────────────────────────

  static const String _prefixoPbkdf2 = 'pbkdf2_sha256';

  // PIN de operador: validado na abertura e no fechamento de turno, às vezes
  // várias vezes seguidas. O custo aqui é pago na thread de UI (no PWA não há
  // isolate), então o teto é o que roda em ~100ms num celular simples.
  static const int _iteracoesPbkdf2Web = 4000;
  static const int _iteracoesPbkdf2Nativo = 12000;
  static int get _iteracoesPbkdf2 => kIsWeb ? _iteracoesPbkdf2Web : _iteracoesPbkdf2Nativo;

  // PIN Mestre da gerência: digitado raras vezes e sempre atrás de um botão com
  // spinner, então aguenta um custo bem maior. Isso é o que separa "quebra em
  // segundos" de "quebra em horas" caso o hash vaze pela leitura aberta do
  // Firestore.
  static const int _iteracoesPbkdf2MestreWeb = 20000;
  static const int _iteracoesPbkdf2MestreNativo = 50000;
  static int get _iteracoesPbkdf2Mestre =>
      kIsWeb ? _iteracoesPbkdf2MestreWeb : _iteracoesPbkdf2MestreNativo;

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
  static String gerarHashPin(String pin, {int? iteracoes}) {
    final sal = List<int>.generate(16, (_) => _random.nextInt(256));
    final iteracoesUsadas = iteracoes ?? _iteracoesPbkdf2;
    final derivado = _pbkdf2(utf8.encode(pin.trim()), sal, iteracoesUsadas, 32);
    final hashGerado = [
      _prefixoPbkdf2,
      '$iteracoesUsadas',
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

  /// Indica que o hash está no formato antigo (SHA-256 puro) ou foi derivado com
  /// menos iterações do que a versão atual exige, e merece ser regravado no
  /// primeiro acesso correto.
  static bool hashEhLegado(String? hashArmazenado) {
    if (hashArmazenado == null || hashArmazenado.trim().isEmpty) return false;
    final armazenado = hashArmazenado.trim();
    if (!armazenado.startsWith('$_prefixoPbkdf2:')) return true;
    final partes = armazenado.split(':');
    if (partes.length == 4) {
      final iteracoes = int.tryParse(partes[1]) ?? 0;
      // Hashes derivados por uma versão antiga (600/1200 iterações) ou por uma
      // plataforma mais leve são reforçados de graça no próximo login correto.
      // O critério é "abaixo do alvo", nunca "acima": marcar hashes mais fortes
      // como legados faria o app enfraquecê-los sozinho a cada acesso.
      if (iteracoes < _iteracoesPbkdf2) return true;
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

  // Chaves do PIN Mestre. Ficam em SharedPreferences, mas quem manda é o
  // Firestore: OperadoresSyncService.sincronizarPinMestre() reescreve estas
  // chaves com o valor da nuvem. Sem isso, trocar o PIN Mestre num aparelho
  // deixava todos os outros (e qualquer navegador com os dados limpos) valendo
  // o padrão de fábrica para sempre.
  static const String keyPinGerenteHash = 'pin_gerente_hash';
  static const String keyPinGerentePersonalizado = 'pin_gerente_personalizado';

  /// Valida se o PIN informado pertence à Gerência (PIN Mestre PBKDF2-HMAC-SHA256)
  ///
  /// Atenção ao custo: [validarPin] chama este método **antes** de conferir o PIN
  /// do operador, ou seja, ele está no caminho de toda abertura e todo
  /// fechamento de turno. Enquanto o PIN Mestre for o de fábrica, a resposta sai
  /// por comparação direta, sem derivar hash nenhum — derivar as dezenas de
  /// milhares de iterações do PIN Mestre aqui congelaria a tela a cada PIN
  /// digitado no caixa.
  static Future<bool> validarPinGerente(String pinDigitado) async {
    final digitado = pinDigitado.trim();
    if (digitado.length != 4 || int.tryParse(digitado) == null) return false;

    // Fast-path imediato (0ms): PIN ainda de fábrica e o usuário digitou o padrão
    if (_cachePinGerenteEhPadrao == true) {
      return digitado == _pinGerentePadrao;
    }

    // Daqui para baixo vem a derivação cara (20.000 iterações no Web), e ela
    // roda na thread da interface. Sem esta pausa, o indicador de carregamento
    // que a tela acabou de ligar nunca chega a ser desenhado: a thread já está
    // ocupada quando o frame seria pintado, e o usuário vê travamento em vez de
    // espera. Dois frames bastam para o spinner aparecer.
    //
    // Fica aqui, e não em cada tela, porque o PIN Mestre é pedido em vários
    // lugares — gerência, override de fechamento, reabertura de turno.
    await Future<void>.delayed(const Duration(milliseconds: 32));

    final prefs = await SharedPreferences.getInstance();
    final personalizado = prefs.getBool(keyPinGerentePersonalizado);
    String? hashSalvo = prefs.getString(keyPinGerenteHash);
    final pinLegado = prefs.getString('pin_gerente')?.trim();

    // Aparelho legado: a flag ainda não existe. Resolve uma única vez qual é o
    // PIN Mestre, persiste a flag e segue pelo caminho barato daqui em diante.
    if (personalizado == null) {
      if (pinLegado != null && pinLegado.length == 4) {
        // Texto plano de uma versão antiga: converte em hash e apaga o rastro.
        final ehPadrao = pinLegado == _pinGerentePadrao;
        hashSalvo = gerarHashPin(pinLegado, iteracoes: _iteracoesPbkdf2Mestre);
        await prefs.setString(keyPinGerenteHash, hashSalvo);
        await prefs.setBool(keyPinGerentePersonalizado, !ehPadrao);
        await prefs.remove('pin_gerente');
        _cachePinGerenteEhPadrao = ehPadrao;
        return digitado == pinLegado;
      }

      if (hashSalvo == null) {
        // Instalação nova: PIN Mestre é o de fábrica, nada a derivar.
        await prefs.setBool(keyPinGerentePersonalizado, false);
        _cachePinGerenteEhPadrao = true;
        return digitado == _pinGerentePadrao;
      }

      // Existe hash mas não se sabe se é o de fábrica: descobre uma vez só.
      final ehPadrao = verificarPin(_pinGerentePadrao, hashSalvo);
      await prefs.setBool(keyPinGerentePersonalizado, !ehPadrao);
      _cachePinGerenteEhPadrao = ehPadrao;
      if (ehPadrao) {
        return digitado == _pinGerentePadrao;
      }
      // cai para a verificação por hash abaixo
    }

    // PIN Mestre ainda é o de fábrica: comparação direta, custo zero.
    if (personalizado == false) {
      _cachePinGerenteEhPadrao = true;
      return digitado == _pinGerentePadrao;
    }

    if (hashSalvo == null) {
      // Estado inconsistente (flag diz personalizado, mas o hash sumiu). Nega em
      // vez de aceitar o PIN de fábrica, que seria abrir a gerência de graça.
      return false;
    }

    if (!verificarPin(digitado, hashSalvo)) return false;

    // Acertou: reforça hashes derivados por versões antigas, com poucas iterações
    if (_hashMestreEhFraco(hashSalvo)) {
      await prefs.setString(
        keyPinGerenteHash,
        gerarHashPin(digitado, iteracoes: _iteracoesPbkdf2Mestre),
      );
    }
    return true;
  }

  /// O PIN Mestre tem alvo próprio de iterações, bem acima do PIN de operador
  static bool _hashMestreEhFraco(String? hashArmazenado) {
    if (hashArmazenado == null || hashArmazenado.trim().isEmpty) return false;
    final armazenado = hashArmazenado.trim();
    if (!armazenado.startsWith('$_prefixoPbkdf2:')) return true;
    final partes = armazenado.split(':');
    if (partes.length != 4) return true;
    final iteracoes = int.tryParse(partes[1]) ?? 0;
    return iteracoes < _iteracoesPbkdf2Mestre;
  }

  /// Informa se o PIN Mestre ainda é o padrão de fábrica, para que a tela da
  /// Gerência possa cobrar a troca.
  ///
  /// Responde pela flag persistida em vez de derivar o hash: o painel da
  /// gerência chama isto ao abrir, e rodar PBKDF2 do PIN Mestre aqui travaria a
  /// tela por meio segundo no PWA. A flag só é calculada por hash uma única vez,
  /// em aparelhos vindos de uma versão que ainda não a gravava.
  static Future<bool> pinGerenteEhPadrao() async {
    if (_cachePinGerenteEhPadrao != null) {
      return _cachePinGerenteEhPadrao!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final flag = prefs.getBool(keyPinGerentePersonalizado);
      if (flag != null) {
        _cachePinGerenteEhPadrao = !flag;
        return !flag;
      }

      final hashSalvo = prefs.getString(keyPinGerenteHash);
      if (hashSalvo == null) {
        _cachePinGerenteEhPadrao = true;
        return true;
      }

      // Aparelho legado sem a flag: calcula uma vez e persiste o resultado.
      final ehPadrao = verificarPin(_pinGerentePadrao, hashSalvo);
      await prefs.setBool(keyPinGerentePersonalizado, !ehPadrao);
      _cachePinGerenteEhPadrao = ehPadrao;
      return ehPadrao;
    } catch (_) {
      return false;
    }
  }

  /// Altera o PIN Mestre da Gerência e propaga a mudança para os outros aparelhos
  static Future<bool> alterarPinGerente(String novoPin) async {
    final limpo = novoPin.trim();
    if (limpo.length != 4 || int.tryParse(limpo) == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final novoHash = gerarHashPin(limpo, iteracoes: _iteracoesPbkdf2Mestre);
    final personalizado = limpo != _pinGerentePadrao;

    await prefs.setString(keyPinGerenteHash, novoHash);
    await prefs.setBool(keyPinGerentePersonalizado, personalizado);
    await prefs.remove('pin_gerente'); // Remove qualquer rastro de texto plano
    _cachePinGerenteEhPadrao = !personalizado;
    _cacheVerificacao.clear();

    // Publica na nuvem para que o PIN novo valha em todos os aparelhos e
    // sobreviva a uma reinstalação ou à limpeza dos dados do site no PWA.
    unawaited(OperadoresSyncService.sincronizarPinMestre(
      hash: novoHash,
      personalizado: personalizado,
    ));

    return true;
  }

  /// Aplica localmente o PIN Mestre que veio da nuvem.
  /// Chamado só pela sincronização — nunca por tela.
  static Future<void> aplicarPinMestreDaNuvem({
    required String hash,
    required bool personalizado,
  }) async {
    if (hash.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(keyPinGerenteHash) == hash &&
          (prefs.getBool(keyPinGerentePersonalizado) ?? false) == personalizado) {
        return;
      }
      await prefs.setString(keyPinGerenteHash, hash);
      await prefs.setBool(keyPinGerentePersonalizado, personalizado);
      await prefs.remove('pin_gerente');
      _cachePinGerenteEhPadrao = !personalizado;
      _cacheVerificacao.clear();
    } catch (_) {}
  }

  /// Valida o PIN digitado contra o PIN do operador ativo ou contra o PIN Mestre da Gerência
  static Future<bool> validarPin(String operador, String pinDigitado) async {
    final digitado = pinDigitado.trim();
    if (digitado.length != 4) return false;

    // O PIN Mestre continua valendo para qualquer operação, mas é conferido por
    // ÚLTIMO, não por primeiro.
    //
    // Ele usa uma contagem de iterações bem maior que a do operador (20.000
    // contra 4.000 no Web). Testá-lo antes fazia todo login pagar as duas
    // contas, na thread da interface: no Safari do iPhone isso travava a tela
    // por mais de um segundo, e o próprio indicador de carregamento não chegava
    // a ser desenhado. Agora o caminho comum — o operador digitando o próprio
    // PIN — paga só a conta barata.

    // 1. Estado oficial do operador no cadastro sincronizado.
    //
    //    Este passo é a trava: se o cadastro existe e diz que o operador foi
    //    excluído ou desativado, a validação termina aqui, negando. Antes, a
    //    checagem apenas "não aprovava" e a execução seguia para o hash local
    //    do passo 3 — que aprovava o acesso de quem a gerência tinha acabado de
    //    bloquear e ainda reenviava o cadastro à nuvem, reativando o operador.
    OperadorModel? cadastro;
    try {
      cadastro = await DatabaseService.instance.obterOperadorCachePorNome(operador);
    } catch (_) {}

    if (cadastro != null && (cadastro.removido || !cadastro.ativo)) {
      // A gerência continua conseguindo agir sobre um operador removido — por
      // exemplo, reabrir um turno antigo dele. O PIN do próprio removido segue
      // negado. Aqui o custo alto do PIN Mestre não incomoda: é caminho raro.
      if (await validarPinGerente(digitado)) return true;
      await _revogarCredenciaisLocais(operador);
      return false;
    }

    if (cadastro != null &&
        cadastro.pinHash.isNotEmpty &&
        verificarPin(digitado, cadastro.pinHash)) {
      // Reforça o hash da nuvem se ele veio de uma versão mais fraca
      if (hashEhLegado(cadastro.pinHash)) {
        unawaited(OperadoresSyncService.redefinirPin(
          operadorId: cadastro.id,
          novoPin: digitado,
        ));
      } else {
        await salvarHashLocal(operador, cadastro.pinHash);
      }
      return true;
    }

    final prefs = await SharedPreferences.getInstance();

    // 2. Hash local. Chega aqui quem não está no cadastro da nuvem (aparelho que
    //    nunca sincronizou, ou operador anterior ao Firestore) e também quem
    //    trocou o PIN neste aparelho e a gravação na nuvem ainda está na fila
    //    offline — nesse caso o hash local é o mais novo dos dois, e recusar
    //    aqui trancaria o operador para fora do próprio caixa.
    //
    //    Operador excluído ou desativado nunca alcança este ponto: o passo 1
    //    encerra antes.
    final hashSalvo = prefs.getString(_chaveHashOperador(operador));
    if (verificarPin(digitado, hashSalvo)) {
      if (hashEhLegado(hashSalvo)) {
        await prefs.setString(_chaveHashOperador(operador), gerarHashPin(digitado));
      }
      // Sincroniza em segundo plano com o Cloud Firestore para garantir presença
      // na nuvem. O perfil vem do cadastro existente: fixar 'operador' aqui
      // rebaixava um gerente a cada login dele.
      unawaited(OperadoresSyncService.sincronizarCadastroOperador(
        nome: operador,
        pin: digitado,
        perfil: cadastro?.perfil,
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
        perfil: cadastro?.perfil,
      ));
      return true;
    }

    // Por último, o PIN Mestre da Gerência, que valida qualquer operação.
    // Ficar no fim é o que mantém o login comum rápido: só quem errou o próprio
    // PIN, ou é de fato a gerência, paga as 20.000 iterações.
    if (await validarPinGerente(digitado)) {
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
    final Set<String> bloqueados = {};
    try {
      final db = DatabaseService.instance;
      final lista = await db.obterOperadoresCache(incluirRemovidos: true);
      for (final o in lista) {
        if (o.nome.trim().isEmpty) continue;
        if (o.removido || !o.ativo) {
          bloqueados.add(normalizarOperador(o.nome));
          continue;
        }
        operadores.add(o.nomeExibicao);
      }
    } catch (_) {}

    // 2. Fallback para chaves locais legadas, pulando quem o cadastro da nuvem
    //    já marcou como excluído ou desativado — senão o operador bloqueado
    //    reaparecia na lista de seleção por causa de um hash local antigo.
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final k in keys) {
      if (!k.startsWith('pin_operador_')) continue;
      final rawNome = k
          .replaceFirst('pin_operador_', '')
          .replaceFirst(RegExp(r'_hash$'), '');
      if (rawNome.isEmpty || bloqueados.contains(rawNome)) continue;
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
