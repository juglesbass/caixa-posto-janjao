import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
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
  static Completer<Database>? _initCompleter;

  /// Notifier reativo para sincronização instantânea de telas quando lançamentos são criados/alterados/excluídos
  static final ValueNotifier<int> lancamentosNotifier = ValueNotifier<int>(0);

  /// Indica se o banco aberto grava em disco/IndexedDB. Falso significa banco
  /// apenas em memória (dados perdidos ao recarregar) — usado para alertar o caixa.
  static bool armazenamentoPersistente = true;

  /// Detalhe técnico da falha de armazenamento, quando houver
  static String? erroArmazenamento;

  /// Versão do esquema garantido por [_garantirTabelas]. Suba este número ao
  /// acrescentar lá uma tabela, coluna ou índice: é o que faz os aparelhos já
  /// instalados rodarem a migração mais uma vez.
  static const int _versaoEsquema = 1;
  static const String _keyEsquemaGarantido = 'db_esquema_garantido_versao';

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<Database>();
    try {
      _database = await _initDatabase();
      _initCompleter!.complete(_database!);
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Database db;

    // Ligado por [_onCreate]: banco novo — ou recriado porque o navegador
    // descartou o armazenamento — precisa do esquema completo, sem depender de
    // marcador nenhum.
    var bancoRecemCriado = false;
    Future<void> criar(Database d, int versao) async {
      bancoRecemCriado = true;
      await _onCreate(d, versao);
    }

    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
      try {
        db = await openDatabase(
          'caixa_posto_janjao_web.db',
          version: 1,
          onCreate: criar,
        );
        armazenamentoPersistente = true;
      } catch (e) {
        // Causa mais comum: 'web/sqlite3.wasm' ausente no build (rode
        // `dart run sqflite_common_ffi_web:setup`) ou bloqueado pelo servidor.
        debugPrint('[DB] Falha ao abrir banco persistente no Web: $e');
        debugPrint('[DB] Ativando banco em memória — os dados NÃO sobrevivem ao recarregar a página.');
        armazenamentoPersistente = false;
        erroArmazenamento = e.toString();
        db = await openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onCreate: criar,
        );
      }
    } else {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'caixa_posto_janjao.db');
      db = await openDatabase(
        path,
        version: 1,
        onCreate: criar,
      );
      armazenamentoPersistente = true;
    }
    await _garantirEsquema(db, recemCriado: bancoRecemCriado);
    return db;
  }

  /// Roda [_garantirTabelas] só quando faz falta.
  ///
  /// São 24 instruções, e onze delas são `ALTER TABLE` que falham de propósito
  /// porque a coluna já existe. No celular isso é barato; no PWA não é: cada
  /// instrução é uma transação contra o SQLite em WebAssembly persistido em
  /// IndexedDB, no mesmo thread que desenha a tela e recebe os toques — no
  /// Safari de iPhone mais fraco era uma fatia visível da demora da abertura, e
  /// o preço era pago em toda abertura para nada.
  ///
  /// O marcador fica nas preferências, e não no `user_version` do banco, porque
  /// esse pragma pertence ao sqflite: é por ele que ele decide chamar
  /// [_onCreate]. Sem marcador, ou com marcador de outra versão, o esquema é
  /// garantido como antes. E ele só é gravado com o banco persistente, senão uma
  /// abertura que caiu para o banco em memória faria o banco de verdade pular a
  /// migração na próxima vez.
  Future<void> _garantirEsquema(Database db, {required bool recemCriado}) async {
    if (!recemCriado) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getInt(_keyEsquemaGarantido) == _versaoEsquema) return;
      } catch (_) {
        // Preferências inacessíveis: segue pelo caminho antigo, garantindo tudo.
      }
    }

    final completo = await _garantirTabelas(db);

    // Esquema incompleto não é marcado: a próxima abertura precisa tentar de
    // novo, como acontecia antes.
    if (!completo || !armazenamentoPersistente) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyEsquemaGarantido, _versaoEsquema);
    } catch (_) {}
  }

  /// Garante tabelas, colunas e índices acrescentados depois de [_onCreate].
  ///
  /// Devolve `false` quando algum passo não pôde ser aplicado — hoje só o índice
  /// único da fila do Drive, que é justamente o que não pode ficar de fora.
  Future<bool> _garantirTabelas(Database db) async {
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
    try {
      await db.execute('ALTER TABLE turnos ADD COLUMN versao INTEGER NOT NULL DEFAULT 1');
    } catch (_) {}

    // Tabela de cache local de Operadores sincronizados via Firestore
    await db.execute('''
      CREATE TABLE IF NOT EXISTS operadores_cache (
        id TEXT PRIMARY KEY,
        nome TEXT NOT NULL,
        pin_hash TEXT NOT NULL,
        perfil TEXT NOT NULL DEFAULT 'operador',
        ativo INTEGER NOT NULL DEFAULT 1,
        removido INTEGER NOT NULL DEFAULT 0,
        posto_id TEXT NOT NULL DEFAULT 'posto_janjao',
        criado_em TEXT NOT NULL DEFAULT '',
        atualizado_em TEXT NOT NULL
      )
    ''');
    try {
      await db.execute("ALTER TABLE operadores_cache ADD COLUMN perfil TEXT NOT NULL DEFAULT 'operador'");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE operadores_cache ADD COLUMN posto_id TEXT NOT NULL DEFAULT 'posto_janjao'");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE operadores_cache ADD COLUMN criado_em TEXT NOT NULL DEFAULT ''");
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE operadores_cache ADD COLUMN removido INTEGER NOT NULL DEFAULT 0');
    } catch (_) {}

    // Controle de tentativas da fila do Drive: sem isso o reenvio fica em laço
    // apertado contra um webhook que está fora do ar, gastando bateria e dados.
    try {
      await db.execute('ALTER TABLE drive_pendencias ADD COLUMN tentativas INTEGER NOT NULL DEFAULT 0');
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE drive_pendencias ADD COLUMN proxima_tentativa TEXT NOT NULL DEFAULT ''");
    } catch (_) {}
    // Guarda a causa da pendência: a fila sobrevive ao fechamento do app, e sem
    // isso o banner só sabia dizer "sem internet" para qualquer tipo de falha.
    try {
      await db.execute('ALTER TABLE drive_pendencias ADD COLUMN motivo TEXT');
    } catch (_) {}

    // Fila de sincronização offline de operadores (para envio quando restabelecer a conexão)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS operadores_pendentes_sync (
        id TEXT PRIMARY KEY,
        operador_id TEXT NOT NULL,
        acao TEXT NOT NULL,
        dados_json TEXT NOT NULL,
        criado_em TEXT NOT NULL
      )
    ''');

    // Índices de alta performance para garantir consultas instantâneas sem travamentos (O(log n))
    await db.execute('CREATE INDEX IF NOT EXISTS idx_lancamentos_turno_id ON lancamentos (turno_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_turnos_aberto ON turnos (aberto)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_turnos_auth_hash ON turnos (auth_hash)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_drive_pendencias_turno ON drive_pendencias (turno_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_operadores_cache_nome ON operadores_cache (nome)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_operadores_pendentes_sync_op ON operadores_pendentes_sync (operador_id)');

    // Garante uma única pendência por turno: sem isso um fechamento que falha
    // várias vezes enfileira linhas duplicadas e o PDF é enviado repetido ao Drive.
    try {
      await db.execute(
        'DELETE FROM drive_pendencias WHERE id NOT IN '
        '(SELECT MIN(id) FROM drive_pendencias GROUP BY turno_id)',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_drive_pendencias_turno_unico ON drive_pendencias (turno_id)',
      );
      return true;
    } catch (e) {
      debugPrint('[DB] Não foi possível aplicar índice único da fila do Drive: $e');
      // Este índice é a única proteção contra o mesmo PDF ser enviado duas vezes
      // ao Drive. Falhando ele, o esquema não é marcado como pronto.
      return false;
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
        justificativa TEXT DEFAULT '',
        canhotos TEXT DEFAULT '{}',
        fundo_caixa REAL DEFAULT 0.0,
        auth_hash TEXT,
        versao INTEGER NOT NULL DEFAULT 1
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
        criado_em TEXT NOT NULL,
        tentativas INTEGER NOT NULL DEFAULT 0,
        proxima_tentativa TEXT NOT NULL DEFAULT '',
        motivo TEXT
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
        removido INTEGER NOT NULL DEFAULT 0,
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

    int numeroTurno = 0;
    int id = 0;

    await db.transaction((txn) async {
      // Fechar turnos abertos anteriormente por segurança
      await txn.update('turnos', {'aberto': 0, 'fechado_em': dataCompletaStr}, where: 'aberto = 1');

      // Obter número do turno no dia
      final result = await txn.rawQuery(
        "SELECT COUNT(*) as count FROM turnos WHERE substr(data, 1, 10) = ?",
        [dataHojeStr],
      );
      final countDia = (result.first['count'] as num?)?.toInt() ?? 0;
      numeroTurno = countDia + 1;

      id = await txn.insert('turnos', {
        'numero': numeroTurno,
        'data': dataCompletaStr,
        'operador': operador,
        'aberto': 1,
        'vendas_sistema': 0.0,
        'observacao': '',
        'fundo_caixa': fundoCaixa,
      });
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
    // Reabre o selecionado e incrementa a versão para versionamento sequencial de relatórios
    final turnoAtual = await obterTurnoPorId(turnoId);
    final proximaVersao = (turnoAtual?.versao ?? 1) + 1;
    await db.update(
      'turnos',
      {
        'aberto': 1,
        'fechado_em': null,
        'versao': proximaVersao,
      },
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

    lancamentosNotifier.value++;

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
    lancamentosNotifier.value++;
  }

  Future<void> deletarLancamento(int id, int turnoId) async {
    final db = await database;
    await db.delete(
      'lancamentos',
      where: 'id = ? AND turno_id = ?',
      whereArgs: [id, turnoId],
    );
    lancamentosNotifier.value++;
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
    double suprimentos = 0.0;
    int qtdSuprimentos = 0;

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
      } else if (PaymentTypes.ehSuprimento(tipo)) {
        // Suprimento é dinheiro que entra na gaveta (troco reposto pela
        // gerência), não é venda: entra no caixa físico e fica fora do total
        // de vendas comparado com o PDV.
        suprimentos += valor;
        qtdSuprimentos++;
      } else if (PaymentTypes.ehCartao(tipo)) {
        cartoes += valor;
        qtdCartoes++;
        final atual = detalheCartoes[tipo] ?? (total: 0.0, qtd: 0);
        detalheCartoes[tipo] = (total: atual.total + valor, qtd: atual.qtd + 1);
      }
    }

    final totalGeral = dinheiro + pix + cartoes + requisicao + depositoGlobal + despesas;
    final diferenca = totalGeral - vendasSistema;
    final dinheiroGaveta = fundoCaixa + dinheiro + suprimentos - sangrias - despesas;

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
      suprimentos: suprimentos,
      qtdSuprimentos: qtdSuprimentos,
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

  /// Espera antes da próxima tentativa automática, por número de falhas.
  /// Cresce até 30 minutos: o fechamento não é urgente ao ponto de justificar
  /// martelar um webhook fora do ar de segundo em segundo no 4G do frentista.
  static Duration backoffDaFila(int tentativas) {
    const escala = [
      Duration(seconds: 30),
      Duration(minutes: 2),
      Duration(minutes: 5),
      Duration(minutes: 15),
      Duration(minutes: 30),
    ];
    if (tentativas <= 0) return Duration.zero;
    final idx = (tentativas - 1).clamp(0, escala.length - 1);
    return escala[idx];
  }

  Future<void> salvarPendenciaDrive(
    int turnoId,
    String caminhoPdf,
    String operador, {
    String? motivo,
  }) async {
    final db = await database;

    // Preserva o histórico de tentativas ao regravar a pendência do mesmo turno,
    // senão o backoff zera a cada falha e volta a ser um laço apertado.
    int tentativas = 0;
    try {
      final atuais = await db.query(
        'drive_pendencias',
        columns: ['tentativas'],
        where: 'turno_id = ?',
        whereArgs: [turnoId],
        limit: 1,
      );
      if (atuais.isNotEmpty) {
        tentativas = (atuais.first['tentativas'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}

    tentativas += 1;
    final proxima = DateTime.now().add(backoffDaFila(tentativas));

    await db.delete('drive_pendencias', where: 'turno_id = ?', whereArgs: [turnoId]);
    await db.insert(
      'drive_pendencias',
      {
        'turno_id': turnoId,
        'caminho_pdf': caminhoPdf,
        'operador': operador,
        'criado_em': DateTime.now().toIso8601String(),
        'tentativas': tentativas,
        'proxima_tentativa': proxima.toIso8601String(),
        'motivo': motivo,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Atualiza só a causa de uma pendência já enfileirada, sem mexer no backoff
  Future<void> atualizarMotivoPendencia(int turnoId, String motivo) async {
    final db = await database;
    try {
      await db.update(
        'drive_pendencias',
        {'motivo': motivo},
        where: 'turno_id = ?',
        whereArgs: [turnoId],
      );
    } catch (_) {}
  }

  Future<void> removerPendenciaDrive(int turnoId) async {
    final db = await database;
    await db.delete(
      'drive_pendencias',
      where: 'turno_id = ?',
      whereArgs: [turnoId],
    );
  }

  /// Todas as pendências da fila, inclusive as que ainda estão em backoff.
  /// É esta contagem que alimenta o banner e a notificação: o operador precisa
  /// ver que existe PDF preso mesmo enquanto o reenvio automático está esperando.
  Future<List<Map<String, dynamic>>> obterPendenciasDrive() async {
    final db = await database;
    return await db.query('drive_pendencias', orderBy: 'id ASC');
  }

  /// Só as pendências cuja janela de backoff já venceu. Usada pelo reenvio
  /// automático; o botão "Reenviar" da tela ignora o backoff de propósito.
  Future<List<Map<String, dynamic>>> obterPendenciasDriveVencidas() async {
    final agora = DateTime.now();
    final todas = await obterPendenciasDrive();
    return todas.where((p) {
      final bruto = (p['proxima_tentativa'] as String?)?.trim() ?? '';
      if (bruto.isEmpty) return true;
      final quando = DateTime.tryParse(bruto);
      return quando == null || !quando.isAfter(agora);
    }).toList();
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

  /// Zera turnos, lançamentos e encerrantes do dispositivo.
  ///
  /// Recusa a operação enquanto houver PDF de fechamento na fila do Drive: os
  /// turnos apagados nunca mais poderiam ser reenviados, e o fechamento sumiria
  /// sem nunca ter chegado à pasta do gerente. Quem chama deve tratar o
  /// [StateError] e mandar o usuário sincronizar antes.
  Future<void> resetarTudo({bool ignorarPendenciasDrive = false}) async {
    final db = await database;

    if (!ignorarPendenciasDrive) {
      final pendentes = await obterPendenciasDrive();
      if (pendentes.isNotEmpty) {
        throw StateError(
          'Existem ${pendentes.length} PDF(s) de fechamento aguardando envio ao '
          'Google Drive. Envie-os antes de zerar os dados.',
        );
      }
    }

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
        orderBy: 'bico ASC',
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

  /// Grava a lista vinda da nuvem no cache local.
  ///
  /// Com [substituirTudo] o cache passa a espelhar exatamente a nuvem: quem não
  /// veio na lista é apagado daqui. Sem isso, um operador excluído pela gerência
  /// ficava para sempre no cache deste aparelho e era reenviado ao Firestore na
  /// próxima migração, ressuscitando sozinho.
  ///
  /// Só use [substituirTudo] quando a busca na nuvem realmente tiver sucesso —
  /// aplicar isso com uma lista vazia por falha de rede apagaria o cache inteiro
  /// e deixaria o caixa sem conseguir autenticar offline.
  Future<void> salvarOperadoresCache(
    List<OperadorModel> operadores, {
    bool substituirTudo = false,
  }) async {
    final db = await database;
    final batch = db.batch();

    if (substituirTudo) {
      final idsNuvem = operadores.map((o) => o.id).where((id) => id.isNotEmpty).toList();
      if (idsNuvem.isEmpty) {
        batch.delete('operadores_cache');
      } else {
        final placeholders = List.filled(idsNuvem.length, '?').join(',');
        batch.delete(
          'operadores_cache',
          where: 'id NOT IN ($placeholders)',
          whereArgs: idsNuvem,
        );
      }
    }

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

  Future<List<OperadorModel>> obterOperadoresCache({bool incluirRemovidos = false}) async {
    final db = await database;
    try {
      final rows = await db.query(
        'operadores_cache',
        where: incluirRemovidos ? null : 'removido = 0',
        orderBy: 'nome ASC',
      );
      return rows.map((r) => OperadorModel.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Busca pelo nome. Por padrão devolve também os removidos, porque quem
  /// autentica precisa distinguir "operador desconhecido" de "operador excluído"
  /// — no segundo caso o acesso tem de ser negado, não cair em algum fallback.
  Future<OperadorModel?> obterOperadorCachePorNome(
    String nome, {
    bool incluirRemovidos = true,
  }) async {
    final db = await database;
    try {
      final nomeLimpo = nome.trim();
      final rows = await db.query(
        'operadores_cache',
        where: incluirRemovidos
            ? 'LOWER(nome) = LOWER(?)'
            : 'LOWER(nome) = LOWER(?) AND removido = 0',
        whereArgs: [nomeLimpo],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return OperadorModel.fromMap(rows.first);
      }
    } catch (_) {}
    return null;
  }

  Future<void> excluirOperadorCache(String id) async {
    final db = await database;
    try {
      await db.delete(
        'operadores_cache',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('[DB] Erro ao remover operador do cache: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // FILA DE SINCRONIZAÇÃO OFFLINE DE OPERADORES
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> salvarPendenciaOperador({
    required String operadorId,
    required String acao,
    required Map<String, dynamic> dados,
  }) async {
    final db = await database;
    try {
      await db.insert(
        'operadores_pendentes_sync',
        {
          'id': 'sync_${operadorId}_${DateTime.now().millisecondsSinceEpoch}',
          'operador_id': operadorId,
          'acao': acao,
          'dados_json': jsonEncode(dados),
          'criado_em': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[DB] Erro ao salvar pendência de operador: $e');
    }
  }

  Future<void> removerPendenciaOperador(String pendenciaId) async {
    final db = await database;
    try {
      await db.delete(
        'operadores_pendentes_sync',
        where: 'id = ?',
        whereArgs: [pendenciaId],
      );
    } catch (e) {
      debugPrint('[DB] Erro ao remover pendência de operador: $e');
    }
  }

  Future<void> limparPendenciasDoOperador(String operadorId) async {
    final db = await database;
    try {
      await db.delete(
        'operadores_pendentes_sync',
        where: 'operador_id = ?',
        whereArgs: [operadorId],
      );
    } catch (e) {
      debugPrint('[DB] Erro ao limpar pendências do operador: $e');
    }
  }

  Future<List<Map<String, dynamic>>> obterPendenciasOperadores() async {
    final db = await database;
    try {
      return await db.query('operadores_pendentes_sync', orderBy: 'criado_em ASC');
    } catch (e) {
      debugPrint('[DB] Erro ao obter pendências de operadores: $e');
      return [];
    }
  }
}
