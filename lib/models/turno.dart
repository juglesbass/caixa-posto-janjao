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
  final int versao;

  /// Dia do caixa gravado no banco (dd/MM/yyyy), ou null em turnos anteriores a
  /// este campo. Use [dataCaixa], que já resolve o caso antigo.
  final String? dataCaixaDefinida;

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
    this.versao = 1,
    String? dataCaixa,
  })  : dataCaixaDefinida =
            (dataCaixa != null && dataCaixa.trim().isNotEmpty) ? dataCaixa.trim() : null,
        vendasSistema = vendaSistema ?? vendasSistema ?? 0.0,
        canhotos = canhotos != null ? Map<String, int>.from(canhotos) : const {};

  bool get isFechado => !aberto;

  /// Dia a que o caixa pertence (dd/MM/yyyy) — nem sempre o dia da abertura.
  /// Ver `DataCaixa`. Turnos antigos, sem o campo gravado, usam o dia da
  /// abertura, que era a regra de antes.
  String get dataCaixa => dataCaixaDefinida ?? data.trim().split(' ').first;

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
      'versao': versao,
      'data_caixa': dataCaixaDefinida,
    };
  }

  static Map<String, int> _parseCanhotos(dynamic bruto) {
    dynamic mapa = bruto;
    if (mapa is String && mapa.trim().isNotEmpty) {
      try {
        mapa = jsonDecode(mapa);
      } catch (_) {
        return {};
      }
    }
    if (mapa is! Map) return {};
    final resultado = <String, int>{};
    for (final entry in mapa.entries) {
      final v = entry.value;
      final qtd = v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
      if (qtd != null) {
        resultado[entry.key.toString()] = qtd;
      }
    }
    return resultado;
  }

  static int? _parseInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString().trim());
  }

  static double _parseDouble(dynamic val, {double padrao = 0.0}) {
    if (val == null) return padrao;
    if (val is double) return val;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().trim().replaceAll(',', '.')) ?? padrao;
  }

  factory Turno.fromMap(Map<String, dynamic> map) {
    final canhotosMap = _parseCanhotos(map['canhotos']);

    final valorVendas = _parseDouble(map['venda_sistema'] ?? map['vendas_sistema']);
    final obs = map['observacao']?.toString() ?? '';
    final justBruta = map['justificativa']?.toString();
    final just = (justBruta != null && justBruta.trim().isNotEmpty)
        ? justBruta
        : (obs.trim().isNotEmpty ? obs : null);

    final abertoBruto = map['aberto'];
    final aberto = abertoBruto == 1 || abertoBruto == true || abertoBruto == '1' || abertoBruto == 'true';

    return Turno(
      id: _parseInt(map['id']),
      numero: _parseInt(map['numero']) ?? 1,
      data: map['data']?.toString() ?? '',
      operador: map['operador']?.toString() ?? 'Não informado',
      aberto: aberto,
      fechadoEm: map['fechado_em']?.toString(),
      vendasSistema: valorVendas,
      observacao: obs,
      justificativa: just,
      canhotos: canhotosMap,
      fundoCaixa: _parseDouble(map['fundo_caixa']),
      authHash: map['auth_hash']?.toString(),
      versao: _parseInt(map['versao']) ?? 1,
      dataCaixa: map['data_caixa']?.toString(),
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
    int? versao,
    String? dataCaixa,
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
      versao: versao ?? this.versao,
      dataCaixa: dataCaixa ?? dataCaixaDefinida,
    );
  }
}
