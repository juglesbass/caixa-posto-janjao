/// Modelo de Lançamento de Venda / Movimentação
class Lancamento {
  final int? id;
  final int turnoId;
  final String tipo;
  final double valor;
  final String descricao;
  final String hora;
  final String dataHora;

  Lancamento({
    this.id,
    required this.turnoId,
    required this.tipo,
    required this.valor,
    this.descricao = '',
    required this.hora,
    required this.dataHora,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'turno_id': turnoId,
      'tipo': tipo,
      'valor': valor,
      'descricao': descricao,
      'hora': hora,
      'data_hora': dataHora,
    };
  }

  factory Lancamento.fromMap(Map<String, dynamic> map) {
    return Lancamento(
      id: map['id'] as int?,
      turnoId: (map['turno_id'] as num?)?.toInt() ?? 0,
      tipo: map['tipo'] as String? ?? 'Dinheiro',
      valor: (map['valor'] as num?)?.toDouble() ?? 0.0,
      descricao: map['descricao'] as String? ?? '',
      hora: map['hora'] as String? ?? '',
      dataHora: map['data_hora'] as String? ?? '',
    );
  }

  Lancamento copyWith({
    int? id,
    int? turnoId,
    String? tipo,
    double? valor,
    String? descricao,
    String? hora,
    String? dataHora,
  }) {
    return Lancamento(
      id: id ?? this.id,
      turnoId: turnoId ?? this.turnoId,
      tipo: tipo ?? this.tipo,
      valor: valor ?? this.valor,
      descricao: descricao ?? this.descricao,
      hora: hora ?? this.hora,
      dataHora: dataHora ?? this.dataHora,
    );
  }
}
