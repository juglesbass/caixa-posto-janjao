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

  /// Timer de sincronização reativa periódica (polling a cada 4 segundos)
  static Timer? _pollingTimer;
  static int _activeListenersCount = 0;
  static bool _pollingEmExecucao = false;
  static bool _migracaoExecutada = false;

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
    unawaited(_executarCicloPolling());

    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_executarCicloPolling());
    });
  }

  /// Para o monitoramento em tempo real quando nenhuma tela estiver visualizando
  static void pararMonitoramentoEmTempoReal() {
    _activeListenersCount = (_activeListenersCount - 1).clamp(0, 999);
    if (_activeListenersCount == 0) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  static Future<void> _executarCicloPolling() async {
    if (_pollingEmExecucao) return;
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
      final db = DatabaseService.instance;
      await db.salvarOperadoresCache(operadoresNuvem);
      await _salvarCachePrefs(operadoresNuvem);
      await _sincronizarChavesLocais(operadoresNuvem);

      operadoresNotifier.value = operadoresNuvem;

      statusNotifier.value = SyncStatus(
        online: true,
        mensagem: 'Sincronizado com Firestore',
        statusCode: 200,
        ultimaSincronizacao: DateTime.now(),
      );
    } catch (e) {
      // Se falhar a conexão, preserva dados locais
      final db = DatabaseService.instance;
      final locais = await db.obterOperadoresCache();
      if (operadoresNotifier.value.isEmpty && locais.isNotEmpty) {
        operadoresNotifier.value = locais;
      }
    } finally {
      _pollingEmExecucao = false;
    }
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

  static Future<void> _sincronizarEmBackground() async {
    try {
      // Esvazia fila offline
      await sincronizarFilaOffline();

      final operadoresNuvem = await _buscarDoFirestore();
      if (operadoresNuvem.isNotEmpty) {
        final db = DatabaseService.instance;
        // Atualiza cache local (SQLite e SharedPreferences)
        await db.salvarOperadoresCache(operadoresNuvem);
        await _salvarCachePrefs(operadoresNuvem);
        // Sincroniza também as chaves legadas de PIN no SharedPreferences
        await _sincronizarChavesLocais(operadoresNuvem);

        operadoresNotifier.value = operadoresNuvem;

        statusNotifier.value = SyncStatus(
          online: true,
          mensagem: 'Sincronizado com Firestore',
          statusCode: 200,
          ultimaSincronizacao: DateTime.now(),
        );
      }
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
      final db = DatabaseService.instance;
      await db.salvarOperadoresCache(operadoresNuvem);
      await _salvarCachePrefs(operadoresNuvem);
      await _sincronizarChavesLocais(operadoresNuvem);

      operadoresNotifier.value = operadoresNuvem;

      statusNotifier.value = SyncStatus(
        online: true,
        mensagem: 'Sincronizado com Nuvem',
        statusCode: 200,
        ultimaSincronizacao: DateTime.now(),
      );
      return (
        sucesso: true,
        mensagem: '✅ ${operadoresNuvem.length} operadores sincronizados via Firestore.',
        operadores: operadoresNuvem
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
  static Future<bool> sincronizarCadastroOperador({
    required String nome,
    required String pin,
    String perfil = 'operador',
    String? operadorId,
  }) async {
    final nomeLimpo = nome.trim();
    final pinLimpo = pin.trim();

    if (nomeLimpo.isEmpty || pinLimpo.length != 4 || int.tryParse(pinLimpo) == null) {
      return false;
    }

    final pinHash = AuthService.gerarHashPin(pinLimpo);
    final docId = operadorId ?? 'op_${AuthService.normalizarOperador(nomeLimpo)}';

    final operadorAtualizado = OperadorModel(
      id: docId,
      nome: nomeLimpo,
      pinHash: pinHash,
      perfil: perfil,
      ativo: true,
      postoId: 'posto_janjao',
      criadoEm: DateTime.now(),
      atualizadoEm: DateTime.now(),
    );

    // 1. Salva imediatamente no cache local (Offline-First)
    final db = DatabaseService.instance;
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
    return sincronizarCadastroOperador(
      nome: nome,
      pin: pin,
      perfil: perfil,
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
    final novoHash = AuthService.gerarHashPin(pinLimpo);
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

  /// Exclui o operador permanentemente do Firestore e do armazenamento local
  static Future<bool> excluirOperador({
    required String operadorId,
    required String nome,
  }) async {
    final db = DatabaseService.instance;
    await db.excluirOperadorCache(operadorId);
    await AuthService.excluirPinOperador(nome);

    // Atualiza o notifier reativo na tela do gerente imediatamente
    final lista = List<OperadorModel>.from(operadoresNotifier.value)
      ..removeWhere((o) => o.id == operadorId || o.nomeNormalizado == AuthService.normalizarOperador(nome));
    operadoresNotifier.value = lista;

    bool enviado = false;
    try {
      final url = await _getUrlDocumento(operadorId);
      final response = await _client.delete(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 404) {
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
        acao: 'delete',
        dados: {'id': operadorId, 'nome': nome},
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
          final response = await _client.delete(
            Uri.parse(url),
            headers: {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 6));

          if (response.statusCode == 200 || response.statusCode == 404) {
            await db.removerPendenciaOperador(pendenciaId);
            debugPrint('[Firestore Sync] ✅ Exclusão pendente $pendenciaId concluída no Firestore.');
          }
        }
      } catch (e) {
        debugPrint('[Firestore Sync] Pendência $pendenciaId continua na fila (falha de rede): $e');
      }
    }
  }

  /// Migra e envia automaticamente todos os operadores cadastrados anteriormente
  /// neste dispositivo (em SharedPreferences ou SQLite) para o Cloud Firestore.
  static Future<int> migrarOperadoresLocaisParaFirestore() async {
    int migrados = 0;
    try {
      final db = DatabaseService.instance;
      final prefs = await SharedPreferences.getInstance();

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
          hash = AuthService.gerarHashPin(pinPlano.trim());
          await prefs.setString('pin_operador_${chave}_hash', hash);
          await prefs.remove('pin_operador_$chave');
        }

        if (hash == null || hash.isEmpty) continue;

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

      // Garante envio de qualquer operador que esteja no SQLite mas não foi para a nuvem
      for (final op in locaisDb) {
        try {
          final url = await _getUrlDocumento(op.id);
          await _client.patch(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(op.toFirestoreRest()),
          ).timeout(const Duration(seconds: 4));
        } catch (_) {}
      }

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
      if (!op.ativo) {
        debugPrint('Operador ${op.nome} está desativado.');
        return false;
      }
      // Aceita tanto o hash PBKDF2 com sal quanto o SHA-256 legado da nuvem
      if (AuthService.verificarPin(pinLimpo, op.pinHash)) {
        return true;
      }
    }

    return false;
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

  static Future<void> _sincronizarChavesLocais(List<OperadorModel> lista) async {
    try {
      for (final op in lista) {
        final chave = 'pin_operador_${op.nomeNormalizado}';
        // Guarda hash ou referência
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('${chave}_hash', op.pinHash);
      }
    } catch (_) {}
  }
}

