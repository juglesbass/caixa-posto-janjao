import 'dart:convert';

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
  final String? justificativa;
  final Map<String, int> canhotos;
  final double fundoCaixa;
  final String? authHash;

  Turno({
    this.id,
    required this.numero,
    required this.data,
    required this.operador,
    this.aberto = true,
    this.fechadoEm,
    double? vendasSistema,
    double? vendaSistema,
    this.observacao = '',
    this.justificativa,
    Map<String, int>? canhotos,
    this.fundoCaixa = 0.0,
    this.authHash,
  })  : vendasSistema = vendaSistema ?? vendasSistema ?? 0.0,
        canhotos = canhotos != null ? Map<String, int>.from(canhotos) : const {};

  bool get isFechado => !aberto;

  /// Alias de conveniência para consistência com solicitações de "vendaSistema"
  double get vendaSistema => vendasSistema;

  /// Retorna o texto de justificativa prioritário ou a observação como fallback
  String get textoJustificativa =>
      (justificativa != null && justificativa!.trim().isNotEmpty) ? justificativa! : observacao;

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
      'justificativa': justificativa ?? observacao,
      'canhotos': jsonEncode(canhotos),
      'fundo_caixa': fundoCaixa,
      'auth_hash': authHash,
    };
  }

  factory Turno.fromMap(Map<String, dynamic> map) {
    Map<String, int> canhotosMap = {};
    if (map['canhotos'] != null && map['canhotos'] is String && (map['canhotos'] as String).trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(map['canhotos'] as String);
        if (decoded is Map) {
          canhotosMap = decoded.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
        }
      } catch (_) {}
    } else if (map['canhotos'] is Map) {
      try {
        canhotosMap = (map['canhotos'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      } catch (_) {}
    }

    final valorVendas = ((map['venda_sistema'] ?? map['vendas_sistema']) as num?)?.toDouble() ?? 0.0;
    final obs = map['observacao'] as String? ?? '';
    final just = map['justificativa'] as String? ?? (obs.isNotEmpty ? obs : null);

    return Turno(
      id: map['id'] as int?,
      numero: (map['numero'] as num?)?.toInt() ?? 1,
      data: map['data'] as String? ?? '',
      operador: map['operador'] as String? ?? 'Não informado',
      aberto: map['aberto'] == 1 || map['aberto'] == true,
      fechadoEm: map['fechado_em'] as String?,
      vendasSistema: valorVendas,
      observacao: obs,
      justificativa: just,
      canhotos: canhotosMap,
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
    double? vendaSistema,
    String? observacao,
    String? justificativa,
    Map<String, int>? canhotos,
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
      vendasSistema: vendaSistema ?? vendasSistema ?? this.vendasSistema,
      observacao: observacao ?? this.observacao,
      justificativa: justificativa ?? this.justificativa,
      canhotos: canhotos != null ? Map<String, int>.from(canhotos) : this.canhotos,
      fundoCaixa: fundoCaixa ?? this.fundoCaixa,
      authHash: authHash ?? this.authHash,
    );
  }
}
