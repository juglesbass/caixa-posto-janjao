// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void requestNotificationPermission() {
  try {
    if (html.Notification.supported) {
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
