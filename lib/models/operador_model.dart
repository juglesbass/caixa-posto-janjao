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

  /// Chave normalizada para comparação insensível a maiúsculas/minúsculas e acentos
  String get nomeNormalizado =>
      nome.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

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
    DateTime dataCriado = DateTime.now();
    if (map['criado_em'] != null) {
      dataCriado = DateTime.tryParse(map['criado_em'].toString()) ?? DateTime.now();
    } else if (map['criadoEm'] != null) {
      dataCriado = DateTime.tryParse(map['criadoEm'].toString()) ?? DateTime.now();
    }

    DateTime dataAtualizada = DateTime.now();
    if (map['atualizado_em'] != null) {
      dataAtualizada = DateTime.tryParse(map['atualizado_em'].toString()) ?? DateTime.now();
    } else if (map['atualizadoEm'] != null) {
      dataAtualizada = DateTime.tryParse(map['atualizadoEm'].toString()) ?? DateTime.now();
    }

    return OperadorModel(
      id: map['id'] as String? ?? '',
      nome: map['nome'] as String? ?? '',
      pinHash: map['pin_hash'] as String? ?? (map['pin'] as String? ?? ''),
      perfil: map['perfil'] as String? ?? (map['role'] as String? ?? 'operador'),
      ativo: map['ativo'] == null ? true : (map['ativo'] == 1 || map['ativo'] == true),
      removido: map['removido'] == 1 || map['removido'] == true,
      postoId: map['posto_id'] as String? ?? (map['postoId'] as String? ?? 'posto_janjao'),
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
    if (fields.containsKey('id') && fields['id']['stringValue'] != null) {
      docId = fields['id']['stringValue'].toString();
    } else if (json.containsKey('name')) {
      final pathParts = (json['name'] as String?)?.split('/') ?? [];
      if (pathParts.isNotEmpty) {
        docId = pathParts.last;
      }
    }

    final nome = fields['nome']?['stringValue']?.toString() ?? '';
    final pinHash = fields['pin_hash']?['stringValue']?.toString() ??
        (fields['pin']?['stringValue']?.toString() ?? '');
    final perfil = fields['perfil']?['stringValue']?.toString() ??
        (fields['role']?['stringValue']?.toString() ?? 'operador');
    final ativo = fields['ativo']?['booleanValue'] as bool? ?? true;
    final removido = fields['removido']?['booleanValue'] as bool? ?? false;
    final postoId = fields['postoId']?['stringValue']?.toString() ??
        (fields['posto_id']?['stringValue']?.toString() ?? 'posto_janjao');

    DateTime dataCriado = DateTime.now();
    if (fields['criadoEm']?['timestampValue'] != null) {
      dataCriado = DateTime.tryParse(fields['criadoEm']['timestampValue'].toString()) ?? DateTime.now();
    } else if (fields['criado_em']?['timestampValue'] != null) {
      dataCriado = DateTime.tryParse(fields['criado_em']['timestampValue'].toString()) ?? DateTime.now();
    } else if (json['createTime'] != null) {
      dataCriado = DateTime.tryParse(json['createTime'].toString()) ?? DateTime.now();
    }

    DateTime dataAtualizada = DateTime.now();
    if (fields['atualizadoEm']?['timestampValue'] != null) {
      dataAtualizada = DateTime.tryParse(fields['atualizadoEm']['timestampValue'].toString()) ?? DateTime.now();
    } else if (fields['atualizado_em']?['timestampValue'] != null) {
      dataAtualizada = DateTime.tryParse(fields['atualizado_em']['timestampValue'].toString()) ?? DateTime.now();
    } else if (json['updateTime'] != null) {
      dataAtualizada = DateTime.tryParse(json['updateTime'].toString()) ?? DateTime.now();
    }

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
