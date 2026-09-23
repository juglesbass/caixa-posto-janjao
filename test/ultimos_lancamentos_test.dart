import 'dart:io';

import 'package:caixa_posto_janjao/models/turno.dart';
import 'package:caixa_posto_janjao/services/database_service.dart';
import 'package:caixa_posto_janjao/theme/app_theme.dart';
import 'package:caixa_posto_janjao/widgets/ultimos_lancamentos.dart';
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
    // Banco de teste numa pasta so deste arquivo: os arquivos de teste rodam
    // em paralelo e nao podem dividir (nem apagar) o mesmo banco.
    await databaseFactory.setDatabasesPath(Directory.systemTemp.createTempSync('caixa_teste_').path);
  });

  /// Cor de fundo da linha que mostra este valor.
  Color corDaLinha(WidgetTester tester, String valor) {
    final linha = find.ancestor(of: find.textContaining(valor), matching: find.byType(AnimatedContainer));
    final deco = tester.widget<AnimatedContainer>(linha.first).decoration! as BoxDecoration;
    return deco.color!;
  }

  Future<void> esperarBanco(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
    }
  }

  testWidgets('lançamento feito fora da tela (pelo "+") aparece na lista', (tester) async {
    await tester.runAsync(() async {
      final db = DatabaseService.instance;
      turno = await db.obterTurnoAberto() ?? await db.abrirNovoTurno('Agildo Gomes');
      await db.inserirLancamento(turno.id!, 'Dinheiro', 60, '');
    });

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: Scaffold(
        body: UltimosLancamentos(
          turno: turno,
          maquinaAtiva: 'Rede',
        ),
      ),
    ));
    await esperarBanco(tester);
    expect(find.textContaining('60,00'), findsOneWidget);

    await tester.runAsync(() => DatabaseService.instance.inserirLancamento(turno.id!, 'Pag Pix', 80, ''));
    await esperarBanco(tester);

    expect(find.textContaining('80,00'), findsOneWidget);

    // O novo entra aceso; o que ja estava na tela, nao.
    expect(corDaLinha(tester, '80,00').a, greaterThan(0));
    expect(corDaLinha(tester, '60,00').a, 0);

    // E apaga sozinho depois de um instante. O lancamento veio de fora do
    // relogio simulado do teste (como vem do "+"), entao o temporizador corre
    // no relogio real: espera de verdade.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1800)));
    await tester.pumpAndSettle();
    expect(corDaLinha(tester, '80,00').a, 0);
  });
}
