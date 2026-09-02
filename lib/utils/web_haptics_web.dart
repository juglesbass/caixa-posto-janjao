// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void triggerWebVibrate(dynamic pattern) {
  try {
    if (html.window.navigator.vibrate != null) {
      html.window.navigator.vibrate(pattern);
    }
  } catch (_) {}
}
