import 'package:flutter_test/flutter_test.dart';
import 'package:caixa_posto_janjao/models/lancamento.dart';
import 'package:caixa_posto_janjao/models/totais_turno.dart';
import 'package:caixa_posto_janjao/models/turno.dart';
import 'package:caixa_posto_janjao/services/pdf_service.dart';

void main() {
  group('Models - Turno, Lancamento e TotaisTurno', () {
    test('Turno toMap e fromMap', () {
      final turno = Turno(
        id: 1,
        numero: 2,
        data: '25/08/2026 10:00',
        operador: 'João Victor',
        aberto: true,
        fundoCaixa: 150.0,
      );

      final map = turno.toMap();
      final turnoReconstruido = Turno.fromMap(map);

      expect(turnoReconstruido.id, equals(1));
      expect(turnoReconstruido.numero, equals(2));
      expect(turnoReconstruido.operador, equals('João Victor'));
      expect(turnoReconstruido.aberto, isTrue);
      expect(turnoReconstruido.fundoCaixa, equals(150.0));
    });

    test('Lancamento toMap e fromMap', () {
      final lanc = Lancamento(
        id: 10,
        turnoId: 1,
        tipo: 'Rede Master Débito',
        valor: 50.0,
        descricao: 'Venda Pista',
        hora: '10:15:00',
        dataHora: '2026-08-25 10:15:00',
      );

      final map = lanc.toMap();
      final lancReconstruido = Lancamento.fromMap(map);

      expect(lancReconstruido.id, equals(10));
      expect(lancReconstruido.tipo, equals('Rede Master Débito'));
      expect(lancReconstruido.valor, equals(50.0));
    });

    test('TotaisTurno flags de auditoria e cálculo', () {
      final totaisBatido = TotaisTurno(
        totalGeral: 1000.0,
        vendasSistema: 1000.0,
        diferenca: 0.0,
      );
      expect(totaisBatido.temDiferenca, isFalse);

      final totaisSobra = TotaisTurno(
        totalGeral: 1050.0,
        vendasSistema: 1000.0,
        diferenca: 50.0,
      );
      expect(totaisSobra.ehSobra, isTrue);
      expect(totaisSobra.ehFalta, isFalse);

      final totaisFalta = TotaisTurno(
        totalGeral: 950.0,
        vendasSistema: 1000.0,
        diferenca: -50.0,
      );
      expect(totaisFalta.ehFalta, isTrue);
      expect(totaisFalta.ehSobra, isFalse);
    });

    test('PdfService.gerarNomeArquivo formato ${operador} ${data_dd-MM-yyyy}.pdf', () {
      final turno = Turno(
        id: 1,
        numero: 1,
        data: '25/08/2026 10:00',
        operador: 'João Victor',
        aberto: true,
      );

      final nome = PdfService.gerarNomeArquivo(turno: turno);
      expect(nome, equals('João Victor 25-08-2026.pdf'));
    });

    test('PaymentTypes.ordenarCartoes - Ordenação isolada Cielo', () {
      final entrada = {
        'Cielo Visa Débito': 100.0,
        'Cielo Master Crédito': 200.0,
        'Cielo Visa Crédito': 150.0,
        'Cielo Fitcard': 50.0,
        'Cielo Master Débito': 300.0,
      };

      final ordenado = PaymentTypes.ordenarCartoes(entrada.entries).map((e) => e.key).toList();

      expect(ordenado, equals([
        'Cielo Fitcard',
        'Cielo Master Crédito',
        'Cielo Master Débito',
        'Cielo Visa Crédito',
        'Cielo Visa Débito',
      ]));
    });

    test('PaymentTypes.ordenarCartoes - Ordenação mista Rede e Cielo', () {
      final entrada = {
        'Cielo Visa Crédito': 100.0,
        'Rede Visa Débito': 50.0,
        'Cielo Master Crédito': 200.0,
        'Rede Fitcard': 70.0,
        'Cielo Master Débito': 300.0,
        'Rede Master Débito': 400.0,
        'Rede Master Crédito': 500.0,
      };

      final ordenado = PaymentTypes.ordenarCartoes(entrada.entries).map((e) => e.key).toList();

      expect(ordenado, equals([
        // Todas as bandeiras Rede primeiro na ordem oficial
        'Rede Fitcard',
        'Rede Master Crédito',
        'Rede Master Débito',
        'Rede Visa Débito',
        // Depois todas as bandeiras Cielo na ordem oficial
        'Cielo Master Crédito',
        'Cielo Master Débito',
        'Cielo Visa Crédito',
      ]));
    });
  });
}
