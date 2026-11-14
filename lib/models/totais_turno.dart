/// Item de detalhe de cartão por bandeira e máquina
class ItemDetalheCartao {
  final String maquina;
  final String bandeira;
  final double total;
  final int quantidade;

  ItemDetalheCartao({
    required this.maquina,
    required this.bandeira,
    required this.total,
    required this.quantidade,
  });

  String get nomeCompleto => '$maquina $bandeira';
}

/// Totais agregados de um turno
class TotaisTurno {
  final double dinheiro;
  final int qtdDinheiro;
  final double pix;
  final int qtdPix;
  final double cartoes;
  final int qtdCartoes;
  final double requisicao;
  final int qtdRequisicao;
  final double depositoGlobal;
  final int qtdDepositoGlobal;
  final double despesas;
  final int qtdDespesas;
  final double sangrias;
  final int qtdSangrias;
  final double suprimentos;
  final int qtdSuprimentos;
  final double fundoCaixa;
  final double totalGeral;
  final double diferenca;
  final double vendasSistema;
  final double dinheiroGaveta;
  final Map<String, ({double total, int qtd})> detalheCartoes;

  TotaisTurno({
    this.dinheiro = 0.0,
    this.qtdDinheiro = 0,
    this.pix = 0.0,
    this.qtdPix = 0,
    this.cartoes = 0.0,
    this.qtdCartoes = 0,
    this.requisicao = 0.0,
    this.qtdRequisicao = 0,
    this.depositoGlobal = 0.0,
    this.qtdDepositoGlobal = 0,
    this.despesas = 0.0,
    this.qtdDespesas = 0,
    this.sangrias = 0.0,
    this.qtdSangrias = 0,
    this.suprimentos = 0.0,
    this.qtdSuprimentos = 0,
    this.fundoCaixa = 0.0,
    this.totalGeral = 0.0,
    this.diferenca = 0.0,
    this.vendasSistema = 0.0,
    this.dinheiroGaveta = 0.0,
    this.detalheCartoes = const {},
  });

  bool get temDiferenca => diferenca.abs() >= 0.005;
  bool get ehSobra => diferenca >= 0.005;
  bool get ehFalta => diferenca <= -0.005;

  TotaisTurno copyWith({
    double? dinheiro,
    int? qtdDinheiro,
    double? pix,
    int? qtdPix,
    double? cartoes,
    int? qtdCartoes,
    double? requisicao,
    int? qtdRequisicao,
    double? depositoGlobal,
    int? qtdDepositoGlobal,
    double? despesas,
    int? qtdDespesas,
    double? sangrias,
    int? qtdSangrias,
    double? suprimentos,
    int? qtdSuprimentos,
    double? fundoCaixa,
    double? totalGeral,
    double? diferenca,
    double? vendasSistema,
    double? dinheiroGaveta,
    Map<String, ({double total, int qtd})>? detalheCartoes,
  }) {
    return TotaisTurno(
      dinheiro: dinheiro ?? this.dinheiro,
      qtdDinheiro: qtdDinheiro ?? this.qtdDinheiro,
      pix: pix ?? this.pix,
      qtdPix: qtdPix ?? this.qtdPix,
      cartoes: cartoes ?? this.cartoes,
      qtdCartoes: qtdCartoes ?? this.qtdCartoes,
      requisicao: requisicao ?? this.requisicao,
      qtdRequisicao: qtdRequisicao ?? this.qtdRequisicao,
      depositoGlobal: depositoGlobal ?? this.depositoGlobal,
      qtdDepositoGlobal: qtdDepositoGlobal ?? this.qtdDepositoGlobal,
      despesas: despesas ?? this.despesas,
      qtdDespesas: qtdDespesas ?? this.qtdDespesas,
      sangrias: sangrias ?? this.sangrias,
      qtdSangrias: qtdSangrias ?? this.qtdSangrias,
      suprimentos: suprimentos ?? this.suprimentos,
      qtdSuprimentos: qtdSuprimentos ?? this.qtdSuprimentos,
      fundoCaixa: fundoCaixa ?? this.fundoCaixa,
      totalGeral: totalGeral ?? this.totalGeral,
      diferenca: diferenca ?? this.diferenca,
      vendasSistema: vendasSistema ?? this.vendasSistema,
      dinheiroGaveta: dinheiroGaveta ?? this.dinheiroGaveta,
      detalheCartoes: detalheCartoes ?? this.detalheCartoes,
    );
  }
}
