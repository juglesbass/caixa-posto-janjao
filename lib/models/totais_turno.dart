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
  final double pix;
  final double cartoes;
  final int qtdCartoes;
  final double requisicao;
  final double depositoGlobal;
  final double despesas;
  final double sangrias;
  final int qtdSangrias;
  final double fundoCaixa;
  final double totalGeral;
  final double diferenca;
  final double vendasSistema;
  final double dinheiroGaveta;
  final Map<String, ({double total, int qtd})> detalheCartoes;

  TotaisTurno({
    this.dinheiro = 0.0,
    this.pix = 0.0,
    this.cartoes = 0.0,
    this.qtdCartoes = 0,
    this.requisicao = 0.0,
    this.depositoGlobal = 0.0,
    this.despesas = 0.0,
    this.sangrias = 0.0,
    this.qtdSangrias = 0,
    this.fundoCaixa = 0.0,
    this.totalGeral = 0.0,
    this.diferenca = 0.0,
    this.vendasSistema = 0.0,
    this.dinheiroGaveta = 0.0,
    this.detalheCartoes = const {},
  });

  bool get temDiferenca => diferenca.abs() >= 0.01;
  bool get ehSobra => diferenca > 0.009;
  bool get ehFalta => diferenca < -0.009;
}
