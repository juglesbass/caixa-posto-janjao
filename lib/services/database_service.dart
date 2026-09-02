import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/lancamento.dart';
import '../models/operador_model.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../utils/payment_types.dart';

class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Database db;
    if (kIsWeb) {
      try {
        databaseFactory = databaseFactoryFfiWebNoWebWorker;
        db = await openDatabase(
          'caixa_posto_janjao_web.db',
          version: 1,
          onCreate: _onCreate,
        );
      } catch (e) {
        debugPrint('Aviso Web DB: $e -> Usando inMemoryDatabasePath como fallback');
        databaseFactory = databaseFactoryFfiWebNoWebWorker;
        db = await openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onCreate: _onCreate,
        );
      }
    } else {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'caixa_posto_janjao.db');
      db = await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
      );
    }
    await _garantirTabelas(db);
    return db;
  }

  Future<void> _garantirTabelas(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS encerrantes (
        turno_id INTEGER NOT NULL,
        bico TEXT NOT NULL,
        combustivel TEXT NOT NULL,
        inicial REAL DEFAULT 0.0,
        final REAL DEFAULT 0.0,
        preco REAL DEFAULT 0.0,
        PRIMARY KEY (turno_id, bico)
      )
    ''');
    try {
      await db.execute('ALTER TABLE turnos ADD COLUMN auth_hash TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE turnos ADD COLUMN justificativa TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE turnos ADD COLUMN canhotos TEXT');
    } catch (_) {}

    // Tabela de cache local de Operadores sincronizados via Firestore
    await db.execute('''
      CREATE TABLE IF NOT EXISTS operadores_cache (
        id TEXT PRIMARY KEY,
        nome TEXT NOT NULL,
        pin_hash TEXT NOT NULL,
        ativo INTEGER NOT NULL DEFAULT 1,
        atualizado_em TEXT NOT NULL
      )
    ''');

    // Índices de alta performance para garantir consultas instantâneas sem travamentos (O(log n))
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lancamentos_turno_id ON lancamentos (turno_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_turnos_aberto ON turnos (aberto)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_turnos_auth_hash ON turnos (auth_hash)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_drive_pendencias_turno ON drive_pendencias (turno_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_operadores_cache_nome ON operadores_cache (nome)');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS turnos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero INTEGER NOT NULL,
        data TEXT NOT NULL,
        operador TEXT NOT NULL,
        aberto INTEGER NOT NULL DEFAULT 1,
        fechado_em TEXT,
        vendas_sistema REAL DEFAULT 0.0,
        observacao TEXT DEFAULT '',
        justificativa TEXT DEFAULT '',
        canhotos TEXT DEFAULT '{}',
        fundo_caixa REAL DEFAULT 0.0,
        auth_hash TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS lancamentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        turno_id INTEGER NOT NULL,
        tipo TEXT NOT NULL,
        valor REAL NOT NULL,
        descricao TEXT,
        hora TEXT NOT NULL,
        data_hora TEXT NOT NULL,
        FOREIGN KEY (turno_id) REFERENCES turnos (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS config (
        chave TEXT PRIMARY KEY,
        valor TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS drive_pendencias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        turno_id INTEGER NOT NULL,
        caminho_pdf TEXT NOT NULL,
        operador TEXT NOT NULL,
        criado_em TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS encerrantes (
        turno_id INTEGER NOT NULL,
        bico TEXT NOT NULL,
        combustivel TEXT NOT NULL,
        inicial REAL DEFAULT 0.0,
        final REAL DEFAULT 0.0,
        preco REAL DEFAULT 0.0,
        PRIMARY KEY (turno_id, bico)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS operadores_cache (
        id TEXT PRIMARY KEY,
        nome TEXT NOT NULL,
        pin_hash TEXT NOT NULL,
        ativo INTEGER NOT NULL DEFAULT 1,
        atualizado_em TEXT NOT NULL
      )
    ''');

    // Índices de performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lancamentos_turno ON lancamentos(turno_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_turnos_aberto ON turnos(aberto)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_turnos_auth_hash ON turnos(auth_hash)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_drive_pendencias_turno ON drive_pendencias(turno_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_operadores_cache_nome ON operadores_cache(nome)');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TURNOS
  // ──────────────────────────────────────────────────────────────────────────

  Future<Turno> abrirNovoTurno(String operador, {double fundoCaixa = 0.0}) async {
    final db = await database;
    final now = DateTime.now();
    final dataHojeStr = DateFormat('dd/MM/yyyy').format(now);
    final dataCompletaStr = DateFormat('dd/MM/yyyy HH:mm').format(now);

    // Fechar turnos abertos anteriormente por segurança
    await db.update('turnos', {'aberto': 0, 'fechado_em': dataCompletaStr}, where: 'aberto = 1');

    // Obter número do turno no dia
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM turnos WHERE substr(data, 1, 10) = ?",
      [dataHojeStr],
    );
    final countDia = (result.first['count'] as num?)?.toInt() ?? 0;
    final numeroTurno = countDia + 1;

    final id = await db.insert('turnos', {
      'numero': numeroTurno,
      'data': dataCompletaStr,
      'operador': operador,
      'aberto': 1,
      'vendas_sistema': 0.0,
      'observacao': '',
      'fundo_caixa': fundoCaixa,
    });

    return Turno(
      id: id,
      numero: numeroTurno,
      data: dataCompletaStr,
      operador: operador,
      aberto: true,
      fundoCaixa: fundoCaixa,
    );
  }

  Future<Turno?> obterTurnoAberto() async {
    final db = await database;
    final maps = await db.query(
      'turnos',
      where: 'aberto = 1',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Turno.fromMap(maps.first);
    }
    return null;
  }

  Future<Turno?> obterTurnoPorId(int turnoId) async {
    final db = await database;
    final maps = await db.query(
      'turnos',
      where: 'id = ?',
      whereArgs: [turnoId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Turno.fromMap(maps.first);
    }
    return null;
  }

  Future<Turno?> obterTurnoPorAuthHash(String authHash) async {
    final limpo = authHash.trim();
    if (limpo.isEmpty) return null;
    final db = await database;
    final maps = await db.query(
      'turnos',
      where: 'auth_hash = ?',
      whereArgs: [limpo],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Turno.fromMap(maps.first);
    }
    return null;
  }

  Future<void> fecharTurno(
    int turnoId, {
    double vendasSistema = 0.0,
    double? vendaSistema,
    String observacao = '',
    String? justificativa,
    Map<String, int>? canhotos,
    String? authHash,
    String? dataFechamento,
  }) async {
    final db = await database;
    final fechadoEm = dataFechamento ?? DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
    final valorVendas = vendaSistema ?? vendasSistema;
    final obs = observacao;
    final just = justificativa ?? obs;

    await db.update(
      'turnos',
      {
        'aberto': 0,
        'fechado_em': fechadoEm,
        'vendas_sistema': valorVendas,
        'observacao': obs,
        'justificativa': just,
        if (canhotos != null) 'canhotos': jsonEncode(canhotos),
        if (authHash != null) 'auth_hash': authHash,
      },
      where: 'id = ?',
      whereArgs: [turnoId],
    );
  }

  Future<void> reabrirTurno(int turnoId) async {
    final db = await database;
    // Fecha qualquer outro que esteja aberto
    await db.update('turnos', {'aberto': 0}, where: 'aberto = 1');
    // Reabre o selecionado
    await db.update(
      'turnos',
      {'aberto': 1, 'fechado_em': null},
      where: 'id = ?',
      whereArgs: [turnoId],
    );
  }

  Future<void> salvarAuditoria(
    int turnoId,
    double vendasSistema,
    String observacao, {
    String? justificativa,
    Map<String, int>? canhotos,
  }) async {
    final db = await database;
    await db.update(
      'turnos',
      {
        'vendas_sistema': vendasSistema,
        'observacao': observacao,
        'justificativa': justificativa ?? observacao,
        if (canhotos != null) 'canhotos': jsonEncode(canhotos),
      },
      where: 'id = ?',
      whereArgs: [turnoId],
    );
  }

  Future<void> salvarVendaSistema(int turnoId, double vendasSistema) async {
    final db = await database;
    await db.update(
      'turnos',
      {'vendas_sistema': vendasSistema},
      where: 'id = ?',
      whereArgs: [turnoId],
    );
  }

  Future<void> salvarCanhotos(int turnoId, Map<String, int> canhotos) async {
    final db = await database;
    await db.update(
      'turnos',
      {'canhotos': jsonEncode(canhotos)},
      where: 'id = ?',
      whereArgs: [turnoId],
    );
  }

  Future<List<Turno>> obterTurnosFechados({int limit = 30}) async {
    final db = await database;
    final maps = await db.query(
      'turnos',
      where: 'aberto = 0',
      orderBy: 'id DESC',
      limit: limit,
    );
    return maps.map((m) => Turno.fromMap(m)).toList();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LANÇAMENTOS
  // ──────────────────────────────────────────────────────────────────────────

  Future<Lancamento> inserirLancamento(
    int turnoId,
    String tipo,
    double valor,
    String descricao,
  ) async {
    final db = await database;
    final now = DateTime.now();
    final hora = DateFormat('HH:mm:ss').format(now);
    final dataHora = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    final id = await db.insert('lancamentos', {
      'turno_id': turnoId,
      'tipo': tipo,
      'valor': valor,
      'descricao': descricao,
      'hora': hora,
      'data_hora': dataHora,
    });

    return Lancamento(
      id: id,
      turnoId: turnoId,
      tipo: tipo,
      valor: valor,
      descricao: descricao,
      hora: hora,
      dataHora: dataHora,
    );
  }

  Future<void> atualizarLancamento(
    int id,
    int turnoId,
    String tipo,
    double valor,
    String descricao,
  ) async {
    final db = await database;
    await db.update(
      'lancamentos',
      {
        'tipo': tipo,
        'valor': valor,
        'descricao': descricao,
      },
      where: 'id = ? AND turno_id = ?',
      whereArgs: [id, turnoId],
    );
  }

  Future<void> deletarLancamento(int id, int turnoId) async {
    final db = await database;
    await db.delete(
      'lancamentos',
      where: 'id = ? AND turno_id = ?',
      whereArgs: [id, turnoId],
    );
  }

  Future<List<Lancamento>> obterLancamentos(int turnoId) async {
    final db = await database;
    final maps = await db.query(
      'lancamentos',
      where: 'turno_id = ?',
      orderBy: 'id DESC',
      whereArgs: [turnoId],
    );
    return maps.map((m) => Lancamento.fromMap(m)).toList();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TOTAIS DO TURNO (Cálculo Agregado Rigoroso)
  // ──────────────────────────────────────────────────────────────────────────

  Future<TotaisTurno> obterTotaisTurno(int turnoId) async {
    final db = await database;
    final lancamentos = await obterLancamentos(turnoId);

    // Obter dados do turno para fundo_caixa e vendas_sistema
    final turnoMap = await db.query(
      'turnos',
      columns: ['fundo_caixa', 'vendas_sistema'],
      where: 'id = ?',
      whereArgs: [turnoId],
      limit: 1,
    );

    final double fundoCaixa = turnoMap.isNotEmpty
        ? (turnoMap.first['fundo_caixa'] as num?)?.toDouble() ?? 0.0
        : 0.0;
    final double vendasSistema = turnoMap.isNotEmpty
        ? (turnoMap.first['vendas_sistema'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    double dinheiro = 0.0;
    double pix = 0.0;
    int qtdPix = 0;
    double cartoes = 0.0;
    int qtdCartoes = 0;
    double requisicao = 0.0;
    double depositoGlobal = 0.0;
    double despesas = 0.0;
    double sangrias = 0.0;
    int qtdSangrias = 0;

    final Map<String, ({double total, int qtd})> detalheCartoes = {};

    for (final l in lancamentos) {
      final tipo = l.tipo;
      final valor = l.valor;

      if (PaymentTypes.ehDinheiro(tipo)) {
        dinheiro += valor;
      } else if (PaymentTypes.ehPix(tipo)) {
        pix += valor;
        qtdPix++;
      } else if (PaymentTypes.ehRequisicao(tipo)) {
        requisicao += valor;
      } else if (PaymentTypes.ehDeposito(tipo)) {
        depositoGlobal += valor;
      } else if (PaymentTypes.ehDespesa(tipo)) {
        despesas += valor;
      } else if (PaymentTypes.ehSangria(tipo)) {
        sangrias += valor;
        qtdSangrias++;
      } else if (PaymentTypes.ehCartao(tipo)) {
        cartoes += valor;
        qtdCartoes++;
        final atual = detalheCartoes[tipo] ?? (total: 0.0, qtd: 0);
        detalheCartoes[tipo] = (total: atual.total + valor, qtd: atual.qtd + 1);
      }
    }

    final totalGeral = dinheiro + pix + cartoes + requisicao + depositoGlobal + despesas;
    final diferenca = totalGeral - vendasSistema;
    final dinheiroGaveta = fundoCaixa + dinheiro - sangrias - despesas;

    final sortedDetalheCartoes = Map<String, ({double total, int qtd})>.fromEntries(
      PaymentTypes.ordenarCartoes(detalheCartoes.entries),
    );

    return TotaisTurno(
      dinheiro: dinheiro,
      pix: pix,
      qtdPix: qtdPix,
      cartoes: cartoes,
      qtdCartoes: qtdCartoes,
      requisicao: requisicao,
      depositoGlobal: depositoGlobal,
      despesas: despesas,
      sangrias: sangrias,
      qtdSangrias: qtdSangrias,
      fundoCaixa: fundoCaixa,
      totalGeral: totalGeral,
      diferenca: diferenca,
      vendasSistema: vendasSistema,
      dinheiroGaveta: dinheiroGaveta,
      detalheCartoes: sortedDetalheCartoes,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CONFIGURAÇÕES (PIN, Tema, etc.)
  // ──────────────────────────────────────────────────────────────────────────

  Future<String> getConfig(String chave, {String padrao = ''}) async {
    final db = await database;
    final maps = await db.query(
      'config',
      columns: ['valor'],
      where: 'chave = ?',
      whereArgs: [chave],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first['valor'] as String;
    }
    return padrao;
  }

  Future<void> setConfig(String chave, String valor) async {
    final db = await database;
    await db.insert(
      'config',
      {'chave': chave, 'valor': valor},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FILA OFFLINE DO GOOGLE DRIVE
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> salvarPendenciaDrive(int turnoId, String caminhoPdf, String operador) async {
    final db = await database;
    await db.insert(
      'drive_pendencias',
      {
        'turno_id': turnoId,
        'caminho_pdf': caminhoPdf,
        'operador': operador,
        'criado_em': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removerPendenciaDrive(int turnoId) async {
    final db = await database;
    await db.delete(
      'drive_pendencias',
      where: 'turno_id = ?',
      whereArgs: [turnoId],
    );
  }

  Future<List<Map<String, dynamic>>> obterPendenciasDrive() async {
    final db = await database;
    return await db.query('drive_pendencias', orderBy: 'id ASC');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MENU DO CAIXA: TODOS OS TURNOS, ENCERRANTES E RESET
  // ──────────────────────────────────────────────────────────────────────────

  Future<List<Turno>> obterTodosTurnos({int limit = 50}) async {
    final db = await database;
    final maps = await db.query(
      'turnos',
      orderBy: 'id DESC',
      limit: limit,
    );
    return maps.map((m) => Turno.fromMap(m)).toList();
  }

  Future<void> resetarTudo() async {
    final db = await database;
    await db.delete('lancamentos');
    await db.delete('turnos');
    await db.delete('drive_pendencias');
    try {
      await db.delete('encerrantes');
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> obterEncerrantes(int turnoId) async {
    final db = await database;
    try {
      return await db.query(
        'encerrantes',
        where: 'turno_id = ?',
        whereArgs: [turnoId],
        orderBy: 'id ASC',
      );
    } catch (_) {
      return [];
    }
  }

  Future<void> salvarEncerrante(int turnoId, String bico, String combustivel, double inicial, double finalLitros, double preco) async {
    final db = await database;
    await db.insert(
      'encerrantes',
      {
        'turno_id': turnoId,
        'bico': bico,
        'combustivel': combustivel,
        'inicial': inicial,
        'final': finalLitros,
        'preco': preco,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CACHE DE OPERADORES (OFFLINE-FIRST FIRESTORE)
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> salvarOperadoresCache(List<OperadorModel> operadores) async {
    final db = await database;
    final batch = db.batch();
    for (final op in operadores) {
      batch.insert(
        'operadores_cache',
        op.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> salvarOperadorCache(OperadorModel operador) async {
    final db = await database;
    await db.insert(
      'operadores_cache',
      operador.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<OperadorModel>> obterOperadoresCache() async {
    final db = await database;
    try {
      final rows = await db.query('operadores_cache', orderBy: 'nome ASC');
      return rows.map((r) => OperadorModel.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<OperadorModel?> obterOperadorCachePorNome(String nome) async {
    final db = await database;
    try {
      final nomeLimpo = nome.trim();
      final rows = await db.query(
        'operadores_cache',
        where: 'LOWER(nome) = LOWER(?)',
        whereArgs: [nomeLimpo],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return OperadorModel.fromMap(rows.first);
      }
    } catch (_) {}
    return null;
  }
}
