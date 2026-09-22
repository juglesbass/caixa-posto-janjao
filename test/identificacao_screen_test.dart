import 'dart:io';

import 'package:caixa_posto_janjao/dialogs/cadastro_pin_dialog.dart';
import 'package:caixa_posto_janjao/models/operador_model.dart';
import 'package:caixa_posto_janjao/screens/identificacao_screen.dart';
import 'package:caixa_posto_janjao/services/operadores_sync_service.dart';
import 'package:caixa_posto_janjao/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fonte de verdade no lugar da fonte de teste (bem mais larga), para que
/// medir tamanho e estouro diga algo sobre o aparelho.
Future<void> _fonteReal() async {
  final dir = '${Platform.environment['HOME']}/development/flutter/bin/cache/artifacts/material_fonts';
  if (!File('$dir/Roboto-Regular.ttf').existsSync()) return;
  for (final familia in ['Roboto', 'FlutterTest']) {
    final loader = FontLoader(familia);
    for (final peso in ['Regular', 'Medium', 'Bold', 'Black']) {
      final bytes = File('$dir/Roboto-$peso.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    await _fonteReal();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(Directory.systemTemp.createTempSync('caixa_teste_').path);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final agora = DateTime(2026, 9, 22);
    OperadoresSyncService.operadoresNotifier.value = [
      for (final n in ['Agildo Gomes', 'Alessandro', 'Bruno Costa', 'Frankson', 'João Victor', 'Luiz Diego'])
        OperadorModel(id: 'op_$n', nome: n, pinHash: 'x', atualizadoEm: agora),
    ];
  });

  Future<void> abrir(WidgetTester tester, {double largura = 440}) async {
    tester.view.physicalSize = Size(largura * 3, 956 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme(),
      home: const IdentificacaoScreen(novoTurno: true),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
    }
  }

  // Operador sem PIN salvo neste aparelho: o toque leva ao cadastro do PIN
  // (primeiro acesso), nunca direto para o caixa.
  testWidgets('lista os operadores e o toque leva ao PIN', (tester) async {
    await abrir(tester);
    expect(find.text('Bruno Costa'), findsOneWidget);

    await tester.tap(find.text('Bruno Costa'));
    // A tela espera um quadro (relogio do teste) e depois consulta o PIN
    // guardado (relogio real): avanca os dois.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    }
    await tester.pumpAndSettle();
    expect(find.byType(CadastroPinDialog), findsOneWidget);
  });

  // Tela de troca de turno: toque com pressa. Antes os botoes tinham ~33pt.
  testWidgets('botões de operador têm pelo menos 44pt de altura', (tester) async {
    await abrir(tester);
    final botao = find.ancestor(of: find.text('Frankson'), matching: find.byType(InkWell)).first;
    expect(tester.getSize(botao).height, greaterThanOrEqualTo(44));
  });

  testWidgets('cabe num celular de 375pt', (tester) async {
    await abrir(tester, largura: 375);
    expect(tester.takeException(), isNull);
  });
}
