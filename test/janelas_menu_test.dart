import 'dart:io';

import 'package:caixa_posto_janjao/dialogs/bloqueio_dialog.dart';
import 'package:caixa_posto_janjao/dialogs/cadastro_pin_dialog.dart';
import 'package:caixa_posto_janjao/dialogs/drive_failure_dialog.dart';
import 'package:caixa_posto_janjao/dialogs/encerrantes_dialog.dart';
import 'package:caixa_posto_janjao/dialogs/reset_dialog.dart';
import 'package:caixa_posto_janjao/dialogs/trocar_pin_dialog.dart';
import 'package:caixa_posto_janjao/dialogs/turnos_anteriores_dialog.dart';
import 'package:caixa_posto_janjao/models/turno.dart';
import 'package:caixa_posto_janjao/screens/consulta_produtos_screen.dart';
import 'package:caixa_posto_janjao/services/database_service.dart';
import 'package:caixa_posto_janjao/services/notification_service.dart';
import 'package:caixa_posto_janjao/theme/app_theme.dart';
import 'package:caixa_posto_janjao/widgets/pending_sync_banner.dart';
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

// Janelas que se abrem pelo Menu e pelo fechamento, no visual novo: as
// mesmas ações de antes, e cabendo num celular estreito.
void main() {
  late Turno turno;

  setUpAll(() async {
    await _fonteReal();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(Directory.systemTemp.createTempSync('caixa_teste_').path);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> esperar(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> abrir(WidgetTester tester, WidgetBuilder janela, {double largura = 440, bool escuro = true}) async {
    tester.view.physicalSize = Size(largura * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      final db = DatabaseService.instance;
      turno = await db.obterTurnoAberto() ?? await db.abrirNovoTurno('Agildo Gomes');
    });
    await tester.pumpWidget(MaterialApp(
      theme: escuro ? AppTheme.darkTheme() : AppTheme.lightTheme(),
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(context: ctx, builder: janela),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pump();
    await esperar(tester);
  }

  group('Encerrantes', () {
    testWidgets('litros viram o total do bico, e salvar grava', (tester) async {
      await abrir(tester, (_) => EncerrantesDialog(turnoId: turno.id!));
      expect(find.text('Encerrantes de Bombas'), findsOneWidget);

      // Bico 01: gasolina a 5,89 por padrão.
      await tester.enterText(find.widgetWithText(TextField, 'Litros Vendidos').first, '10');
      await tester.pump();
      expect(find.textContaining('58,90'), findsWidgets);

      await tester.tap(find.text('Salvar Encerrantes'));
      await esperar(tester);
      await tester.pumpAndSettle();
      expect(find.text('Encerrantes de Bombas'), findsNothing);

      final salvos = await tester.runAsync(() => DatabaseService.instance.obterEncerrantes(turno.id!));
      final bico1 = salvos!.firstWhere((e) => e['bico'] == 'Bico 01');
      expect((bico1['final'] as num).toDouble(), 10);
    });

    testWidgets('cabe num celular de 375pt, claro e escuro', (tester) async {
      await abrir(tester, (_) => EncerrantesDialog(turnoId: turno.id!), largura: 375);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      await abrir(tester, (_) => EncerrantesDialog(turnoId: turno.id!), largura: 375, escuro: false);
      expect(tester.takeException(), isNull);
    });
  });

  group('Histórico de Turnos', () {
    testWidgets('lista os turnos; reabrir pede confirmação e PIN', (tester) async {
      // Um turno fechado e um aberto.
      await tester.runAsync(() async {
        final db = DatabaseService.instance;
        final t = await db.obterTurnoAberto() ?? await db.abrirNovoTurno('Agildo Gomes');
        await db.fecharTurno(t.id!, vendasSistema: 100);
        await db.abrirNovoTurno('Bruno Costa');
      });
      await abrir(tester, (_) => TurnosAnterioresDialog(onReabrirTurno: (_) {}));
      expect(find.text('Agildo Gomes'), findsOneWidget);
      expect(find.text('Bruno Costa'), findsOneWidget);
      expect(find.text('EM ANDAMENTO'), findsOneWidget);

      await tester.tap(find.text('Reabrir'));
      await esperar(tester);
      await tester.pumpAndSettle();
      expect(find.text('Fechar o turno atual?'), findsOneWidget);

      await tester.tap(find.text('Fechar e reabrir'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Reabrir Turno #'), findsOneWidget);
      expect(find.text('Autorizar Reabertura'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Autorizar Reabertura'), findsNothing);
      expect(find.text('Histórico de Turnos'), findsOneWidget);
    });

    testWidgets('cabe num celular de 375pt', (tester) async {
      await abrir(tester, (_) => TurnosAnterioresDialog(onReabrirTurno: (_) {}), largura: 375);
      expect(tester.takeException(), isNull);
    });
  });

  group('Falha do Drive', () {
    testWidgets('mostra o motivo e as duas saídas, e cabe em 375pt', (tester) async {
      await abrir(
        tester,
        (_) => DriveFailureDialog(
          turnoNumero: 12,
          operador: 'Agildo Gomes',
          mensagemErro: 'O Google demorou a responder.',
          onSincronizado: () {},
        ),
        largura: 375,
      );
      expect(find.text('O Google demorou a responder.'), findsOneWidget);
      expect(find.text('Tentar Enviar Novamente Agora'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Entendido, Enviar Mais Tarde'));
      await tester.pumpAndSettle();
      expect(find.text('Envio Pendente para o Drive'), findsNothing);
    });
  });

  group('Pendências', () {
    tearDown(() => NotificationService.pendenciasCount.value = 0);

    testWidgets('aviso só aparece com pendência, com o botão Reenviar', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme(),
        home: const Scaffold(body: PendingSyncBanner()),
      ));
      expect(find.text('Reenviar'), findsNothing);

      NotificationService.pendenciasCount.value = 2;
      await tester.pump();
      expect(find.text('2 PDF(s) pendente(s) no Drive'), findsOneWidget);
      expect(find.text('Reenviar'), findsOneWidget);
    });

    testWidgets('zerar tudo fica bloqueado enquanto houver PDF pendente', (tester) async {
      NotificationService.pendenciasCount.value = 1;
      await abrir(tester, (_) => ResetDialog(onResetConcluido: () {}));
      expect(find.text('Enviar ao Drive'), findsOneWidget);
      expect(find.text('Sim, Zerar Tudo'), findsNothing);

      NotificationService.pendenciasCount.value = 0;
      await tester.pump();
      expect(find.text('Sim, Zerar Tudo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Consulta de Produtos', () {
    testWidgets('busca pelo código, copia ao tocar e limpa filtros', (tester) async {
      tester.view.physicalSize = const Size(375 * 3, 812 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      String? copiado;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copiado = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme(), home: const ConsultaProdutosScreen()));
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), '488');
      await tester.pump();
      expect(find.text('ADITIVO RAD IPI PRONTO 1L'), findsOneWidget);

      await tester.tap(find.text('ADITIVO RAD IPI PRONTO 1L'));
      await tester.pump();
      expect(copiado, '00488');
      expect(find.textContaining('Código 00488 copiado'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();
      expect(find.text('Nenhum produto encontrado'), findsOneWidget);
      await tester.tap(find.text('Limpar Filtros'));
      await tester.pump();
      expect(find.text('Nenhum produto encontrado'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('PIN', () {
    testWidgets('bloqueio: PIN errado mostra o erro, e a tela cabe em 375pt', (tester) async {
      await abrir(tester, (_) => const BloqueioDialog(operador: 'Agildo Gomes'), largura: 375);
      expect(find.text('Caixa bloqueado'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '12');
      await tester.tap(find.text('Desbloquear Caixa'));
      await esperar(tester);
      expect(find.text('PIN Incorreto. Acesso Negado!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('trocar PIN: PIN atual errado mostra o erro', (tester) async {
      await abrir(tester, (_) => const TrocarPinDialog(operador: 'Agildo Gomes'), largura: 375);
      await tester.enterText(find.byType(TextField).first, '12');
      await tester.tap(find.text('Salvar Novo PIN'));
      await esperar(tester);
      expect(find.textContaining('PIN atual incorreto'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cadastro de PIN confere tamanho e confirmação', (tester) async {
      await abrir(tester, (_) => const CadastroPinDialog(operador: 'Bruno Costa', obrigatorio: true), largura: 375);
      final botao = find.text('Confirmar e Cadastrar PIN');

      await tester.enterText(find.byType(TextField).first, '12');
      await tester.tap(botao);
      await tester.pump();
      expect(find.text('O PIN deve ter exatamente 4 números'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '1234');
      await tester.enterText(find.byType(TextField).last, '1235');
      await tester.tap(botao);
      await tester.pump();
      expect(find.text('Os PINs digitados não coincidem'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
