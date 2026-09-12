import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/operador_model.dart';
import 'auth_service.dart';
import 'database_service.dart';

/// Estado de conectividade da sincronização do Firestore
class SyncStatus {
  final bool online;
  final String mensagem;
  final String? detalheErro;
  final int? statusCode;
  final DateTime? ultimaSincronizacao;

  const SyncStatus({
    required this.online,
    required this.mensagem,
    this.detalheErro,
    this.statusCode,
    this.ultimaSincronizacao,
  });
}

/// Serviço centralizado de sincronização de Operadores e PINs via Cloud Firestore
/// Arquitetura: Offline-First com suporte multiplataforma total (Android APK, Web PWA, iOS IPA)
class OperadoresSyncService {
  static final http.Client _client = http.Client();

  /// ID do Projeto Firebase padrão
  static const String defaultProjectId = 'caixa-posto-janjao';
  static const String _keyProjectId = 'firebase_firestore_project_id';
  static const String _keyCacheOperadoresJson = 'operadores_cache_json';
  static const String _keyMigracaoConcluida = 'operadores_migracao_inicial_concluida';
  static const String _keyPinMestreSyncEm = 'pin_gerente_sync_em';

  /// Variáveis estáticas de diagnóstico para inspeção na interface
  static String? ultimoErroDiagnostico;
  static int? ultimoStatusCode;
  static String? urlUltimaTentativa;

  /// Notificador reativo de status para a interface
  static final ValueNotifier<SyncStatus> statusNotifier = ValueNotifier<SyncStatus>(
    const SyncStatus(online: false, mensagem: 'Não sincronizado'),
  );

  /// Notificador reativo da lista de operadores para telas que exigem tempo real
  static final ValueNotifier<List<OperadorModel>> operadoresNotifier =
      ValueNotifier<List<OperadorModel>>([]);

  /// Timer de sincronização reativa periódica da tela de gestão
  static Timer? _pollingTimer;
  static int _activeListenersCount = 0;
  static bool _pollingEmExecucao = false;
  /// Sincronização de background em andamento, compartilhada entre os
  /// chamadores simultâneos. Nulo quando não há nenhuma em voo.
  static Future<void>? _syncEmVoo;
  static bool _migracaoExecutada = false;

  /// Intervalo base do polling. O timer dispara nesse ritmo, mas cada ciclo
  /// respeita o backoff acumulado — em rede ruim ele espaça sozinho em vez de
  /// martelar o Firestore de 4 em 4 segundos gastando bateria e franquia.
  static const Duration _intervaloPollingBase = Duration(seconds: 5);
  static const Duration _backoffMaximo = Duration(minutes: 2);
  static int _falhasConsecutivas = 0;
  static DateTime? _proximoCicloPermitido;

  /// Só sincroniza com o app em primeiro plano. Um app minimizado que continua
  /// varrendo a rede é a maior fonte de consumo silencioso de bateria no celular
  /// do frentista.
  static bool _appEmPrimeiroPlano = true;

  /// Informado pelo shell do app ao mudar o ciclo de vida (resumed/paused)
  static void definirAppEmPrimeiroPlano(bool emPrimeiroPlano) {
    _appEmPrimeiroPlano = emPrimeiroPlano;
    if (emPrimeiroPlano) {
      // Voltou para a tela: zera o backoff e sincroniza na hora, se alguma tela
      // estiver observando.
      _falhasConsecutivas = 0;
      _proximoCicloPermitido = null;
      if (_activeListenersCount > 0) {
        unawaited(_executarCicloPolling());
      }
    }
  }

  /// Inicia monitoramento em tempo real da coleção 'operadores' do Firestore
  static void iniciarMonitoramentoEmTempoReal() {
    _activeListenersCount++;
    if (_pollingTimer != null && _pollingTimer!.isActive) return;

    // Carrega o cache inicial no notifier se estiver vazio
    if (operadoresNotifier.value.isEmpty) {
      obterOperadores(sincronizarNuvem: false).then((locais) {
        if (operadoresNotifier.value.isEmpty && locais.isNotEmpty) {
          operadoresNotifier.value = locais;
        }
      });
    }

    // Executa uma sincronização imediata
    _proximoCicloPermitido = null;
    unawaited(_executarCicloPolling());

    _pollingTimer = Timer.periodic(_intervaloPollingBase, (_) {
      unawaited(_executarCicloPolling());
    });
  }

  /// Para o monitoramento em tempo real quando nenhuma tela estiver visualizando
  static void pararMonitoramentoEmTempoReal() {
    _activeListenersCount = (_activeListenersCount - 1).clamp(0, 999);
    if (_activeListenersCount == 0) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
      _falhasConsecutivas = 0;
      _proximoCicloPermitido = null;
    }
  }

  static Duration _backoffAtual() {
    if (_falhasConsecutivas <= 0) return Duration.zero;
    // O expoente é limitado porque no Web os inteiros são doubles: deslocar
    // além de ~32 bits produz lixo em vez de um número grande.
    final expoente = (_falhasConsecutivas - 1).clamp(0, 8);
    final segundos = _intervaloPollingBase.inSeconds * (1 << expoente);
    final calculado = Duration(seconds: segundos);
    return calculado > _backoffMaximo ? _backoffMaximo : calculado;
  }

  static Future<void> _executarCicloPolling() async {
    if (_pollingEmExecucao) return;
    if (!_appEmPrimeiroPlano) return;

    final espera = _proximoCicloPermitido;
    if (espera != null && DateTime.now().isBefore(espera)) return;

    _pollingEmExecucao = true;
    try {
      // 1. Tenta descarregar pendências offline acumuladas
      await sincronizarFilaOffline();

      // 2. Migra cadastros locais anteriores deste dispositivo para a nuvem
      if (!_migracaoExecutada) {
        _migracaoExecutada = true;
        await migrarOperadoresLocaisParaFirestore();
      }

      // 3. Busca lista fresca do Firestore
      final operadoresNuvem = await _buscarDoFirestore();
      await _aplicarListaDaNuvem(operadoresNuvem);

      // 4. Traz o PIN Mestre da gerência definido em outro aparelho
      await sincronizarPinMestreDaNuvem();

      _falhasConsecutivas = 0;
      _proximoCicloPermitido = null;

      statusNotifier.value = SyncStatus(
        online: true,
        mensagem: 'Sincronizado com Firestore',
        statusCode: 200,
        ultimaSincronizacao: DateTime.now(),
      );
    } catch (e) {
      // Se falhar a conexão, preserva dados locais e espaça a próxima tentativa
      _falhasConsecutivas++;
      _proximoCicloPermitido = DateTime.now().add(_backoffAtual());

      final db = DatabaseService.instance;
      final locais = await db.obterOperadoresCache();
      if (operadoresNotifier.value.isEmpty && locais.isNotEmpty) {
        operadoresNotifier.value = locais;
      }
    } finally {
      _pollingEmExecucao = false;
    }
  }

  /// Aplica no aparelho a lista que veio da nuvem.
  ///
  /// A lista da nuvem é a verdade completa, então o cache local passa a
  /// espelhá-la: quem não veio foi excluído de fato e precisa sair daqui, senão
  /// é reenviado ao Firestore na próxima migração e ressuscita sozinho.
  /// Operadores marcados como removidos continuam no cache (para que a
  /// autenticação saiba negar), mas ficam fora das listas visíveis.
  static Future<void> _aplicarListaDaNuvem(List<OperadorModel> daNuvem) async {
    final db = DatabaseService.instance;

    // Lista vazia não apaga o cache. Uma coleção realmente vazia só acontece em
    // projeto novo — mas um ID de projeto errado também devolve vazio (HTTP 404),
    // e nesse caso zerar o cache deixaria o caixa sem conseguir autenticar
    // ninguém offline. Na dúvida, preserva o que já está no aparelho.
    await db.salvarOperadoresCache(daNuvem, substituirTudo: daNuvem.isNotEmpty);

    if (daNuvem.isEmpty) return;

    final visiveis = daNuvem.where((o) => !o.removido).toList();
    await _salvarCachePrefs(visiveis);
    await _sincronizarChavesLocais(daNuvem);

    operadoresNotifier.value = visiveis;
  }

  /// Obtém o ID do projeto Firebase configurado
  static Future<String> getProjectId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyProjectId) ?? defaultProjectId;
    } catch (_) {
      return defaultProjectId;
    }
  }

  /// Permite configurar o ID do projeto Firebase
  static Future<void> setProjectId(String novoProjectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyProjectId, novoProjectId.trim());
      debugPrint('[Firestore Sync] Projeto alterado para: ${novoProjectId.trim()}');
    } catch (_) {}
  }

  /// URL base da coleção 'operadores' na API REST do Cloud Firestore
  static Future<String> _getUrlColecao() async {
    final projectId = await getProjectId();
    return 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/operadores';
  }

  /// URL de um documento específico de operador
  static Future<String> _getUrlDocumento(String docId) async {
    final baseUrl = await _getUrlColecao();
    return '$baseUrl/$docId';
  }

  /// URL do documento de configuração da gerência (hash do PIN Mestre)
  static Future<String> _getUrlConfigGerencia() async {
    final projectId = await getProjectId();
    return 'https://firestore.googleapis.com/v1/projects/$projectId'
        '/databases/(default)/documents/configuracoes/gerencia';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CONSULTA E SINCRONIZAÇÃO (OFFLINE-FIRST)
  // ──────────────────────────────────────────────────────────────────────────

  /// Obtém os operadores cadastrados com estratégia Offline-First:
  /// Retorna imediatamente o cache local e tenta sincronizar em background ou sob demanda.
  static Future<List<OperadorModel>> obterOperadores({bool sincronizarNuvem = true}) async {
    final db = DatabaseService.instance;

    // 1. Tenta carregar do cache SQLite
    List<OperadorModel> operadoresLocais = await db.obterOperadoresCache();

    // 2. Fallback secundário em SharedPreferences caso SQLite esteja vazio
    if (operadoresLocais.isEmpty) {
      operadoresLocais = await _carregarCachePrefs();
    }

    // Alimenta o notifier caso esteja vazio
    if (operadoresLocais.isNotEmpty && operadoresNotifier.value.isEmpty) {
      operadoresNotifier.value = operadoresLocais;
    }

    // 3. Se solicitado, sincroniza com o Firestore em background
    if (sincronizarNuvem) {
      unawaited(_sincronizarEmBackground());
    }

    return operadoresLocais;
  }

  /// Sincronização de background compartilhada.
  ///
  /// Vários pontos do app chamam [obterOperadores] logo na abertura (a carga
  /// inicial em main.dart e a tela de identificação, por exemplo). Sem esta
  /// trava, cada chamada disparava por conta própria uma varredura completa
  /// da coleção, uma descarga da fila offline e uma gravação do mesmo
  /// resultado no cache — tudo em paralelo e idêntico. Enquanto uma
  /// sincronização está em voo, as demais aguardam o mesmo Future.
  ///
  /// A trava para aqui de propósito. Cada sincronização mantém a própria
  /// leitura do Firestore, feita depois da própria descarga da fila: como
  /// [_aplicarListaDaNuvem] substitui o cache inteiro, aplicar uma leitura
  /// iniciada antes dessa descarga apagaria do aparelho um operador
  /// recém-enviado. Pelo mesmo motivo a migração de cadastros antigos
  /// continua com leitura própria — ela só pula quem já existe na nuvem, e
  /// essa proteção depende de o retrato ser fresco.
  static Future<void> _sincronizarEmBackground() {
    final emVoo = _syncEmVoo;
    if (emVoo != null) return emVoo;

    final nova = _executarSincronizacaoEmBackground()
        .whenComplete(() => _syncEmVoo = null);
    _syncEmVoo = nova;
    return nova;
  }

  static Future<void> _executarSincronizacaoEmBackground() async {
    try {
      // Esvazia fila offline
      await sincronizarFilaOffline();

      final operadoresNuvem = await _buscarDoFirestore();
      await _aplicarListaDaNuvem(operadoresNuvem);
      await sincronizarPinMestreDaNuvem();

      statusNotifier.value = SyncStatus(
        online: true,
        mensagem: 'Sincronizado com Firestore',
        statusCode: 200,
        ultimaSincronizacao: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[Firestore Sync] ⚠️ Modo Offline ativo. Detalhe: $e');
      statusNotifier.value = SyncStatus(
        online: false,
        mensagem: 'Modo Offline (Cache Local)',
        detalheErro: ultimoErroDiagnostico ?? e.toString(),
        statusCode: ultimoStatusCode,
        ultimaSincronizacao: statusNotifier.value.ultimaSincronizacao,
      );
    }
  }

  /// Força a sincronização completa entre o dispositivo e o Firestore
  static Future<({bool sucesso, String mensagem, List<OperadorModel> operadores})> forcarSincronizacao() async {
    try {
      await sincronizarFilaOffline();

      final operadoresNuvem = await _buscarDoFirestore();
      await _aplicarListaDaNuvem(operadoresNuvem);
      await sincronizarPinMestreDaNuvem();

      _falhasConsecutivas = 0;
      _proximoCicloPermitido = null;

      final visiveis = operadoresNotifier.value;
      statusNotifier.value = SyncStatus(
        online: true,
        mensagem: 'Sincronizado com Nuvem',
        statusCode: 200,
        ultimaSincronizacao: DateTime.now(),
      );
      return (
        sucesso: true,
        mensagem: '✅ ${visiveis.length} operadores sincronizados via Firestore.',
        operadores: visiveis
      );
    } catch (e) {
      final locais = await DatabaseService.instance.obterOperadoresCache();
      if (operadoresNotifier.value.isEmpty && locais.isNotEmpty) {
        operadoresNotifier.value = locais;
      }
      statusNotifier.value = SyncStatus(
        online: false,
        mensagem: 'Modo Offline (Cache Local)',
        detalheErro: ultimoErroDiagnostico ?? e.toString(),
        statusCode: ultimoStatusCode,
        ultimaSincronizacao: statusNotifier.value.ultimaSincronizacao,
      );
      return (
        sucesso: false,
        mensagem: 'Nuvem indisponível (${ultimoStatusCode != null ? "HTTP $ultimoStatusCode" : "Sem conexão"}). Cache local ativo (${locais.length} operadores).',
        operadores: locais
      );
    }
  }

  /// Busca os operadores diretamente na API REST do Firestore
  static Future<List<OperadorModel>> _buscarDoFirestore() async {
    final url = await _getUrlColecao();
    urlUltimaTentativa = url;
    debugPrint('[Firestore Sync] Conectando à coleção "operadores" via REST...');

    final List<OperadorModel> lista = [];
    String? pageToken;
    http.Response response;
    var paginas = 0;

    do {
      final uri = Uri.parse(url).replace(queryParameters: {
        'pageSize': '300',
        if (pageToken != null) 'pageToken': pageToken,
      });

      response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 6));

      debugPrint('[Firestore Sync] Resposta HTTP: ${response.statusCode}');

      if (response.statusCode != 200) break;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final docs = data['documents'] as List<dynamic>? ?? [];
      for (final doc in docs) {
        if (doc is Map<String, dynamic>) {
          lista.add(OperadorModel.fromFirestoreRest(doc));
        }
      }
      pageToken = data['nextPageToken'] as String?;
      paginas++;
    } while (pageToken != null && pageToken.isNotEmpty && paginas < 20);

    if (response.statusCode == 200) {
      debugPrint('[Firestore Sync] ✅ Sucesso! ${lista.length} operadores encontrados na nuvem.');
      ultimoErroDiagnostico = null;
      ultimoStatusCode = 200;
      lista.sort((a, b) => a.nome.compareTo(b.nome));
      return lista;
    } else if (response.statusCode == 404) {
      debugPrint('[Firestore Sync] Coleção "operadores" ainda vazia no Firestore.');
      ultimoErroDiagnostico = null;
      ultimoStatusCode = 404;
      return [];
    } else {
      final erroBody = response.body;
      final erroMsg = 'HTTP ${response.statusCode}: $erroBody';
      ultimoErroDiagnostico = erroMsg;
      ultimoStatusCode = response.statusCode;
      debugPrint('[Firestore Sync] ❌ Erro retornado pelo Firestore: $erroMsg');
      throw Exception(erroMsg);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // OPERAÇÕES DE ESCRITA (ADICIONAR, REDEFINIR PIN, ATIVAR/DESATIVAR, EXCLUIR)
  // ──────────────────────────────────────────────────────────────────────────

  /// Sincroniza o cadastro ou alteração de PIN de um operador com o Firestore
  /// Chamado sempre que um operador digita ou redefine o PIN em qualquer dispositivo
  /// Grava (ou atualiza) o cadastro de um operador com o PIN informado.
  ///
  /// [perfil] nulo preserva o perfil já cadastrado — passar 'operador' às cegas
  /// aqui rebaixava um gerente toda vez que ele digitava o próprio PIN.
  /// [restaurar] traz de volta um operador que a gerência tinha excluído; sem
  /// ele, um cadastro removido continua removido.
  static Future<bool> sincronizarCadastroOperador({
    required String nome,
    required String pin,
    String? perfil,
    String? operadorId,
    bool restaurar = false,
  }) async {
    final nomeLimpo = nome.trim();
    final pinLimpo = pin.trim();

    if (nomeLimpo.isEmpty || pinLimpo.length != 4 || int.tryParse(pinLimpo) == null) {
      return false;
    }

    final pinHash = await AuthService.gerarHashPinAsync(pinLimpo);
    final docId = operadorId ?? 'op_${AuthService.normalizarOperador(nomeLimpo)}';

    final db = DatabaseService.instance;

    // Recupera o cadastro atual para não sobrescrever perfil, data de criação
    // nem o estado de exclusão com valores inventados na hora.
    OperadorModel? existente;
    try {
      final todos = await db.obterOperadoresCache(incluirRemovidos: true);
      for (final o in todos) {
        if (o.id == docId ||
            o.nomeNormalizado == AuthService.normalizarOperador(nomeLimpo)) {
          existente = o;
          break;
        }
      }
    } catch (_) {}

    // Operador excluído não recebe PIN novo por caminho automático. Só o
    // cadastro explícito da gerência (restaurar: true) o traz de volta — do
    // contrário, qualquer rotina de sincronização acabaria reabrindo a conta.
    if (!restaurar && (existente?.removido ?? false)) {
      debugPrint('[Firestore Sync] Cadastro de $nomeLimpo ignorado: operador excluído.');
      return false;
    }

    final operadorAtualizado = OperadorModel(
      id: docId,
      nome: nomeLimpo,
      pinHash: pinHash,
      perfil: perfil ?? existente?.perfil ?? 'operador',
      ativo: restaurar ? true : (existente?.ativo ?? true),
      removido: false,
      postoId: existente?.postoId ?? 'posto_janjao',
      criadoEm: existente?.criadoEm ?? DateTime.now(),
      atualizadoEm: DateTime.now(),
    );

    // 1. Salva imediatamente no cache local (Offline-First)
    await db.salvarOperadorCache(operadorAtualizado);
    await AuthService.salvarHashLocal(nomeLimpo, pinHash);

    // Atualiza imediatamente o notificador em memória
    final listaAtual = List<OperadorModel>.from(operadoresNotifier.value);
    final idx = listaAtual.indexWhere((o) => o.id == docId || o.nomeNormalizado == operadorAtualizado.nomeNormalizado);
    if (idx != -1) {
      listaAtual[idx] = operadorAtualizado;
    } else {
      listaAtual.add(operadorAtualizado);
    }
    listaAtual.sort((a, b) => a.nome.compareTo(b.nome));
    operadoresNotifier.value = listaAtual;

    // 2. Persiste diretamente no Firestore na nuvem
    bool enviadoComSucesso = false;
    try {
      final url = await _getUrlDocumento(docId);
      final response = await _client.patch(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(operadorAtualizado.toFirestoreRest()),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        enviadoComSucesso = true;
        await db.limparPendenciasDoOperador(docId);
        statusNotifier.value = SyncStatus(
          online: true,
          mensagem: 'Operador sincronizado no Firestore',
          statusCode: 200,
          ultimaSincronizacao: DateTime.now(),
        );
        debugPrint('[Firestore Sync] ✅ Operador $nomeLimpo salvo no Firestore.');
      } else {
        debugPrint('[Firestore Sync] ⚠️ Resposta ${response.statusCode} ao salvar operador no Firestore.');
      }
    } catch (e) {
      debugPrint('[Firestore Sync] ⚠️ Falha ao conectar ao Firestore: $e');
    }

    // 3. Fallback Offline: se não foi possível enviar pela rede, guarda na fila offline
    if (!enviadoComSucesso) {
      await db.salvarPendenciaOperador(
        operadorId: docId,
        acao: 'upsert',
        dados: operadorAtualizado.toMap(),
      );
      statusNotifier.value = SyncStatus(
        online: false,
        mensagem: 'Salvo localmente (pendente de nuvem)',
        ultimaSincronizacao: statusNotifier.value.ultimaSincronizacao,
      );
      debugPrint('[Firestore Sync] ℹ️ Operador $nomeLimpo enfileirado para sincronização posterior.');
    }

    return true;
  }

  /// Adiciona um novo operador com nome e PIN inicial de 4 dígitos
  static Future<bool> adicionarOperador({
    required String nome,
    required String pin,
    String perfil = 'operador',
  }) async {
    // Cadastro feito pela gerência: se existir um documento com esse nome que
    // tinha sido excluído, esta é a intenção explícita de trazê-lo de volta.
    return sincronizarCadastroOperador(
      nome: nome,
      pin: pin,
      perfil: perfil,
      restaurar: true,
    );
  }

  /// Redefine o PIN de 4 dígitos de um operador existente
  static Future<bool> redefinirPin({
    required String operadorId,
    required String novoPin,
  }) async {
    final pinLimpo = novoPin.trim();
    if (pinLimpo.length != 4 || int.tryParse(pinLimpo) == null) return false;

    final db = DatabaseService.instance;
    final operadores = await db.obterOperadoresCache();
    final index = operadores.indexWhere((o) => o.id == operadorId);
    if (index == -1) return false;

    final operadorExistente = operadores[index];
    final novoHash = await AuthService.gerarHashPinAsync(pinLimpo);
    final atualizado = operadorExistente.copyWith(
      pinHash: novoHash,
      atualizadoEm: DateTime.now(),
    );

    // Salva imediatamente no cache local
    await db.salvarOperadorCache(atualizado);
    await AuthService.salvarHashLocal(atualizado.nome, novoHash);

    // Atualiza o notifier reativo na tela do gerente imediatamente
    final lista = List<OperadorModel>.from(operadoresNotifier.value);
    final idxN = lista.indexWhere((o) => o.id == operadorId);
    if (idxN != -1) {
      lista[idxN] = atualizado;
      operadoresNotifier.value = lista;
    }

    // Tenta atualizar no Firestore
    bool enviado = false;
    try {
      final url = await _getUrlDocumento(operadorId);
      final response = await _client.patch(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(atualizado.toFirestoreRest()),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        enviado = true;
        await db.limparPendenciasDoOperador(operadorId);
        statusNotifier.value = SyncStatus(
          online: true,
          mensagem: 'PIN atualizado no Firestore',
          statusCode: 200,
          ultimaSincronizacao: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('[Firestore Sync] ⚠️ PIN atualizado apenas localmente (offline): $e');
    }

    if (!enviado) {
      await db.salvarPendenciaOperador(
        operadorId: operadorId,
        acao: 'upsert',
        dados: atualizado.toMap(),
      );
    }

    return true;
  }

  /// Ativa ou Desativa um operador
  static Future<bool> alternarStatusOperador({
    required String operadorId,
    required bool ativo,
  }) async {
    final db = DatabaseService.instance;
    final operadores = await db.obterOperadoresCache();
    final index = operadores.indexWhere((o) => o.id == operadorId);
    if (index == -1) return false;

    final operadorExistente = operadores[index];
    final atualizado = operadorExistente.copyWith(
      ativo: ativo,
      atualizadoEm: DateTime.now(),
    );

    // Salva imediatamente no cache local
    await db.salvarOperadorCache(atualizado);

    // Atualiza o notifier reativo na tela do gerente imediatamente
    final lista = List<OperadorModel>.from(operadoresNotifier.value);
    final idxN = lista.indexWhere((o) => o.id == operadorId);
    if (idxN != -1) {
      lista[idxN] = atualizado;
      operadoresNotifier.value = lista;
    }

    // Tenta atualizar no Firestore
    bool enviado = false;
    try {
      final url = await _getUrlDocumento(operadorId);
      final response = await _client.patch(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(atualizado.toFirestoreRest()),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        enviado = true;
        await db.limparPendenciasDoOperador(operadorId);
        statusNotifier.value = SyncStatus(
          online: true,
          mensagem: 'Status atualizado no Firestore',
          statusCode: 200,
          ultimaSincronizacao: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('[Firestore Sync] ⚠️ Status atualizado apenas localmente (offline): $e');
    }

    if (!enviado) {
      await db.salvarPendenciaOperador(
        operadorId: operadorId,
        acao: 'upsert',
        dados: atualizado.toMap(),
      );
    }

    return true;
  }

  /// Exclui o operador: some das listas e deixa de autenticar em todo aparelho.
  ///
  /// A exclusão é reversível (`removido: true`), não um DELETE. Apagar o
  /// documento exigiria manter a permissão de exclusão aberta no Firestore — e,
  /// sem autenticação, isso deixa qualquer um zerar a coleção inteira. O
  /// documento marcado também preserva o rastro de quem assinou fechamentos
  /// antigos.
  static Future<bool> excluirOperador({
    required String operadorId,
    required String nome,
  }) async {
    final db = DatabaseService.instance;

    OperadorModel? existente;
    try {
      final todos = await db.obterOperadoresCache(incluirRemovidos: true);
      for (final o in todos) {
        if (o.id == operadorId) {
          existente = o;
          break;
        }
      }
    } catch (_) {}

    final marcado = (existente ??
            OperadorModel(
              id: operadorId,
              nome: nome,
              pinHash: '',
              criadoEm: DateTime.now(),
              atualizadoEm: DateTime.now(),
            ))
        .copyWith(
      ativo: false,
      removido: true,
      atualizadoEm: DateTime.now(),
    );

    // Cache local mantém o registro marcado: é ele que faz a autenticação negar
    // o acesso mesmo offline, em vez de tratar o operador como desconhecido.
    await db.salvarOperadorCache(marcado);
    await AuthService.excluirPinOperador(nome);

    // Atualiza o notifier reativo na tela do gerente imediatamente
    final lista = List<OperadorModel>.from(operadoresNotifier.value)
      ..removeWhere((o) => o.id == operadorId || o.nomeNormalizado == AuthService.normalizarOperador(nome));
    operadoresNotifier.value = lista;

    bool enviado = false;
    try {
      final url = await _getUrlDocumento(operadorId);
      final response = await _client.patch(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(marcado.toFirestoreRest()),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        enviado = true;
        await db.limparPendenciasDoOperador(operadorId);
        statusNotifier.value = SyncStatus(
          online: true,
          mensagem: 'Operador removido do Firestore',
          statusCode: 200,
          ultimaSincronizacao: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('[Firestore Sync] ⚠️ Falha ao excluir operador da nuvem: $e');
    }

    if (!enviado) {
      await db.salvarPendenciaOperador(
        operadorId: operadorId,
        acao: 'upsert',
        dados: marcado.toMap(),
      );
    }

    return true;
  }

  /// Processa a fila de pendências acumuladas em modo offline e envia ao Firestore
  static Future<void> sincronizarFilaOffline() async {
    final db = DatabaseService.instance;
    final pendencias = await db.obterPendenciasOperadores();
    if (pendencias.isEmpty) return;

    debugPrint('[Firestore Sync] Processando ${pendencias.length} pendências offline de operadores...');

    for (final p in pendencias) {
      final pendenciaId = p['id'].toString();
      final operadorId = p['operador_id'].toString();
      final acao = p['acao'].toString();
      final dadosJson = p['dados_json'].toString();

      try {
        final url = await _getUrlDocumento(operadorId);
        if (acao == 'upsert') {
          final dadosMap = jsonDecode(dadosJson) as Map<String, dynamic>;
          final operador = OperadorModel.fromMap(dadosMap);
          final response = await _client.patch(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(operador.toFirestoreRest()),
          ).timeout(const Duration(seconds: 6));

          if (response.statusCode == 200) {
            await db.removerPendenciaOperador(pendenciaId);
            debugPrint('[Firestore Sync] ✅ Pendência $pendenciaId enviada com sucesso ao Firestore.');
          }
        } else if (acao == 'delete') {
          // Pendência criada por uma versão anterior, quando a exclusão era um
          // DELETE de verdade. As regras atuais recusam DELETE (403): nesse caso
          // o operador já está marcado como removido no cache e no próximo
          // upsert a nuvem recebe a marcação, então a pendência sai da fila em
          // vez de ficar girando para sempre.
          final response = await _client.delete(
            Uri.parse(url),
            headers: {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 6));

          if (response.statusCode == 200 ||
              response.statusCode == 404 ||
              response.statusCode == 403) {
            await db.removerPendenciaOperador(pendenciaId);
            debugPrint('[Firestore Sync] ✅ Exclusão pendente $pendenciaId encerrada (HTTP ${response.statusCode}).');
          }
        }
      } catch (e) {
        debugPrint('[Firestore Sync] Pendência $pendenciaId continua na fila (falha de rede): $e');
      }
    }
  }

  /// Migra, **uma única vez por instalação**, os operadores que já existiam
  /// neste dispositivo (SharedPreferences ou SQLite) para o Cloud Firestore.
  ///
  /// A execução repetida era o que ressuscitava operador excluído: a cada
  /// abertura do app, o aparelho reenviava à nuvem tudo que tinha no cache
  /// local, desfazendo exclusões e reativações feitas em outro aparelho.
  /// Agora ela roda só enquanto houver algo de fato pendente de migração, e
  /// nunca sobrescreve um cadastro que já existe na nuvem.
  static Future<int> migrarOperadoresLocaisParaFirestore({bool forcar = false}) async {
    int migrados = 0;
    try {
      final db = DatabaseService.instance;
      final prefs = await SharedPreferences.getInstance();

      if (!forcar && (prefs.getBool(_keyMigracaoConcluida) ?? false)) {
        return 0;
      }

      // Cadastros que já vivem na nuvem não são tocados: quem manda sobre eles
      // é o Firestore, não o cache deste aparelho.
      final Set<String> jaNaNuvem = {};
      try {
        for (final o in await _buscarDoFirestore()) {
          jaNaNuvem.add(o.id);
          jaNaNuvem.add(o.nomeNormalizado);
        }
      } catch (e) {
        // Sem rede não dá para saber o que já existe lá. Tentar assim mesmo
        // arriscaria sobrescrever a nuvem com dados velhos: adia a migração.
        debugPrint('[Firestore Sync] Migração adiada (nuvem indisponível): $e');
        return 0;
      }

      // 1. Mapeia nomes reais dos turnos para preservar a formatação bonita (ex: "Carlos Silva")
      final Map<String, String> nomesReais = {};
      try {
        final turnosDb = await db.database;
        final rows = await turnosDb.rawQuery(
          'SELECT DISTINCT operador FROM turnos WHERE operador IS NOT NULL AND TRIM(operador) != ""',
        );
        for (final r in rows) {
          final op = r['operador']?.toString().trim() ?? '';
          if (op.isNotEmpty) {
            nomesReais[AuthService.normalizarOperador(op)] = op;
          }
        }
      } catch (_) {}

      // 2. Coleta operadores do cache SQLite existente
      final locaisDb = await db.obterOperadoresCache();
      for (final op in locaisDb) {
        if (op.nome.trim().isNotEmpty) {
          nomesReais[op.nomeNormalizado] = op.nomeExibicao;
        }
      }

      // 3. Varre chaves de PIN existentes no SharedPreferences (cadastros anteriores)
      final Set<String> chavesOperadores = {};
      for (final k in prefs.getKeys()) {
        if (!k.startsWith('pin_operador_')) continue;
        final raw = k.replaceFirst('pin_operador_', '').replaceFirst(RegExp(r'_hash$'), '');
        if (raw.isNotEmpty) {
          chavesOperadores.add(raw);
        }
      }

      // 4. Para cada operador antigo encontrado, prepara o OperadorModel e envia ao Firestore
      for (final chave in chavesOperadores) {
        String? hash = prefs.getString('pin_operador_${chave}_hash');
        final pinPlano = prefs.getString('pin_operador_$chave');

        if ((hash == null || hash.isEmpty) && pinPlano != null && pinPlano.trim().length == 4) {
          hash = await AuthService.gerarHashPinAsync(pinPlano.trim());
          await prefs.setString('pin_operador_${chave}_hash', hash);
          await prefs.remove('pin_operador_$chave');
        }

        if (hash == null || hash.isEmpty) continue;
        if (jaNaNuvem.contains(chave) || jaNaNuvem.contains('op_$chave')) continue;

        // Recupera nome original ou formata
        String nomeFinal = nomesReais[chave] ?? chave.replaceAll('_', ' ');
        if (!nomeFinal.contains(' ') && nomeFinal.isNotEmpty) {
          nomeFinal = nomeFinal[0].toUpperCase() + nomeFinal.substring(1);
        } else {
          nomeFinal = nomeFinal
              .split(' ')
              .map((p) => p.isNotEmpty ? (p[0].toUpperCase() + p.substring(1).toLowerCase()) : '')
              .join(' ')
              .trim();
        }

        final docId = 'op_$chave';
        final opModel = OperadorModel(
          id: docId,
          nome: nomeFinal,
          pinHash: hash,
          perfil: 'operador',
          ativo: true,
          postoId: 'posto_janjao',
          criadoEm: DateTime.now(),
          atualizadoEm: DateTime.now(),
        );

        // Salva no SQLite local
        await db.salvarOperadorCache(opModel);

        // Envia ao Firestore
        try {
          final url = await _getUrlDocumento(docId);
          final res = await _client.patch(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(opModel.toFirestoreRest()),
          ).timeout(const Duration(seconds: 5));

          if (res.statusCode == 200) {
            migrados++;
          }
        } catch (_) {
          await db.salvarPendenciaOperador(
            operadorId: docId,
            acao: 'upsert',
            dados: opModel.toMap(),
          );
        }
      }

      // Envia apenas os operadores do SQLite que ainda não existem na nuvem.
      //
      // Antes, este trecho reenviava **todos** os operadores do cache local a
      // cada execução. Era um "last writer wins" com dado velho: bastava um
      // aparelho desatualizado abrir o app para reativar quem tinha acabado de
      // ser desativado, ou trazer de volta quem tinha sido excluído.
      for (final op in locaisDb) {
        if (op.removido) continue;
        if (jaNaNuvem.contains(op.id) || jaNaNuvem.contains(op.nomeNormalizado)) continue;
        try {
          final url = await _getUrlDocumento(op.id);
          final res = await _client.patch(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(op.toFirestoreRest()),
          ).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            migrados++;
            jaNaNuvem.add(op.id);
          }
        } catch (_) {}
      }

      // A migração é um evento único do aparelho. A partir daqui, quem sincroniza
      // é o fluxo normal (cadastro, redefinição de PIN e fila offline).
      await prefs.setBool(_keyMigracaoConcluida, true);

      if (migrados > 0) {
        debugPrint('[Firestore Sync] ✅ $migrados operadores anteriores sincronizados com a nuvem.');
      }
    } catch (e) {
      debugPrint('[Firestore Sync] Erro na migração de operadores anteriores: $e');
    }
    return migrados;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // VALIDAÇÃO DE PIN VIA CACHE SINCRONIZADO
  // ──────────────────────────────────────────────────────────────────────────

  /// Valida o PIN digitado contra o hash do operador ativo no cache
  static Future<bool> validarPin(String nomeOperador, String pinDigitado) async {
    final pinLimpo = pinDigitado.trim();
    if (pinLimpo.length != 4) return false;

    // 1. Fallback soberano do PIN Mestre da Gerência
    if (await AuthService.validarPinGerente(pinLimpo)) {
      return true;
    }

    final db = DatabaseService.instance;
    final op = await db.obterOperadorCachePorNome(nomeOperador);
    if (op != null) {
      if (op.removido) {
        debugPrint('Operador ${op.nome} foi excluído pela gerência.');
        return false;
      }
      if (!op.ativo) {
        debugPrint('Operador ${op.nome} está desativado.');
        return false;
      }
      // Aceita tanto o hash PBKDF2 com sal quanto o SHA-256 legado da nuvem
      if (await AuthService.verificarPinAsync(pinLimpo, op.pinHash)) {
        return true;
      }
    }

    return false;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PIN MESTRE DA GERÊNCIA
  //
  // O PIN Mestre vivia só no SharedPreferences de cada aparelho. Na prática isso
  // significava que trocá-lo num celular não valia em lugar nenhum: todo aparelho
  // novo, toda reinstalação e todo PWA com os dados do site limpos voltavam ao
  // PIN de fábrica — e o painel da gerência, com "Zerar Tudo" dentro, ficava
  // aberto para quem soubesse o padrão.
  // ──────────────────────────────────────────────────────────────────────────

  /// Publica o hash do PIN Mestre na nuvem para valer em todos os aparelhos
  static Future<bool> sincronizarPinMestre({
    required String hash,
    required bool personalizado,
  }) async {
    if (hash.trim().isEmpty) return false;
    try {
      final url = await _getUrlConfigGerencia();
      final response = await _client
          .patch(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fields': {
                'pin_mestre_hash': {'stringValue': hash},
                'personalizado': {'booleanValue': personalizado},
                'atualizado_em': {
                  'timestampValue': DateTime.now().toUtc().toIso8601String()
                },
              }
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyPinMestreSyncEm, DateTime.now().toIso8601String());
        } catch (_) {}
        debugPrint('[Firestore Sync] ✅ PIN Mestre publicado para todos os aparelhos.');
        return true;
      }

      debugPrint('[Firestore Sync] ⚠️ HTTP ${response.statusCode} ao publicar o PIN Mestre.');
    } catch (e) {
      debugPrint('[Firestore Sync] ⚠️ PIN Mestre alterado apenas neste aparelho: $e');
    }
    return false;
  }

  /// Traz o PIN Mestre definido em outro aparelho e aplica localmente.
  ///
  /// Falha em silêncio de propósito: sem rede, o aparelho continua validando
  /// pelo último PIN Mestre que recebeu, que é exatamente o comportamento
  /// offline-first esperado no caixa.
  static Future<void> sincronizarPinMestreDaNuvem() async {
    try {
      final url = await _getUrlConfigGerencia();
      final response = await _client
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));

      // 404 = a gerência ainda não trocou o PIN em aparelho nenhum
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final fields = data['fields'] as Map<String, dynamic>? ?? {};
      final hash = fields['pin_mestre_hash']?['stringValue']?.toString() ?? '';
      if (hash.isEmpty) return;

      final personalizado = fields['personalizado']?['booleanValue'] as bool? ?? true;
      await AuthService.aplicarPinMestreDaNuvem(
        hash: hash,
        personalizado: personalizado,
      );
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MÉTODOS AUXILIARES DE PERSISTÊNCIA LOCAL
  // ──────────────────────────────────────────────────────────────────────────

  static Future<void> _salvarCachePrefs(List<OperadorModel> lista) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final maps = lista.map((o) => o.toMap()).toList();
      await prefs.setString(_keyCacheOperadoresJson, jsonEncode(maps));
    } catch (_) {}
  }

  static Future<List<OperadorModel>> _carregarCachePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyCacheOperadoresJson);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded
            .map((item) => OperadorModel.fromMap(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Espelha os hashes da nuvem nas chaves locais usadas pela autenticação
  /// offline — e, principalmente, **apaga** as chaves de quem foi excluído ou
  /// desativado.
  ///
  /// Sem essa limpeza, o hash local sobrevivia à exclusão e continuava
  /// autenticando o operador bloqueado, além de reenviá-lo ao Firestore.
  static Future<void> _sincronizarChavesLocais(List<OperadorModel> lista) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final op in lista) {
        if (op.nome.trim().isEmpty) continue;

        if (op.removido || !op.ativo) {
          await AuthService.revogarCredenciaisLocais(op.nome);
          continue;
        }

        if (op.pinHash.isEmpty) continue;
        await prefs.setString('pin_operador_${op.nomeNormalizado}_hash', op.pinHash);
      }
    } catch (_) {}
  }
}

