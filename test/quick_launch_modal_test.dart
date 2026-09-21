import 'package:caixa_posto_janjao/dialogs/quick_launch_modal.dart';
import 'package:caixa_posto_janjao/theme/app_theme.dart';
import 'package:caixa_posto_janjao/utils/payment_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ({String tipo, double valor, String descricao})? lancado;

  /// Abre o lançamento rápido do jeito que o app abre: numa folha por cima.
  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(440 * 3, 956 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    lancado = null;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: ctx,
                  isScrollControlled: true,
                  builder: (_) => QuickLaunchModal(
                    maquinaAtiva: PaymentTypes.maquinaRede,
                    onLancar: (dados) => lancado = dados,
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  group('Lançamento rápido', () {
    // Regressão: aqui os atalhos substituíam o valor, enquanto na tela Início
    // somavam — e o próprio botão diz "+".
    testWidgets('os atalhos somam e o lançamento leva forma e valor', (tester) async {
      await abrir(tester);

      await tester.tap(find.text('+10'));
      await tester.tap(find.text('+20'));
      await tester.tap(find.text('Pag Pix'));
      await tester.pump();
      await tester.tap(find.text('LANÇAR'));
      await tester.pumpAndSettle();

      expect(lancado, isNotNull);
      expect(lancado!.valor, 30);
      expect(lancado!.tipo, PaymentTypes.pix);
    });

    testWidgets('sem valor, não lança e avisa', (tester) async {
      await abrir(tester);

      // Sem valor o botão nem aparece; o Enter do teclado tenta lançar.
      expect(find.text('LANÇAR'), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(lancado, isNull);
      expect(find.text('Informe um valor maior que zero'), findsOneWidget);
    });

    testWidgets('abre com Dinheiro escolhido e cabe sem estourar', (tester) async {
      await abrir(tester);

      expect(tester.takeException(), isNull);
      await tester.tap(find.text('+50'));
      await tester.pump();
      await tester.tap(find.text('LANÇAR'));
      await tester.pumpAndSettle();

      expect(lancado!.tipo, PaymentTypes.dinheiro);
    });
  });
}
