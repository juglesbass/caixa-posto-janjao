import 'dart:io';

import 'package:caixa_posto_janjao/models/totais_turno.dart';
import 'package:caixa_posto_janjao/models/turno.dart';
import 'package:caixa_posto_janjao/screens/summary_screen.dart';
import 'package:caixa_posto_janjao/services/database_service.dart';
import 'package:caixa_posto_janjao/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Turno turno;
  late TotaisTurno totais;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    await databaseFactory.setDatabasesPath(Directory.systemTemp.createTempSync('caixa_teste_').path);
  });

  Future<void> esperar(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
    }
  }

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(440 * 3, 2600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      final db = DatabaseService.instance;
      turno = await db.obterTurnoAberto() ?? await db.abrirNovoTurno('Agildo Gomes');
      if ((await db.obterLancamentos(turno.id!)).isEmpty) {
        await db.inserirLancamento(turno.id!, 'Dinheiro', 60, '');
        await db.inserirLancamento(turno.id!, 'Rede Master Crédito', 255.71, '');
      }
      totais = await db.obterTotaisTurno(turno.id!);
    });
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: SummaryScreen(turno: turno, totais: totais, onTurnoAlterado: () {}),
    ));
    await esperar(tester);
  }

  testWidgets('sem venda do sistema, não mostra sobra: pede o valor', (tester) async {
    await abrir(tester);

    expect(find.text('SOBRA NA PISTA'), findsNothing);
    expect(find.text('FALTA NA PISTA'), findsNothing);
    expect(find.textContaining('Digite as vendas do sistema'), findsOneWidget);
  });

  testWidgets('com a venda do sistema, mostra pista fechada, sobra ou falta', (tester) async {
    await abrir(tester);
    final campo = find.widgetWithText(TextFormField, 'Vendas do sistema (relatório PDV)');

    await tester.enterText(campo, '31571'); // R$ 315,71 = total da pista
    await tester.pump();
    expect(find.text('PISTA FECHADA'), findsOneWidget);

    await tester.enterText(campo, '30000'); // R$ 300,00
    await tester.pump();
    expect(find.text('SOBRA NA PISTA'), findsOneWidget);

    await tester.enterText(campo, '40000'); // R$ 400,00
    await tester.pump();
    expect(find.text('FALTA NA PISTA'), findsOneWidget);

    // Deixa o salvamento com atraso terminar antes de encerrar o teste.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 700)));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('blocos, total de cartões e as ações continuam lá', (tester) async {
    await abrir(tester);

    expect(find.text('CARTÕES E VOUCHERS'), findsOneWidget);
    expect(find.text('OUTRAS FORMAS DE PAGAMENTO'), findsOneWidget);
    expect(find.text('Total cartões e vouchers'), findsOneWidget);
    for (final acao in ['Encerrar turno e enviar ao gerente', 'WhatsApp', 'Copiar texto', 'Baixar PDF', 'Excel (CSV)', 'Fechar']) {
      expect(find.text(acao), findsOneWidget, reason: acao);
    }
  });

  testWidgets('tocar numa bandeira abre o detalhe dela', (tester) async {
    await abrir(tester);
    // O nome fica num texto composto com a quantidade ("Rede Master Crédito  1×").
    await tester.tap(find.textContaining('Rede Master Crédito', findRichText: true));
    await esperar(tester);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
