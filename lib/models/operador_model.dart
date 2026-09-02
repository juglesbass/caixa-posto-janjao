/// Modelo de dados para Operador com suporte a Cloud Firestore e cache offline
class OperadorModel {
  final String id;
  final String nome;
  final String pinHash;
  final bool ativo;
  final DateTime atualizadoEm;

  const OperadorModel({
    required this.id,
    required this.nome,
    required this.pinHash,
    this.ativo = true,
    required this.atualizadoEm,
  });

  /// Nome formatado para exibição (ex: "João Victor")
  String get nomeExibicao => nome.trim();

  /// Chave normalizada para comparação insensível a maiúsculas/minúsculas e acentos
  String get nomeNormalizado =>
      nome.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  OperadorModel copyWith({
    String? id,
    String? nome,
    String? pinHash,
    bool? ativo,
    DateTime? atualizadoEm,
  }) {
    return OperadorModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      pinHash: pinHash ?? this.pinHash,
      ativo: ativo ?? this.ativo,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    );
  }

  /// Converte para Map plano (SQLite / SharedPreferences)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'pin_hash': pinHash,
      'ativo': ativo ? 1 : 0,
      'atualizado_em': atualizadoEm.toIso8601String(),
    };
  }

  /// Constrói a partir de Map plano (SQLite / SharedPreferences)
  factory OperadorModel.fromMap(Map<String, dynamic> map) {
    return OperadorModel(
      id: map['id'] as String? ?? '',
      nome: map['nome'] as String? ?? '',
      pinHash: map['pin_hash'] as String? ?? '',
      ativo: map['ativo'] == 1 || map['ativo'] == true,
      atualizadoEm: map['atualizado_em'] != null
          ? DateTime.tryParse(map['atualizado_em'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Converte para o formato de documento da API REST do Cloud Firestore
  Map<String, dynamic> toFirestoreRest() {
    return {
      'fields': {
        'id': {'stringValue': id},
        'nome': {'stringValue': nome},
        'pin_hash': {'stringValue': pinHash},
        'ativo': {'booleanValue': ativo},
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
      final pathParts = (json['name'] as String).split('/');
      if (pathParts.isNotEmpty) {
        docId = pathParts.last;
      }
    }

    final nome = fields['nome']?['stringValue']?.toString() ?? '';
    final pinHash = fields['pin_hash']?['stringValue']?.toString() ?? '';
    final ativo = fields['ativo']?['booleanValue'] as bool? ?? true;

    DateTime dataAtualizada = DateTime.now();
    if (fields['atualizado_em']?['timestampValue'] != null) {
      dataAtualizada = DateTime.tryParse(fields['atualizado_em']['timestampValue'].toString()) ?? DateTime.now();
    } else if (json['updateTime'] != null) {
      dataAtualizada = DateTime.tryParse(json['updateTime'].toString()) ?? DateTime.now();
    }

    return OperadorModel(
      id: docId,
      nome: nome,
      pinHash: pinHash,
      ativo: ativo,
      atualizadoEm: dataAtualizada,
    );
  }
}
