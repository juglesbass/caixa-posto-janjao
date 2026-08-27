import 'package:flutter_test/flutter_test.dart';
import 'package:caixa_posto_janjao/data/produtos_data.dart';

void main() {
  group('ProdutosData - Catálogo de Produtos e Códigos', () {
    test('Possui exatamente 32 produtos cadastrados na base inicial', () {
      expect(ProdutosData.listaProdutos.length, equals(32));
    });

    test('Todos os produtos possuem código e descrição válidos e não vazios', () {
      for (final p in ProdutosData.listaProdutos) {
        expect(p.codigo.trim(), isNotEmpty);
        expect(p.descricao.trim(), isNotEmpty);
        expect(p.categoria.trim(), isNotEmpty);
      }
    });

    test('Não possui códigos duplicados na base', () {
      final codigos = ProdutosData.listaProdutos.map((p) => p.codigo).toSet();
      expect(codigos.length, equals(ProdutosData.listaProdutos.length));
    });

    test('Contém produtos-chave especificados na regra de negócio', () {
      final mapa = {for (final p in ProdutosData.listaProdutos) p.codigo: p.descricao};

      expect(mapa['00488'], equals('ADITIVO RAD IPI PRONTO 1L'));
      expect(mapa['00043'], equals('AGUA CRIM 20'));
      expect(mapa['21950'], equals('ARLA 32- AMAZONIA 5 LT'));
      expect(mapa['19377'], equals('ARLA 32- AMAZONIA BB 20L'));
      expect(mapa['00991'], equals('GELO 05 KG'));
      expect(mapa['00992'], equals('GELO 10 KG'));
      expect(mapa['19347'], equals('GELO 20 KG'));
      expect(mapa['00035'], equals('LUBRIF IPI 20W50 SL PROTECT CARRO 1L'));
      expect(mapa['20545'], equals('LUBRIF MOBIL 15W40 SL SEMISINT 1L'));
      expect(mapa['23887'], equals('SILICONE SPRAY AMERICA 400ML'));
      expect(mapa['00200'], equals('VASILHAME 20 L'));
    });
  });
}
