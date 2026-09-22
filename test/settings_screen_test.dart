import 'dart:io';

import 'package:caixa_posto_janjao/models/totais_turno.dart';
import 'package:caixa_posto_janjao/models/turno.dart';
import 'package:caixa_posto_janjao/screens/settings_screen.dart';
import 'package:caixa_posto_janjao/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(Directory.systemTemp.createTempSync('caixa_teste_').path);
  });
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

  late List<String> chamadas;

  Future<void> abrir(WidgetTester tester, {bool escuro = true}) async {
    tester.view.physicalSize = const Size(440 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    chamadas = [];
    await tester.pumpWidget(MaterialApp(
      theme: escuro ? AppTheme.darkTheme() : AppTheme.lightTheme(),
      home: SettingsScreen(
        turno: turno,
        totais: TotaisTurno(),
        isDark: escuro,
        onMudarTema: (v) => chamadas.add('tema:$v'),
        onAbrirNovoTurno: () => chamadas.add('trocarOperador'),
        onAbrirResumo: () => chamadas.add('resumo'),
        onRecarregar: () {},
        onFechar: () => chamadas.add('fechar'),
      ),
    ));
    await tester.pump();
  }

  testWidgets('todos os itens continuam no Menu', (tester) async {
    await abrir(tester);
    for (final item in [
      'Desenvolvedor',
      'Encerrantes de Bombas',
      'Tabela de Códigos / Produtos',
      'Bloquear Caixa',
      'Sincronizar com Google Drive',
      'Alterar Meu PIN',
      'Fechar Caixa & Resumo',
      'Histórico de Turnos',
      'Ativar Tema Claro',
      'Trocar / Sair do Operador',
      'Voltar ao Caixa',
    ]) {
      expect(find.text(item), findsOneWidget, reason: item);
    }
    // A sangria saiu do app.
    expect(find.textContaining('Sangria'), findsNothing);
  });

  testWidgets('os atalhos chamam o que chamavam', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Fechar Caixa & Resumo'));
    await tester.tap(find.text('Ativar Tema Claro'));
    await tester.tap(find.text('Trocar / Sair do Operador'));
    await tester.tap(find.text('Voltar ao Caixa'));
    expect(chamadas, ['resumo', 'tema:false', 'trocarOperador', 'fechar']);
  });

  testWidgets('a área restrita pede autorização antes de abrir', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Desenvolvedor'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
  });
}
