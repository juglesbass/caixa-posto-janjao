import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Notificações locais em Android e iOS.
///
/// Toda chamada é tolerante a falha: notificação é conveniência, e um erro aqui
/// nunca pode derrubar o fechamento de turno.

final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

bool _inicializado = false;

bool get _plataformaSuportada =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Canal único de avisos sobre o envio dos PDFs ao Google Drive
const AndroidNotificationDetails _detalhesAndroid = AndroidNotificationDetails(
  'drive_pendencias',
  'Envios ao Google Drive',
  channelDescription:
      'Avisa quando o PDF de fechamento fica pendente por falta de internet e quando ele é entregue.',
  importance: Importance.high,
  priority: Priority.high,
  icon: '@drawable/ic_stat_notify',
);

const DarwinNotificationDetails _detalhesIos = DarwinNotificationDetails(
  presentAlert: true,
  presentBadge: true,
  presentSound: true,
);

const NotificationDetails _detalhes = NotificationDetails(
  android: _detalhesAndroid,
  iOS: _detalhesIos,
);

Future<void> inicializarNotificacoesLocais() async {
  if (_inicializado || !_plataformaSuportada) return;
  try {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_stat_notify'),
      // A permissão no iOS é pedida em solicitarPermissaoNotificacaoLocal(),
      // e não no start do app, para não estourar o prompt na primeira abertura.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    _inicializado = true;
  } catch (e) {
    debugPrint('[Notificações] Falha ao inicializar: $e');
  }
}

Future<void> solicitarPermissaoNotificacaoLocal() async {
  if (!_plataformaSuportada) return;
  try {
    await inicializarNotificacoesLocais();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  } catch (e) {
    debugPrint('[Notificações] Falha ao pedir permissão: $e');
  }
}

Future<void> mostrarNotificacaoLocal({
  required int id,
  required String titulo,
  required String corpo,
}) async {
  if (!_plataformaSuportada) return;
  try {
    await inicializarNotificacoesLocais();
    if (!_inicializado) return;
    await _plugin.show(
      id: id,
      title: titulo,
      body: corpo,
      notificationDetails: _detalhes,
    );
  } catch (e) {
    debugPrint('[Notificações] Falha ao exibir: $e');
  }
}

/// Agenda um aviso para daqui a [daqui], que o sistema mostra mesmo com o app
/// congelado em segundo plano ou fechado.
///
/// É o que cobre o envio cortado no meio: o frentista encerra o turno, abre
/// outro app, e o nosso para de rodar antes de saber se o PDF chegou. Nenhum
/// código nosso roda depois disso — mas o aviso já está entregue ao sistema.
Future<void> agendarNotificacaoLocal({
  required int id,
  required String titulo,
  required String corpo,
  required Duration daqui,
}) async {
  if (!_plataformaSuportada) return;
  try {
    await inicializarNotificacoesLocais();
    if (!_inicializado) return;
    // Em UTC de propósito: só importa "daqui a X minutos", e o UTC já vem
    // embutido no pacote. Carregar a base inteira de fusos só para isso
    // pesaria no app sem mudar o momento em que o aviso aparece.
    final quando = tz.TZDateTime.now(tz.UTC).add(daqui);
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: quando,
      notificationDetails: _detalhes,
      // Inexato basta para um lembrete de minutos, e não exige a permissão de
      // alarme exato, que o Android 14 deixa desligada por padrão.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: titulo,
      body: corpo,
    );
  } catch (e) {
    debugPrint('[Notificações] Falha ao agendar: $e');
  }
}

/// Cancela um aviso agendado ou já exibido com este [id].
Future<void> cancelarNotificacaoLocal(int id) async {
  if (!_plataformaSuportada) return;
  try {
    await inicializarNotificacoesLocais();
    if (!_inicializado) return;
    await _plugin.cancel(id: id);
  } catch (e) {
    debugPrint('[Notificações] Falha ao cancelar: $e');
  }
}
