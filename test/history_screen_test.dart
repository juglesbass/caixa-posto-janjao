import 'dart:io';

import 'package:caixa_posto_janjao/dialogs/edit_launch_dialog.dart';
import 'package:caixa_posto_janjao/models/turno.dart';
import 'package:caixa_posto_janjao/screens/history_screen.dart';
import 'package:caixa_posto_janjao/services/database_service.dart';
import 'package:caixa_posto_janjao/theme/app_theme.dart';
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
    // Banco de teste numa pasta so deste arquivo (os testes rodam em paralelo).
    await databaseFactory.setDatabasesPath(Directory.systemTemp.createTempSync('caixa_teste_').path);
  });

  Future<void> esperar(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
    }
  }

  Future<void> abrir(WidgetTester tester, Turno t) async {
    tester.view.physicalSize = const Size(440 * 3, 956 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: HistoryScreen(turno: t),
    ));
    await esperar(tester);
  }

  testWidgets('lista, filtra, e o filtro de Sangria só aparece com sangria antiga', (tester) async {
    await tester.runAsync(() async {
      final db = DatabaseService.instance;
      turno = await db.obterTurnoAberto() ?? await db.abrirNovoTurno('Agildo Gomes');
      await db.inserirLancamento(turno.id!, 'Dinheiro', 60, 'Troco');
      await db.inserirLancamento(turno.id!, 'Pag Pix', 80, '');
      await db.inserirLancamento(turno.id!, 'Rede Master Crédito', 255.71, '');
    });
    await abrir(tester, turno);

    expect(find.text('3 lançamentos neste turno'), findsOneWidget);
    expect(find.text('Sangria'), findsNothing);

    await tester.tap(find.text('Cartões'));
    await tester.pump();
    expect(find.text('Rede Master Crédito'), findsOneWidget);
    // "Dinheiro" tambem e o nome de um filtro; "Pag Pix" so existe na linha.
    expect(find.text('Pag Pix'), findsNothing);

    await tester.tap(find.text('Todos'));
    await tester.pump();

    await tester.runAsync(() => DatabaseService.instance.inserirLancamento(turno.id!, 'Sangria', 200, ''));
    await esperar(tester);
    expect(find.text('Sangria'), findsOneWidget);
  });

  testWidgets('tocar num lançamento abre a correção', (tester) async {
    await abrir(tester, turno);
    await tester.tap(find.text('Pag Pix'));
    await tester.pumpAndSettle();
    expect(find.byType(EditLaunchDialog), findsOneWidget);
  });

  testWidgets('turno fechado não deixa corrigir', (tester) async {
    final fechado = Turno(
      id: turno.id,
      numero: turno.numero,
      data: turno.data,
      operador: turno.operador,
      aberto: false,
      fechadoEm: '22/09/2026 23:00:00',
      vendasSistema: 0,
      observacao: '',
      fundoCaixa: 0,
      versao: 1,
    );
    await abrir(tester, fechado);
    expect(find.text('FECHADO'), findsOneWidget);

    await tester.tap(find.text('Pag Pix'));
    await tester.pumpAndSettle();
    expect(find.byType(EditLaunchDialog), findsNothing);
    expect(find.textContaining('Turno fechado'), findsOneWidget);
  });

  // Aba escondida não relê o turno a cada lançamento do Início; ao ser aberta
  // de novo, mostra o que entrou enquanto estava escondida.
  testWidgets('escondido não relê; ao voltar, mostra o que entrou', (tester) async {
    tester.view.physicalSize = const Size(440 * 3, 956 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Widget tela(bool ativo) => MaterialApp(
          theme: AppTheme.lightTheme(),
          home: HistoryScreen(turno: turno, ativo: ativo),
        );
    await tester.pumpWidget(tela(false));
    await esperar(tester);
    final antes = find.textContaining('lançamentos neste turno').evaluate().length;
    expect(antes, 1);

    await tester.runAsync(() => DatabaseService.instance.inserirLancamento(turno.id!, 'Requisição', 45, ''));
    await esperar(tester);
    expect(find.text('Requisição'), findsNothing);

    await tester.pumpWidget(tela(true));
    await esperar(tester);
    expect(find.text('Requisição'), findsOneWidget);
  });
}
