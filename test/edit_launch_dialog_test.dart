import 'package:caixa_posto_janjao/dialogs/edit_launch_dialog.dart';
import 'package:caixa_posto_janjao/models/lancamento.dart';
import 'package:caixa_posto_janjao/theme/app_theme.dart';
import 'package:caixa_posto_janjao/utils/payment_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ({String tipo, double valor, String descricao})? salvo;
  late bool excluido;

  Future<void> abrir(WidgetTester tester, Lancamento l, {double largura = 440}) async {
    tester.view.physicalSize = Size(largura * 3, 956 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    salvo = null;
    excluido = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: ctx,
                  builder: (_) => EditLaunchDialog(
                    lancamento: l,
                    maquinaAtiva: PaymentTypes.maquinaRede,
                    onSalvar: (d) => salvo = d,
                    onDeletar: () => excluido = true,
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

  Lancamento lanc(String tipo, double valor, {String desc = ''}) =>
      Lancamento(id: 1, turnoId: 1, tipo: tipo, valor: valor, descricao: desc, hora: '18:55:02', dataHora: '');

  group('Corrigir lançamento', () {
    testWidgets('troca a forma e salva com o mesmo valor e descrição', (tester) async {
      await abrir(tester, lanc(PaymentTypes.dinheiro, 60, desc: 'Placa ABC'));

      await tester.tap(find.text('Pag Pix'));
      await tester.pump();
      await tester.tap(find.text('Salvar correção'));
      await tester.pumpAndSettle();

      expect(salvo, isNotNull);
      expect(salvo!.tipo, PaymentTypes.pix);
      expect(salvo!.valor, 60);
      expect(salvo!.descricao, 'Placa ABC');
    });

    testWidgets('sem valor, não salva e avisa', (tester) async {
      await abrir(tester, lanc(PaymentTypes.dinheiro, 60));

      await tester.enterText(find.byType(TextField).first, '');
      await tester.tap(find.text('Salvar correção'));
      await tester.pump();

      expect(salvo, isNull);
      expect(find.text('Informe um valor maior que zero'), findsOneWidget);
    });

    // Sangria saiu do app, mas um lançamento antigo de sangria continua sendo
    // uma sangria se ninguém escolher outra forma.
    testWidgets('tipo antigo que não está na grade é mantido', (tester) async {
      await abrir(tester, lanc(PaymentTypes.sangria, 200));
      expect(find.textContaining('Forma atual: Sangria'), findsOneWidget);

      await tester.tap(find.text('Salvar correção'));
      await tester.pumpAndSettle();

      expect(salvo!.tipo, PaymentTypes.sangria);
    });

    testWidgets('bandeira escolhida vai para a máquina ativa', (tester) async {
      await abrir(tester, lanc(PaymentTypes.dinheiro, 90));

      await tester.tap(find.text('Cartões'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Visa Crédito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar correção'));
      await tester.pumpAndSettle();

      expect(salvo!.tipo, '${PaymentTypes.maquinaRede} Visa Crédito');
    });

    testWidgets('excluir pede confirmação antes de apagar', (tester) async {
      await abrir(tester, lanc(PaymentTypes.pix, 80));

      await tester.tap(find.byTooltip('Excluir lançamento'));
      await tester.pumpAndSettle();
      expect(excluido, isFalse);

      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(excluido, isTrue);
    });

    testWidgets('cabe num celular de 375pt', (tester) async {
      await abrir(tester, lanc('Cielo VR Multibenefícios', 500), largura: 375);
      expect(tester.takeException(), isNull);
    });
  });
}
