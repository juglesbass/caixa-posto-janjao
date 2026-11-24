import 'dart:io';

import 'package:caixa_posto_janjao/models/totais_turno.dart';
import 'package:caixa_posto_janjao/models/turno.dart';
import 'package:caixa_posto_janjao/screens/home_screen.dart';
import 'package:caixa_posto_janjao/services/database_service.dart';
import 'package:caixa_posto_janjao/theme/app_theme.dart';
import 'package:caixa_posto_janjao/utils/payment_types.dart';
import 'package:caixa_posto_janjao/widgets/confirmacao_lancamento.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Turno turno;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    await databaseFactory.setDatabasesPath(
      Directory.systemTemp.createTempSync('caixa_confirmacao_').path,
    );
    await DatabaseService.instance.database;
  });

  tearDown(ConfirmacaoLancamento.fechar);

  testWidgets('lançar venda exibe confirmação com valor e forma e recolhe o foco do campo', (tester) async {
    tester.view.physicalSize = const Size(440 * 3, 956 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      final db = DatabaseService.instance;
      turno = await db.obterTurnoAberto() ?? await db.abrirNovoTurno('Agildo Gomes');
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(),
        home: HomeScreen(
          turno: turno,
          totais: TotaisTurno(),
          onRecarregar: () {},
          onAbrirResumo: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Seleciona Pag Pix, foca o campo de valor e digita R$ 50,00
    await tester.tap(find.text(PaymentTypes.pix));
    await tester.pump();

    final campoValor = find.byType(TextField).first;
    await tester.tap(campoValor);
    await tester.pump();
    await tester.enterText(campoValor, '5000');
    await tester.pump();

    // Campo está focado (teclado aberto) antes de lançar
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

    await tester.tap(find.text('LANÇAR'));
    for (var i = 0; i < 40 && find.textContaining('lançado em').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }

    // 1. Notificação de confirmação apareceu com valor e forma de pagamento
    expect(find.textContaining('50,00'), findsWidgets);
    expect(find.textContaining('lançado em'), findsOneWidget);
    expect(find.textContaining(PaymentTypes.pix), findsWidgets);

    // 2. O campo perdeu o foco de forma consistente após lançar (teclado fecha)
    final textFieldWidget = tester.widget<TextField>(campoValor);
    expect(textFieldWidget.focusNode?.hasFocus, isFalse);

    // 3. A notificação some sozinha após o tempo configurado
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.textContaining('lançado em'), findsNothing);
  });

  testWidgets('nova confirmação substitui a anterior sem empilhar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Column(
              children: [
                ElevatedButton(
                  onPressed: () => ConfirmacaoLancamento.mostrar(
                    ctx,
                    valor: 25,
                    tipo: PaymentTypes.dinheiro,
                  ),
                  child: const Text('um'),
                ),
                ElevatedButton(
                  onPressed: () => ConfirmacaoLancamento.mostrar(
                    ctx,
                    valor: 90,
                    tipo: 'Rede Visa Crédito',
                  ),
                  child: const Text('dois'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('um'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('25,00'), findsOneWidget);

    await tester.tap(find.text('dois'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('25,00'), findsNothing);
    expect(find.textContaining('90,00'), findsOneWidget);
    expect(find.textContaining('Rede Visa Crédito'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.textContaining('90,00'), findsNothing);
  });
}
