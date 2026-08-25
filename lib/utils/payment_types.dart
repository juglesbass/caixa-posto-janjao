/// Constantes e listas de métodos de pagamento e cartões
class PaymentTypes {
  static const String dinheiro = 'Dinheiro';
  static const String pix = 'Pag Pix';
  static const String requisicao = 'Requisição';
  static const String depositoGlobal = 'Depósito';
  static const String despesas = 'Despesas';
  static const String sangria = 'Sangria';
  static const String suprimento = 'Suprimento';

  static const String maquinaRede = 'Rede';
  static const String maquinaCielo = 'Cielo';

  static const List<String> bandeirasPadrao = [
    'Pix',
    'Master Débito',
    'Master Crédito',
    'Visa Débito',
    'Visa Crédito',
    'Elo Débito',
    'Elo Crédito',
    'Fitcard',
    'Excard',
    'Amex',
    'Eucard',
    'Avancard',
    'Sodexo',
    'Alelo Multibenefícios',
    'VR Multibenefícios',
  ];

  static const List<String> tiposGerais = [
    dinheiro,
    pix,
    'Cartões',
    requisicao,
    depositoGlobal,
    despesas,
  ];

  static bool ehCartao(String tipo) {
    if (tipo.startsWith('Rede ') || tipo.startsWith('Cielo ') || tipo.startsWith('Stone ') || tipo.startsWith('PagBank ')) {
      return true;
    }
    return bandeirasPadrao.contains(tipo) || tipo == 'Cartões' || tipo.contains('Débito') || tipo.contains('Crédito');
  }

  static bool ehSangria(String tipo) => tipo == sangria;
  static bool ehDespesa(String tipo) => tipo == despesas;
  static bool ehDinheiro(String tipo) => tipo == dinheiro;
  static bool ehPix(String tipo) => tipo == pix || tipo == 'Pix Caixa' || tipo == 'Pix Direto';
  static bool ehRequisicao(String tipo) => tipo == requisicao;
  static bool ehDeposito(String tipo) => tipo == depositoGlobal || tipo == 'Depósito Global';
}
