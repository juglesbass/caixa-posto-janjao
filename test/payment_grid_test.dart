import 'package:caixa_posto_janjao/theme/app_colors.dart';
import 'package:caixa_posto_janjao/theme/app_theme.dart';
import 'package:caixa_posto_janjao/utils/payment_types.dart';
import 'package:caixa_posto_janjao/widgets/payment_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> montar(WidgetTester tester, String tipoAtivo) async {
    // Largura de um iPhone de 440pt, com a mesma margem da tela Início.
    tester.view.physicalSize = const Size(440 * 3, 956 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: PaymentGrid(
              tipoAtivo: tipoAtivo,
              bandeiraCartaoAtiva: 'Master Débito',
              onSelecionarTipo: (_) {},
              onAbrirSeletorCartoes: () {},
            ),
          ),
        ),
      ),
    );
  }

  /// Os pontos coloridos da grade, da esquerda para a direita e de cima para
  /// baixo, com posição e cor.
  List<({Offset pos, Color cor})> pontos(WidgetTester tester) {
    final lista = <({Offset pos, Color cor})>[];
    for (final e in find
        .byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle)
        .evaluate()) {
      final box = e.renderObject as RenderBox;
      final cor = ((e.widget as Container).decoration as BoxDecoration).color!;
      lista.add((pos: box.localToGlobal(Offset.zero), cor: cor));
    }
    return lista;
  }

  group('Grade de pagamento', () {
    // Regressão: nome + bandeira passavam da altura do botão (o texto herdava
    // a altura de linha 1,43 do tema), e selecionado, com borda de 2px, pior.
    // Um estouro de layout faz o teste falhar sozinho.
    testWidgets('Cartões selecionado cabe no botão', (tester) async {
      await montar(tester, '${PaymentTypes.maquinaRede} Master Débito');
      expect(tester.takeException(), isNull);
    });

    testWidgets('selecionar não tira o ponto da linha dos outros', (tester) async {
      await montar(tester, PaymentTypes.dinheiro);
      final xs = pontos(tester).map((p) => p.pos.dx).toSet();

      // Duas colunas, cada uma com todos os pontos no mesmo x — inclusive o do
      // card selecionado, que tem borda mais grossa.
      expect(xs, hasLength(2));
    });

    testWidgets('só o ponto do card escolhido acende', (tester) async {
      await montar(tester, PaymentTypes.pix);
      final apagado = AppColors.pontoApagado(false);
      final acesos = pontos(tester).where((p) => p.cor != apagado).toList();

      expect(acesos, hasLength(1));
      expect(acesos.single.cor, AppColors.blue);
    });
  });
}
