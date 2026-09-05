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

  /// Extrai apenas o nome da bandeira/voucher, removendo o prefixo da maquininha
  static String extrairBandeira(String nome) {
    var limpo = nome.trim();
    final upper = limpo.toUpperCase();
    if (upper.startsWith('REDE ')) {
      limpo = limpo.substring(5).trim();
    } else if (upper.startsWith('CIELO ')) {
      limpo = limpo.substring(6).trim();
    } else if (upper.startsWith('STONE ')) {
      limpo = limpo.substring(6).trim();
    } else if (upper.startsWith('PAGBANK ')) {
      limpo = limpo.substring(8).trim();
    }
    return limpo;
  }

  /// Retorna o peso numérico da máquina de cartão (Rede primeiro, depois Cielo, Stone, etc.)
  static int getOrdemMaquina(String nome) {
    final n = nome.toUpperCase();
    if (n.startsWith('REDE ')) return 1;
    if (n.startsWith('CIELO ')) return 2;
    if (n.startsWith('STONE ')) return 3;
    if (n.startsWith('PAGBANK ')) return 4;
    return 5;
  }

  /// Retorna o peso numérico da ordem oficial da bandeira/voucher:
  /// 1. Fitcard
  /// 2. Excard
  /// 3. Amex
  /// 4. Elo Crédito
  /// 5. Elo Débito
  /// 6. Master Crédito
  /// 7. Master Débito
  /// 8. Visa Crédito
  /// 9. Visa Débito
  /// 10. Sodexo
  /// 11. Pix
  /// 12. Avancard
  /// 13. Eucard
  /// 14. Alelo
  /// 15. VR
  static int getOrdemCartao(String nome) {
    final bandeira = extrairBandeira(nome);
    final n = bandeira
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');

    // 1. FITCARD
    if (n.contains('fitcard')) return 1;
    // 2. EXCARD
    if (n.contains('excard')) return 2;
    // 3. AMEX
    if (n.contains('amex')) return 3;
    // 4. ELO CREDITO
    if (n.contains('elo') && (n.contains('cred') || n.contains('credito'))) return 4;
    // 5. ELO DEBITO
    if (n.contains('elo') && (n.contains('deb') || n.contains('debito'))) return 5;
    // 6. MASTER CREDITO
    if (n.contains('master') && (n.contains('cred') || n.contains('credito'))) return 6;
    // 7. MASTER DEBITO
    if (n.contains('master') && (n.contains('deb') || n.contains('debito'))) return 7;
    // 8. VISA CREDITO
    if (n.contains('visa') && (n.contains('cred') || n.contains('credito'))) return 8;
    // 9. VISA DEBITO
    if (n.contains('visa') && (n.contains('deb') || n.contains('debito'))) return 9;
    // 10. SODEXO
    if (n.contains('sodexo')) return 10;
    // 11. PIX
    if (n.contains('pix')) return 11;
    // 12. AVANCARD
    if (n.contains('avancard')) return 12;
    // 13. EUCARD
    if (n.contains('eucard')) return 13;
    // 14. ALELO
    if (n.contains('alelo')) return 14;
    // 15. VR
    if (n == 'vr' || n.startsWith('vr ') || n.endsWith(' vr') || n.contains(' vr ')) return 15;

    return 999;
  }

  /// Ordena entradas de detalhe de cartões agrupando por máquina e ordenando por bandeira
  static List<MapEntry<String, T>> ordenarCartoes<T>(Iterable<MapEntry<String, T>> entries) {
    final list = entries.toList();
    list.sort((a, b) {
      final maqA = getOrdemMaquina(a.key);
      final maqB = getOrdemMaquina(b.key);
      if (maqA != maqB) return maqA.compareTo(maqB);

      final ordA = getOrdemCartao(a.key);
      final ordB = getOrdemCartao(b.key);
      if (ordA != ordB) return ordA.compareTo(ordB);

      return a.key.compareTo(b.key);
    });
    return list;
  }

  static bool ehCartao(String tipo) {
    final t = tipo.trim();
    final tLower = t.toLowerCase();
    if (tLower.startsWith('rede ') || tLower.startsWith('cielo ') || tLower.startsWith('stone ') || tLower.startsWith('pagbank ')) {
      return true;
    }
    return bandeirasPadrao.any((b) => b.toLowerCase() == tLower || t == b) || t == 'Cartões' || t.contains('Débito') || t.contains('Crédito');
  }

  static bool ehSangria(String tipo) => tipo == sangria;
  static bool ehSuprimento(String tipo) => tipo == suprimento;
  static bool ehDespesa(String tipo) => tipo == despesas;
  static bool ehDinheiro(String tipo) => tipo == dinheiro;
  static bool ehPix(String tipo) => tipo == pix || tipo == 'Pix Caixa' || tipo == 'Pix Direto';
  static bool ehRequisicao(String tipo) => tipo == requisicao;
  static bool ehDeposito(String tipo) => tipo == depositoGlobal || tipo == 'Depósito Global';
}
