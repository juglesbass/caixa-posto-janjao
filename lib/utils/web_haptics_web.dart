// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void triggerWebVibrate(dynamic pattern) {
  try {
    final nav = js.context['navigator'];
    if (nav != null && nav.hasProperty('vibrate')) {
      nav.callMethod('vibrate', [pattern]);
    }
  } catch (_) {}
}
