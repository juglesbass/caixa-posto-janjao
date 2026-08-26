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

  /// Ordem oficial de exibição de cartões e vouchers:
  /// 1. FITCARD
  /// 2. EXCARD
  /// 3. REDE AMEX
  /// 4. REDE ELO CREDITO
  /// 5. REDE ELO DEBITO
  /// 6. REDE MASTER CREDITO
  /// 7. REDE MASTER DEBITO
  /// 8. REDE VISA CREDITO
  /// 9. REDE VISA DEBITO
  /// 10. REDE SODEXO
  /// 11. REDE PIX
  /// 12. REDE AVANCARD
  static const List<String> bandeirasPadrao = [
    'Fitcard',
    'Excard',
    'Amex',
    'Elo Crédito',
    'Elo Débito',
    'Master Crédito',
    'Master Débito',
    'Visa Crédito',
    'Visa Débito',
    'Sodexo',
    'Pix',
    'Avancard',
    'Eucard',
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

  /// Retorna o peso numérico da ordem oficial do cartão
  static int getOrdemCartao(String nome) {
    final n = nome
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U');

    // 1. FITCARD
    if (n.contains('FITCARD')) return 1;
    // 2. EXCARD
    if (n.contains('EXCARD')) return 2;
    // 3. REDE AMEX / AMEX
    if (n.contains('AMEX')) return 3;
    // 4. REDE ELO CREDITO
    if (n.contains('ELO') && (n.contains('CRED') || n.contains('CREDITO'))) return 4;
    // 5. REDE ELO DEBITO
    if (n.contains('ELO') && (n.contains('DEB') || n.contains('DEBITO'))) return 5;
    // 6. REDE MASTER CREDITO
    if (n.contains('MASTER') && (n.contains('CRED') || n.contains('CREDITO'))) return 6;
    // 7. REDE MASTER DEBITO
    if (n.contains('MASTER') && (n.contains('DEB') || n.contains('DEBITO'))) return 7;
    // 8. REDE VISA CREDITO
    if (n.contains('VISA') && (n.contains('CRED') || n.contains('CREDITO'))) return 8;
    // 9. REDE VISA DEBITO
    if (n.contains('VISA') && (n.contains('DEB') || n.contains('DEBITO'))) return 9;
    // 10. REDE SODEXO
    if (n.contains('SODEXO')) return 10;
    // 11. REDE PIX / PIX
    if (n.contains('PIX')) return 11;
    // 12. REDE AVANCARD / AVANCARD
    if (n.contains('AVANCARD')) return 12;
    // 13. EUCARD
    if (n.contains('EUCARD')) return 13;
    // 14. ALELO
    if (n.contains('ALELO')) return 14;
    // 15. VR
    if (n.contains('VR')) return 15;

    return 999;
  }

  /// Ordena entradas de detalhe de cartões seguindo a ordem oficial
  static List<MapEntry<String, T>> ordenarCartoes<T>(Iterable<MapEntry<String, T>> entries) {
    final list = entries.toList();
    list.sort((a, b) {
      final ordA = getOrdemCartao(a.key);
      final ordB = getOrdemCartao(b.key);
      if (ordA != ordB) return ordA.compareTo(ordB);
      return a.key.compareTo(b.key);
    });
    return list;
  }

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
