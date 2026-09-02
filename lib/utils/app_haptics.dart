import 'package:flutter/services.dart';
import 'web_haptics.dart';

/// Gerenciador unificado de feedback tátil (Haptics) compatível com Mobile e PWA Web
class AppHaptics {
  /// Feedback tátil ultra suave e rápido (clique de botão, atalho de valor, chip)
  static void light() {
    try {
      HapticFeedback.lightImpact();
      triggerWebVibrate(20);
    } catch (_) {}
  }

  /// Feedback de seleção (troca de aba, toggle, máquina)
  static void selection() {
    try {
      HapticFeedback.selectionClick();
      HapticFeedback.lightImpact();
      triggerWebVibrate(15);
    } catch (_) {}
  }

  /// Feedback intermediário (lançamento confirmado, ação concluída)
  static void medium() {
    try {
      HapticFeedback.mediumImpact();
      triggerWebVibrate(35);
    } catch (_) {}
  }

  /// Feedback pesado / alerta (erro de validação, PIN incorreto)
  static void heavy() {
    try {
      HapticFeedback.heavyImpact();
      triggerWebVibrate([40, 40, 40]);
    } catch (_) {}
  }
}
