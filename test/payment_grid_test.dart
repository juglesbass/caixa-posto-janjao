import 'package:caixa_posto_janjao/theme/app_colors.dart';
import 'package:caixa_posto_janjao/theme/app_icones.dart';
import 'package:caixa_posto_janjao/theme/app_theme.dart';
import 'package:caixa_posto_janjao/utils/payment_types.dart';
import 'package:caixa_posto_janjao/widgets/payment_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> montar(WidgetTester tester, String tipoAtivo, {bool compacto = false}) async {
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
              compacto: compacto,
            ),
          ),
        ),
      ),
    );
  }

  /// Cada forma de pagamento e o seu icone, com a cor que ele deve ter.
  const formas = [
    (AppIcones.dinheiro, AppColors.green),
    (AppIcones.pix, AppColors.blue),
    (AppIcones.cartao, AppColors.purple),
    (AppIcones.requisicao, AppColors.amber),
    (AppIcones.deposito, AppColors.brown),
    (AppIcones.despesas, AppColors.red),
  ];

  group('Grade de pagamento', () {
    // Regressão: nome + bandeira passavam da altura do botão (o texto herdava
    // a altura de linha 1,43 do tema), e selecionado, com borda de 2px, pior.
    // Um estouro de layout faz o teste falhar sozinho.
    testWidgets('Cartões selecionado cabe no botão', (tester) async {
      await montar(tester, '${PaymentTypes.maquinaRede} Master Débito');
      expect(tester.takeException(), isNull);
    });

    testWidgets('selecionar não tira o ícone da linha dos outros', (tester) async {
      await montar(tester, PaymentTypes.dinheiro);
      final xs = {
        for (final (icone, _) in formas) tester.getTopLeft(find.byIcon(icone)).dx,
      };

      // Duas colunas, cada uma com todos os icones no mesmo x — inclusive o do
      // card selecionado, que tem borda mais grossa.
      expect(xs, hasLength(2));
    });

    testWidgets('cada card mostra o ícone da sua forma, na cor dela', (tester) async {
      // Com o Pix escolhido: a cor nao depende de estar selecionado.
      await montar(tester, PaymentTypes.pix);

      for (final (icone, cor) in formas) {
        final widget = tester.widget<Icon>(find.byIcon(icone));
        expect(widget.color, cor, reason: 'cor do icone $icone');
      }
    });

    testWidgets('o escolhido ganha o ✓, e só ele', (tester) async {
      await montar(tester, PaymentTypes.requisicao);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // O ✓ fica no quadrado do icone da forma escolhida.
      final check = tester.getCenter(find.byIcon(Icons.check_rounded));
      final icone = tester.getRect(find.byIcon(AppIcones.requisicao));
      expect((check - icone.center).distance, lessThan(40));
    });

    // Em testes separados: montadas uma depois da outra no mesmo teste, o card
    // animaria o recuo de uma versao para a outra — coisa que no app nao
    // acontece, porque cada tela usa sempre a mesma.
    testWidgets('mostra a linha de apoio', (tester) async {
      await montar(tester, PaymentTypes.dinheiro);
      expect(find.text('Espécie'), findsOneWidget);
    });

    testWidgets('a versão compacta não tem linha de apoio e cabe', (tester) async {
      await montar(tester, '${PaymentTypes.maquinaRede} Master Débito', compacto: true);
      expect(find.text('Espécie'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // Celular pequeno (375pt) com o card mais cheio escolhido: nada estoura.
    testWidgets('cabe num celular de 375pt', (tester) async {
      tester.view.physicalSize = const Size(375 * 3, 812 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: PaymentGrid(
                tipoAtivo: '${PaymentTypes.maquinaRede} Master Crédito',
                bandeiraCartaoAtiva: 'Master Crédito',
                onSelecionarTipo: (_) {},
                onAbrirSeletorCartoes: () {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
