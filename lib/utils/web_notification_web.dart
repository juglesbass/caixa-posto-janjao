import 'dart:js_interop';

@JS('Notification.requestPermission')
external JSPromise<JSString>? _requestPermissionJs();

@JS('Notification')
extension type JSNotification._(JSObject _) implements JSObject {
  external factory JSNotification(JSString title, [JSObject? options]);
}

void requestNotificationPermission() {
  try {
    _requestPermissionJs();
  } catch (_) {}
}

void showSystemNotification(String title, String body) {
  try {
    final opts = {
      'body': body,
      'icon': 'icons/Icon-192.png',
    }.jsify();
    JSNotification(title.toJS, opts as JSObject);
  } catch (_) {}
}
