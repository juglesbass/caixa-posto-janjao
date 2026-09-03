import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'web_haptics.dart';

/// Gerenciador unificado de feedback tátil (Haptics) compatível com Mobile e PWA Web.
/// Calibrado para vibrações muito suaves, discretas e refinadas ("bem suave").
class AppHaptics {
  static bool _habilitado = true;
  static bool _carregado = false;

  /// Carrega as preferências salvas do usuário
  static Future<void> inicializar() async {
    if (_carregado) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _habilitado = prefs.getBool('app_haptics_habilitado') ?? true;
      _carregado = true;
    } catch (_) {}
  }

  static bool get habilitado => _habilitado;

  static Future<void> setHabilitado(bool valor) async {
    _habilitado = valor;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_haptics_habilitado', valor);
    } catch (_) {}
  }

  /// Feedback tátil ultra suave e sutil (clique de botão, atalho de valor, chip, card)
  static void light() {
    if (!_habilitado) return;
    try {
      HapticFeedback.selectionClick();
      triggerWebVibrate(8);
    } catch (_) {}
  }

  /// Feedback de seleção suave (troca de aba, toggle, máquina)
  static void selection() {
    if (!_habilitado) return;
    try {
      HapticFeedback.selectionClick();
      triggerWebVibrate(8);
    } catch (_) {}
  }

  /// Feedback intermediário suave (lançamento confirmado, ação concluída)
  static void medium() {
    if (!_habilitado) return;
    try {
      HapticFeedback.lightImpact();
      triggerWebVibrate(15);
    } catch (_) {}
  }

  /// Feedback de alerta moderado (erro de validação, PIN incorreto)
  static void heavy() {
    if (!_habilitado) return;
    try {
      HapticFeedback.mediumImpact();
      triggerWebVibrate(25);
    } catch (_) {}
  }
}
