import 'package:caixa_posto_janjao/widgets/bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<int> abas;
  late int rapidos;

  Future<void> montar(WidgetTester tester) async {
    abas = [];
    rapidos = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: BottomNavBar(
            indiceAtual: 0,
            onTrocarAba: abas.add,
            onAbrirLancamentoRapido: () => rapidos++,
          ),
        ),
      ),
    );
  }

  group('Rodapé', () {
    testWidgets('cada aba avisa a troca com o próprio índice', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Início'));
      await tester.tap(find.text('Histórico'));
      await tester.tap(find.text('Resumo'));
      await tester.tap(find.text('Menu'));

      expect(abas, [0, 1, 2, 3]);
      expect(rapidos, 0);
    });

    testWidgets('o + abre o lançamento rápido e não troca de aba', (tester) async {
      await montar(tester);

      await tester.tap(find.byIcon(Icons.add_rounded));

      expect(rapidos, 1);
      expect(abas, isEmpty);
    });

    testWidgets('a aba inteira é alvo de toque, não só o texto', (tester) async {
      await montar(tester);
      final barra = tester.getRect(find.byType(BottomNavBar));

      // Canto esquerdo da coluna de Início, longe do ícone e do texto.
      await tester.tapAt(Offset(barra.left + 4, barra.center.dy));

      expect(abas, [0]);
    });

    // Regressão: com o + dentro de um Center sem heightFactor, a barra se
    // esticava até a altura da tela e cobria todo o conteúdo.
    testWidgets('a barra tem altura de barra, não de tela', (tester) async {
      await montar(tester);

      final altura = tester.getSize(find.byType(BottomNavBar)).height;

      expect(altura, lessThan(100));
    });
  });
}
