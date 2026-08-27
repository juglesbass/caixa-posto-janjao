/// Modelo de Produto para consulta rápida de códigos do PDV / Pista
class Produto {
  final String codigo;
  final String descricao;

  const Produto({
    required this.codigo,
    required this.descricao,
  });

  /// Identifica uma categoria visual rápida baseada na descrição
  String get categoria {
    final desc = descricao.toUpperCase();
    if (desc.contains('LUBRIF') || desc.contains('FLUIDO') || desc.contains('ADITIVO')) {
      return 'Lubrificantes & Fluidos';
    }
    if (desc.contains('AROMATIZANTE') || desc.contains('SILICONE')) {
      return 'Cuidados & Aromatizantes';
    }
    if (desc.contains('GELO') || desc.contains('AGUA')) {
      return 'Conveniência & Bebidas';
    }
    if (desc.contains('ARLA')) {
      return 'Arla 32';
    }
    if (desc.contains('BALDE') || desc.contains('VASILHAME')) {
      return 'Recipientes & Acessórios';
    }
    return 'Geral';
  }
}

/// Catálogo estático com a base inicial de produtos cadastrados do Posto Janjão
class ProdutosData {
  static const List<Produto> listaProdutos = [
    Produto(codigo: '00488', descricao: 'ADITIVO RAD IPI PRONTO 1L'),
    Produto(codigo: '00043', descricao: 'AGUA CRIM 20'),
    Produto(codigo: '21950', descricao: 'ARLA 32- AMAZONIA 5 LT'),
    Produto(codigo: '19377', descricao: 'ARLA 32- AMAZONIA BB 20L'),
    Produto(codigo: '20305', descricao: 'AROMATIZANTE 45ML/VIDRO ALIEN'),
    Produto(codigo: '20304', descricao: 'AROMATIZANTE 45ML/VIDRO AMERICA'),
    Produto(codigo: '23582', descricao: 'AROMATIZANTE 45ML/VIDRO ATENAS'),
    Produto(codigo: '00469', descricao: 'AROMATIZANTE 45ML/VIDRO ITALY'),
    Produto(codigo: '21591', descricao: 'AROMATIZANTE 45ML/VIDRO LONDON'),
    Produto(codigo: '00468', descricao: 'AROMATIZANTE CENTRALSUL AMERICA'),
    Produto(codigo: '19332', descricao: 'AROMATIZANTE CENTRALSUL ITALY'),
    Produto(codigo: '20637', descricao: 'AROMATIZANTE CENTRALSUL LONDON'),
    Produto(codigo: '23581', descricao: 'AROMATIZANTE CENTRALSUL MADRI'),
    Produto(codigo: '21729', descricao: 'AROMATIZANTE HOT RACING 400ML'),
    Produto(codigo: '00217', descricao: 'BALDE DE EMERGENCIA 5 LITROS'),
    Produto(codigo: '00029', descricao: 'FLUIDO DE FREIO DOT 3 BOSCH 500ML'),
    Produto(codigo: '19578', descricao: 'FLUIDO DE FREIO DOT 3 IPI 500ML'),
    Produto(codigo: '26095', descricao: 'FLUIDO DE FREIO DOT 4 IPI COR VERM 500ML'),
    Produto(codigo: '00991', descricao: 'GELO 05 KG'),
    Produto(codigo: '00992', descricao: 'GELO 10 KG'),
    Produto(codigo: '19347', descricao: 'GELO 20 KG'),
    Produto(codigo: '22708', descricao: 'GLOBAL INVISIBL PRONTO AMARELO 500ML'),
    Produto(codigo: '00035', descricao: 'LUBRIF IPI 20W50 SL PROTECT CARRO 1L'),
    Produto(codigo: '00036', descricao: 'LUBRIF IPI 2T 500ML'),
    Produto(codigo: '19710', descricao: 'LUBRIF IPI 5W30 SP SINTETICO 1L'),
    Produto(codigo: '00040', descricao: 'LUBRIF IPI ATF DEXRON DH 500ML'),
    Produto(codigo: '20545', descricao: 'LUBRIF MOBIL 15W40 SL SEMISINT 1L'),
    Produto(codigo: '20576', descricao: 'LUBRIF MOBIL 20W 50 API SL CARRO 1L'),
    Produto(codigo: '20578', descricao: 'LUBRIF MOBIL MOTO 4T 10W30 1L'),
    Produto(codigo: '23887', descricao: 'SILICONE SPRAY AMERICA 400ML'),
    Produto(codigo: '23885', descricao: 'SILICONE SPRAY ITALY 400ML'),
    Produto(codigo: '00200', descricao: 'VASILHAME 20 L'),
  ];
}
