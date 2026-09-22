import 'dart:io';

import 'package:caixa_posto_janjao/dialogs/close_shift_dialog.dart';
import 'package:caixa_posto_janjao/models/totais_turno.dart';
import 'package:caixa_posto_janjao/models/turno.dart';
import 'package:caixa_posto_janjao/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Carrega a fonte de verdade (Roboto, a do Android e do PWA) no lugar da
/// fonte de teste, que e bem mais larga: sem isso, medir se uma linha estoura
/// a largura nao diz nada sobre o aparelho.
Future<void> _fonteReal() async {
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['HOME']}/development/flutter'}'
      '/bin/cache/artifacts/material_fonts';
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
  setUpAll(_fonteReal);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final turno = Turno(
    id: 1,
    numero: 1,
    data: '22/09/2026 06:00',
    operador: 'Agildo Gomes',
    aberto: true,
    vendasSistema: 0,
    observacao: '',
    fundoCaixa: 0,
    versao: 1,
  );
  final totais = TotaisTurno(dinheiro: 60, cartoes: 2589.97, totalGeral: 2649.97);

  Future<void> abrir(WidgetTester tester, {double largura = 440}) async {
    tester.view.physicalSize = Size(largura * 3, 1000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme(),
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: ctx,
                builder: (_) => CloseShiftDialog(turno: turno, totais: totais, onConfirmarFechamento: (_) {}),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('sem venda do sistema, não mostra sobra; com ela, mostra', (tester) async {
    await abrir(tester);
    expect(find.text('Agildo Gomes'), findsWidgets);
    expect(find.text('SOBRA NA PISTA'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Vendas Sistema (Relatório PDV)'), '260000');
    await tester.pump();
    expect(find.text('SOBRA NA PISTA'), findsOneWidget);
  });

  testWidgets('cabe num celular de 375pt', (tester) async {
    await abrir(tester, largura: 375);
    expect(tester.takeException(), isNull);
  });
}
