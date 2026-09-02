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

    // 3. Se solicitado, sincroniza com o Firestore
    if (sincronizarNuvem) {
      try {
        final operadoresNuvem = await _buscarDoFirestore();
        if (operadoresNuvem.isNotEmpty) {
          // Atualiza cache local (SQLite e SharedPreferences)
          await db.salvarOperadoresCache(operadoresNuvem);
          await _salvarCachePrefs(operadoresNuvem);
          // Sincroniza também as chaves legadas de PIN no SharedPreferences
          await _sincronizarChavesLocais(operadoresNuvem);

          statusNotifier.value = SyncStatus(
            online: true,
            mensagem: 'Sincronizado com Firestore',
            statusCode: 200,
            ultimaSincronizacao: DateTime.now(),
          );
          return operadoresNuvem;
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

    return operadoresLocais;
  }

  /// Força a sincronização completa entre o dispositivo e o Firestore
  static Future<({bool sucesso, String mensagem, List<OperadorModel> operadores})> forcarSincronizacao() async {
    try {
      final operadoresNuvem = await _buscarDoFirestore();
      final db = DatabaseService.instance;
      await db.salvarOperadoresCache(operadoresNuvem);
      await _salvarCachePrefs(operadoresNuvem);
      await _sincronizarChavesLocais(operadoresNuvem);

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
    debugPrint('[Firestore Sync] URL: $url');

    final response = await _client.get(
      Uri.parse(url),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 6));

    debugPrint('[Firestore Sync] Resposta HTTP: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final docs = data['documents'] as List<dynamic>? ?? [];
      final List<OperadorModel> lista = [];

      for (final doc in docs) {
        if (doc is Map<String, dynamic>) {
          lista.add(OperadorModel.fromFirestoreRest(doc));
        }
      }
      debugPrint('[Firestore Sync] ✅ Sucesso! ${lista.length} operadores encontrados na nuvem.');
      ultimoErroDiagnostico = null;
      ultimoStatusCode = 200;
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
      debugPrint('[Firestore Sync] ❌ Erro retornado pelo Firestore:');
      debugPrint('[Firestore Sync] $erroMsg');
      if (response.statusCode == 403) {
        debugPrint('[Firestore Sync] Causa provável: Permissão negada no projeto Firestore.');
        debugPrint('[Firestore Sync] Verifique se o Cloud Firestore foi criado no console Firebase ou se as regras de segurança permitem leitura/escrita.');
      }
      throw Exception(erroMsg);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // OPERAÇÕES DE ESCRITA (ADICIONAR, REDEFINIR PIN, ATIVAR/DESATIVAR)
  // ──────────────────────────────────────────────────────────────────────────

  /// Adiciona um novo operador com nome e PIN inicial de 4 dígitos
  static Future<bool> adicionarOperador({
    required String nome,
    required String pin,
  }) async {
    final nomeLimpo = nome.trim();
    final pinLimpo = pin.trim();

    if (nomeLimpo.isEmpty || pinLimpo.length != 4 || int.tryParse(pinLimpo) == null) {
      return false;
    }

    final pinHash = AuthService.hashPin(pinLimpo);
    final docId = 'op_${DateTime.now().millisecondsSinceEpoch}_${nomeLimpo.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
    final novoOperador = OperadorModel(
      id: docId,
      nome: nomeLimpo,
      pinHash: pinHash,
      ativo: true,
      atualizadoEm: DateTime.now(),
    );

    // Salva imediatamente no cache local (Offline-First)
    final db = DatabaseService.instance;
    await db.salvarOperadorCache(novoOperador);
    await AuthService.cadastrarOuAlterarPin(nomeLimpo, pinLimpo);

    // Tenta persistir no Firestore
    try {
      final url = await _getUrlDocumento(docId);
      final response = await _client.patch(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(novoOperador.toFirestoreRest()),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        statusNotifier.value = SyncStatus(
          online: true,
          mensagem: 'Operador salvo no Firestore',
          ultimaSincronizacao: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Aviso: Operador salvo apenas localmente (offline): $e');
      statusNotifier.value = SyncStatus(
        online: false,
        mensagem: 'Salvo localmente (pendente de nuvem)',
        ultimaSincronizacao: statusNotifier.value.ultimaSincronizacao,
      );
    }

    return true;
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
    final novoHash = AuthService.hashPin(pinLimpo);
    final atualizado = operadorExistente.copyWith(
      pinHash: novoHash,
      atualizadoEm: DateTime.now(),
    );

    // Salva imediatamente no cache local
    await db.salvarOperadorCache(atualizado);
    await AuthService.cadastrarOuAlterarPin(atualizado.nome, pinLimpo);

    // Tenta atualizar no Firestore
    try {
      final url = await _getUrlDocumento(operadorId);
      final response = await _client.patch(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(atualizado.toFirestoreRest()),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        statusNotifier.value = SyncStatus(
          online: true,
          mensagem: 'PIN atualizado no Firestore',
          ultimaSincronizacao: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Aviso: PIN atualizado apenas localmente (offline): $e');
    }

    return true;
  }

  /// Ativa ou Desativa um operador sem apagar seu histórico
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

    // Tenta atualizar no Firestore
    try {
      final url = await _getUrlDocumento(operadorId);
      final response = await _client.patch(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(atualizado.toFirestoreRest()),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        statusNotifier.value = SyncStatus(
          online: true,
          mensagem: 'Status atualizado no Firestore',
          ultimaSincronizacao: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Aviso: Status atualizado apenas localmente (offline): $e');
    }

    return true;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // VALIDAÇÃO DE PIN VIA CACHE SINCRONIZADO
  // ──────────────────────────────────────────────────────────────────────────

  /// Valida o PIN digitado contra o hash SHA-256 do operador ativo no cache
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
      final hashDigitado = AuthService.hashPin(pinLimpo);
      if (hashDigitado == op.pinHash) {
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
