import 'dart:io';

import 'package:caixa_posto_janjao/dialogs/analytics_dialog.dart';
import 'package:caixa_posto_janjao/models/operador_model.dart';
import 'package:caixa_posto_janjao/models/totais_turno.dart';
import 'package:caixa_posto_janjao/models/turno.dart';
import 'package:caixa_posto_janjao/screens/gerencia/gestao_operadores_screen.dart';
import 'package:caixa_posto_janjao/screens/settings_screen.dart';
import 'package:caixa_posto_janjao/screens/validar_screen.dart';
import 'package:caixa_posto_janjao/services/operadores_sync_service.dart';
import 'package:caixa_posto_janjao/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fonte de verdade no lugar da fonte de teste (bem mais larga), para que
/// medir estouro diga algo sobre o aparelho.
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

// Área do desenvolvedor e tela pública de validação, no visual novo: mesmas
// ações, cabendo num celular estreito. Nada aqui fala com a nuvem de verdade:
// no teste, toda chamada HTTP recebe 400.
void main() {
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
  final totais = TotaisTurno(dinheiro: 60, pix: 80, qtdPix: 1, cartoes: 2589.97, qtdCartoes: 9, totalGeral: 2729.97);

  setUpAll(() async {
    await _fonteReal();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(Directory.systemTemp.createTempSync('caixa_teste_').path);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void tela(WidgetTester tester, {double largura = 375}) {
    tester.view.physicalSize = Size(largura * 3, 812 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('Menu: "Desenvolvedor" pede o PIN Mestre e confere os 4 dígitos', (tester) async {
    tela(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme(),
      home: SettingsScreen(
        turno: turno,
        totais: totais,
        isDark: true,
        onMudarTema: (_) {},
        onAbrirNovoTurno: () {},
        onAbrirResumo: () {},
        onRecarregar: () {},
      ),
    ));
    await tester.tap(find.text('Desenvolvedor'));
    await tester.pumpAndSettle();
    expect(find.text('Informe o PIN Mestre (4 dígitos)'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text('Acessar Painel'));
    await tester.pump();
    expect(find.text('Informe os 4 dígitos do PIN'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Acessar Painel'), findsNothing);
  });

  group('Gestão de Operadores', () {
    setUp(() {
      final agora = DateTime(2026, 9, 22, 14, 30);
      OperadoresSyncService.operadoresNotifier.value = [
        for (final n in ['Agildo Gomes', 'Bruno Costa'])
          OperadorModel(id: 'op_$n', nome: n, pinHash: 'x', atualizadoEm: agora),
        OperadorModel(id: 'op_luiz', nome: 'Luiz Diego', pinHash: 'x', atualizadoEm: agora, ativo: false),
      ];
    });

    Future<void> abrir(WidgetTester tester) async {
      tela(tester);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme(), home: const GestaoOperadoresScreen(isDark: true)));
      await tester.pump();
    }

    // A tela liga uma sincronização periódica; tirá-la da árvore a desliga.
    Future<void> fechar(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      // Esperas curtas que a sincronização deixou no relógio do teste.
      await tester.pump(const Duration(minutes: 1));
    }

    testWidgets('lista ativos e inativos e cabe em 375pt', (tester) async {
      await abrir(tester);
      expect(find.text('Bruno Costa'), findsOneWidget);
      expect(find.text('ATIVO'), findsNWidgets(2));
      expect(find.text('INATIVO'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await fechar(tester);
    });

    testWidgets('tocar no operador abre as ações dele', (tester) async {
      await abrir(tester);
      await tester.tap(find.text('Bruno Costa'));
      await tester.pumpAndSettle();
      expect(find.text('Excluir Operador'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await fechar(tester);
    });

    testWidgets('novo operador sem nome não salva', (tester) async {
      await abrir(tester);
      await tester.tap(find.text('Novo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar Operador'));
      await tester.pump();
      expect(find.text('Novo Operador'), findsOneWidget);
      expect(find.textContaining('mín. 3 letras'), findsOneWidget);
      await fechar(tester);
    });
  });

  testWidgets('Analytics mostra o total e cabe em 375pt', (tester) async {
    tela(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(context: ctx, builder: (_) => AnalyticsDialog(turno: turno, totais: totais)),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2.729,97'), findsOneWidget);
    expect(find.text('Cartões'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Validar: chave desconhecida aparece como não encontrada', (tester) async {
    tela(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme(),
      home: const ValidarScreen(authHash: 'AUTH-1A2B-3C4D-5E6F'),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
    }
    expect(find.text('Documento não encontrado ou Chave Inválida'), findsOneWidget);
    expect(find.textContaining('Formato de chave reconhecido'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
