import 'dart:io';

import 'package:caixa_posto_janjao/models/totais_turno.dart';
import 'package:caixa_posto_janjao/models/turno.dart';
import 'package:caixa_posto_janjao/screens/summary_screen.dart';
import 'package:caixa_posto_janjao/services/database_service.dart';
import 'package:caixa_posto_janjao/theme/app_theme.dart';
import 'package:caixa_posto_janjao/utils/currency_formatter.dart';
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
        await db.inserirLancamento(turno.id!, 'Pag Pix', 100, '');
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

    await tester.enterText(campo, '41571'); // R$ 415,71 = total da pista
    await tester.pump();
    expect(find.text('PISTA FECHADA'), findsOneWidget);

    await tester.enterText(campo, '30000'); // R$ 300,00
    await tester.pump();
    expect(find.text('SOBRA NA PISTA'), findsOneWidget);

    await tester.enterText(campo, '50000'); // R$ 500,00
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

  // Em "Outras formas" só o Pix abre detalhe: sem a seta, o valor dele fica
  // na mesma coluna dos outros. A linha continua abrindo ao toque.
  testWidgets('Pix sem seta, alinhado com o dinheiro, e ainda abre o detalhe', (tester) async {
    await abrir(tester);
    final valorPix = find.text(CurrencyFormatter.formatar(100));
    final valorDinheiro = find.text(CurrencyFormatter.formatar(60));
    expect(tester.getRect(valorPix).right, tester.getRect(valorDinheiro).right);

    final linhaPix = find.ancestor(of: valorPix, matching: find.byType(InkWell)).first;
    expect(find.descendant(of: linhaPix, matching: find.byIcon(Icons.chevron_right_rounded)), findsNothing);
    // As bandeiras de cartão seguem com a seta.
    final linhaCartao = find.ancestor(
      of: find.textContaining('Rede Master Crédito', findRichText: true),
      matching: find.byType(InkWell),
    ).first;
    expect(find.descendant(of: linhaCartao, matching: find.byIcon(Icons.chevron_right_rounded)), findsOneWidget);

    await tester.tap(valorPix);
    await esperar(tester);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  // Detalhe da bandeira: corrigir um valor pela lista grava no banco.
  testWidgets('editar pelo detalhe grava o valor novo', (tester) async {
    await abrir(tester);
    await tester.tap(find.textContaining('Rede Master Crédito', findRichText: true));
    await esperar(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar valor').first);
    await tester.pumpAndSettle();
    expect(find.text('Editar lançamento'), findsOneWidget);

    // O campo de valor da janela (atrás dela está o das vendas do sistema).
    final campoValor = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)).first;
    await tester.enterText(campoValor, '26000'); // R$ 260,00
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    }

    expect(find.text('Editar lançamento'), findsNothing);
    final lancamentos = await tester.runAsync(() => DatabaseService.instance.obterLancamentos(turno.id!));
    final cartao = lancamentos!.firstWhere((l) => l.tipo == 'Rede Master Crédito');
    expect(cartao.valor, 260);

    // Volta ao valor de antes para não mexer nos outros testes.
    await tester.runAsync(() => DatabaseService.instance
        .atualizarLancamento(cartao.id!, turno.id!, cartao.tipo, 255.71, cartao.descricao));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('excluir pelo detalhe pede confirmação e cancelar não apaga', (tester) async {
    await abrir(tester);
    await tester.tap(find.textContaining('Rede Master Crédito', findRichText: true));
    await esperar(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Excluir lançamento').first);
    await tester.pumpAndSettle();
    expect(find.text('Excluir lançamento?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    final lancamentos = await tester.runAsync(() => DatabaseService.instance.obterLancamentos(turno.id!));
    expect(lancamentos!.where((l) => l.tipo == 'Rede Master Crédito'), hasLength(1));
  });

  testWidgets('detalhe da bandeira cabe num celular de 375pt', (tester) async {
    await abrir(tester);
    tester.view.physicalSize = const Size(375 * 3, 812 * 3);
    await tester.pump();
    await tester.tap(find.textContaining('Rede Master Crédito', findRichText: true));
    await esperar(tester);
    await tester.pumpAndSettle();
    expect(find.text('Canhotos físicos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
