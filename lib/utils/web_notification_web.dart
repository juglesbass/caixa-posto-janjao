// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void requestNotificationPermission() {
  try {
    if (!html.Notification.supported) return;
    // Só pede quando o usuário ainda não decidiu. Chamar repetidamente (ou já
    // negado/concedido) só gera ruído e alguns navegadores penalizam pedidos
    // feitos fora de um gesto do usuário.
    if (html.Notification.permission == 'default') {
      html.Notification.requestPermission();
    }
  } catch (_) {}
}

void showSystemNotification(String title, String body) {
  try {
    if (html.Notification.supported && html.Notification.permission == 'granted') {
      html.Notification(title, body: body, icon: 'icons/Icon-192.png');
    }
  } catch (_) {}
}
