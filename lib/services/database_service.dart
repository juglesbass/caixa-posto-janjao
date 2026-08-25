import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/lancamento.dart';
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
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await openDatabase(
        'caixa_posto_janjao.db',
        version: 1,
        onCreate: _onCreate,
      );
    } else {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'caixa_posto_janjao.db');
      return await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
      );
    }
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
        fundo_caixa REAL DEFAULT 0.0
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

    // Índices de performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lancamentos_turno ON lancamentos(turno_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_turnos_aberto ON turnos(aberto)');
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

  Future<void> fecharTurno(
    int turnoId, {
    double vendasSistema = 0.0,
    String observacao = '',
  }) async {
    final db = await database;
    final fechadoEm = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    await db.update(
      'turnos',
      {
        'aberto': 0,
        'fechado_em': fechadoEm,
        'vendas_sistema': vendasSistema,
        'observacao': observacao,
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

  Future<void> salvarAuditoria(int turnoId, double vendasSistema, String observacao) async {
    final db = await database;
    await db.update(
      'turnos',
      {
        'vendas_sistema': vendasSistema,
        'observacao': observacao,
      },
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

    return TotaisTurno(
      dinheiro: dinheiro,
      pix: pix,
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
      detalheCartoes: detalheCartoes,
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
}
