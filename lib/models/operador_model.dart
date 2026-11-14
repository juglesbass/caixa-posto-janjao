/// Modelo de dados para Operador com suporte a Cloud Firestore e cache offline
class OperadorModel {
  final String id;
  final String nome;
  final String pinHash;
  final String perfil; // 'operador' ou 'gerente'
  final bool ativo;

  /// Exclusão reversível. O documento nunca é apagado do Firestore: a gerência
  /// marca `removido = true` e ele deixa de aparecer nas listas e de autenticar.
  /// Apagar de verdade permitiria que qualquer um zerasse a coleção inteira, e
  /// destruiria o histórico de quem assinou fechamentos antigos.
  final bool removido;
  final String postoId;
  final DateTime criadoEm;
  final DateTime atualizadoEm;

  /// [criadoEm] é opcional: quando a origem do dado não informa a data de
  /// criação (documento antigo do Firestore, cadastro migrado de uma versão
  /// anterior), ela passa a valer a data de atualização em vez de exigir que
  /// cada chamador invente uma.
  OperadorModel({
    required this.id,
    required this.nome,
    required this.pinHash,
    this.perfil = 'operador',
    this.ativo = true,
    this.removido = false,
    this.postoId = 'posto_janjao',
    DateTime? criadoEm,
    required this.atualizadoEm,
  }) : criadoEm = criadoEm ?? atualizadoEm;

  /// Nome formatado para exibição (ex: "João Victor")
  String get nomeExibicao => nome.trim();

  /// Chave normalizada em minúsculas com `_` no lugar de espaços (compatível com
  /// `AuthService.normalizarOperador` e com as chaves já salvas no aparelho).
  String get nomeNormalizado =>
      nome.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  static DateTime? _parseDataOpcional(dynamic raw) {
    if (raw == null) return null;
    final texto = raw.toString().trim();
    if (texto.isEmpty) return null;
    return DateTime.tryParse(texto);
  }

  static bool _parseBool(dynamic val, {bool padrao = false}) {
    if (val == null) return padrao;
    if (val is bool) return val;
    if (val is num) return val == 1;
    final texto = val.toString().trim().toLowerCase();
    if (texto == '1' || texto == 'true') return true;
    if (texto == '0' || texto == 'false') return false;
    return padrao;
  }

  static String? _textoOpcional(dynamic val) {
    if (val == null) return null;
    return val is String ? val : val.toString();
  }

  OperadorModel copyWith({
    String? id,
    String? nome,
    String? pinHash,
    String? perfil,
    bool? ativo,
    bool? removido,
    String? postoId,
    DateTime? criadoEm,
    DateTime? atualizadoEm,
  }) {
    return OperadorModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      pinHash: pinHash ?? this.pinHash,
      perfil: perfil ?? this.perfil,
      ativo: ativo ?? this.ativo,
      removido: removido ?? this.removido,
      postoId: postoId ?? this.postoId,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    );
  }

  /// Converte para Map plano (SQLite / SharedPreferences)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'pin_hash': pinHash,
      'perfil': perfil,
      'ativo': ativo ? 1 : 0,
      'removido': removido ? 1 : 0,
      'posto_id': postoId,
      'criado_em': criadoEm.toIso8601String(),
      'atualizado_em': atualizadoEm.toIso8601String(),
    };
  }

  /// Constrói a partir de Map plano (SQLite / SharedPreferences)
  factory OperadorModel.fromMap(Map<String, dynamic> map) {
    final dataAtualizada =
        _parseDataOpcional(map['atualizado_em']) ??
        _parseDataOpcional(map['atualizadoEm']) ??
        DateTime.now();
    final dataCriado =
        _parseDataOpcional(map['criado_em']) ??
        _parseDataOpcional(map['criadoEm']) ??
        dataAtualizada;

    return OperadorModel(
      id: _textoOpcional(map['id']) ?? '',
      nome: _textoOpcional(map['nome']) ?? '',
      pinHash: _textoOpcional(map['pin_hash']) ?? (_textoOpcional(map['pin']) ?? ''),
      perfil: _textoOpcional(map['perfil']) ?? (_textoOpcional(map['role']) ?? 'operador'),
      ativo: _parseBool(map['ativo'], padrao: true),
      removido: _parseBool(map['removido'], padrao: false),
      postoId: _textoOpcional(map['posto_id']) ?? (_textoOpcional(map['postoId']) ?? 'posto_janjao'),
      criadoEm: dataCriado,
      atualizadoEm: dataAtualizada,
    );
  }

  /// Converte para o formato de documento da API REST do Cloud Firestore
  Map<String, dynamic> toFirestoreRest() {
    return {
      'fields': {
        'id': {'stringValue': id},
        'nome': {'stringValue': nome},
        'pin': {'stringValue': pinHash},
        'pin_hash': {'stringValue': pinHash},
        'perfil': {'stringValue': perfil},
        'role': {'stringValue': perfil},
        'ativo': {'booleanValue': ativo},
        'removido': {'booleanValue': removido},
        'postoId': {'stringValue': postoId},
        'posto_id': {'stringValue': postoId},
        'criadoEm': {
          'timestampValue': criadoEm.toUtc().toIso8601String()
        },
        'criado_em': {
          'timestampValue': criadoEm.toUtc().toIso8601String()
        },
        'atualizadoEm': {
          'timestampValue': atualizadoEm.toUtc().toIso8601String()
        },
        'atualizado_em': {
          'timestampValue': atualizadoEm.toUtc().toIso8601String()
        },
      }
    };
  }

  /// Constrói a partir do JSON retornado pela API REST do Cloud Firestore
  factory OperadorModel.fromFirestoreRest(Map<String, dynamic> json, {String? docIdFallback}) {
    final fields = json['fields'] as Map<String, dynamic>? ?? {};

    // Extrai ID do campo explícito ou do caminho do documento Firestore
    String docId = docIdFallback ?? '';
    final campoId = fields['id'];
    final idExplicito = campoId is Map ? campoId['stringValue']?.toString() : null;
    if (idExplicito != null && idExplicito.trim().isNotEmpty) {
      docId = idExplicito;
    } else if (json.containsKey('name')) {
      final pathParts = (json['name']?.toString() ?? '').split('/');
      if (pathParts.isNotEmpty && pathParts.last.isNotEmpty) {
        docId = pathParts.last;
      }
    }

    String? strField(String chave) {
      final f = fields[chave];
      return f is Map ? f['stringValue']?.toString() : null;
    }

    bool? boolField(String chave) {
      final f = fields[chave];
      return f is Map ? f['booleanValue'] as bool? : null;
    }

    DateTime? tsField(String chave) {
      final f = fields[chave];
      return f is Map ? _parseDataOpcional(f['timestampValue']) : null;
    }

    final nome = strField('nome') ?? '';
    final pinHash = strField('pin_hash') ?? (strField('pin') ?? '');
    final perfil = strField('perfil') ?? (strField('role') ?? 'operador');
    final ativo = boolField('ativo') ?? true;
    final removido = boolField('removido') ?? false;
    final postoId = strField('postoId') ?? (strField('posto_id') ?? 'posto_janjao');

    final dataAtualizada =
        tsField('atualizadoEm') ??
        tsField('atualizado_em') ??
        _parseDataOpcional(json['updateTime']) ??
        DateTime.now();
    final dataCriado =
        tsField('criadoEm') ??
        tsField('criado_em') ??
        _parseDataOpcional(json['createTime']) ??
        dataAtualizada;

    return OperadorModel(
      id: docId,
      nome: nome,
      pinHash: pinHash,
      perfil: perfil,
      ativo: ativo,
      removido: removido,
      postoId: postoId,
      criadoEm: dataCriado,
      atualizadoEm: dataAtualizada,
    );
  }
}
