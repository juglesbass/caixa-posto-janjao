/// Modelo de Turno de Caixa
class Turno {
  final int? id;
  final int numero;
  final String data;
  final String operador;
  final bool aberto;
  final String? fechadoEm;
  final double vendasSistema;
  final String observacao;
  final double fundoCaixa;
  final String? authHash;

  Turno({
    this.id,
    required this.numero,
    required this.data,
    required this.operador,
    this.aberto = true,
    this.fechadoEm,
    this.vendasSistema = 0.0,
    this.observacao = '',
    this.fundoCaixa = 0.0,
    this.authHash,
  });

  bool get isFechado => !aberto;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'numero': numero,
      'data': data,
      'operador': operador,
      'aberto': aberto ? 1 : 0,
      'fechado_em': fechadoEm,
      'vendas_sistema': vendasSistema,
      'observacao': observacao,
      'fundo_caixa': fundoCaixa,
      'auth_hash': authHash,
    };
  }

  factory Turno.fromMap(Map<String, dynamic> map) {
    return Turno(
      id: map['id'] as int?,
      numero: (map['numero'] as num?)?.toInt() ?? 1,
      data: map['data'] as String? ?? '',
      operador: map['operador'] as String? ?? 'Não informado',
      aberto: (map['aberto'] as int?) == 1,
      fechadoEm: map['fechado_em'] as String?,
      vendasSistema: (map['vendas_sistema'] as num?)?.toDouble() ?? 0.0,
      observacao: map['observacao'] as String? ?? '',
      fundoCaixa: (map['fundo_caixa'] as num?)?.toDouble() ?? 0.0,
      authHash: map['auth_hash'] as String?,
    );
  }

  Turno copyWith({
    int? id,
    int? numero,
    String? data,
    String? operador,
    bool? aberto,
    String? fechadoEm,
    double? vendasSistema,
    String? observacao,
    double? fundoCaixa,
    String? authHash,
  }) {
    return Turno(
      id: id ?? this.id,
      numero: numero ?? this.numero,
      data: data ?? this.data,
      operador: operador ?? this.operador,
      aberto: aberto ?? this.aberto,
      fechadoEm: fechadoEm ?? this.fechadoEm,
      vendasSistema: vendasSistema ?? this.vendasSistema,
      observacao: observacao ?? this.observacao,
      fundoCaixa: fundoCaixa ?? this.fundoCaixa,
      authHash: authHash ?? this.authHash,
    );
  }
}
