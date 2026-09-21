import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  /// Digitos de largura fixa.
  ///
  /// Numa coluna de dinheiro o "1" passa a ocupar o mesmo espaco do "8", entao
  /// os valores alinham pela virgula como na bobina do encerrante. Nao muda
  /// nenhum numero, nenhuma conta e nenhum layout: muda so o desenho do digito.
  static const List<FontFeature> numerosAlinhados = [FontFeature.tabularFigures()];

  /// Aplica os digitos alinhados em toda a escala de texto do tema, para que
  /// qualquer Text do app herde sem precisar lembrar disso em cada tela.
  static TextTheme _alinharNumeros(TextTheme base) {
    TextStyle? comNumeros(TextStyle? estilo) =>
        estilo?.copyWith(fontFeatures: numerosAlinhados);
    return base.copyWith(
      displayLarge: comNumeros(base.displayLarge),
      displayMedium: comNumeros(base.displayMedium),
      displaySmall: comNumeros(base.displaySmall),
      headlineLarge: comNumeros(base.headlineLarge),
      headlineMedium: comNumeros(base.headlineMedium),
      headlineSmall: comNumeros(base.headlineSmall),
      titleLarge: comNumeros(base.titleLarge),
      titleMedium: comNumeros(base.titleMedium),
      titleSmall: comNumeros(base.titleSmall),
      bodyLarge: comNumeros(base.bodyLarge),
      bodyMedium: comNumeros(base.bodyMedium),
      bodySmall: comNumeros(base.bodySmall),
      labelLarge: comNumeros(base.labelLarge),
      labelMedium: comNumeros(base.labelMedium),
      labelSmall: comNumeros(base.labelSmall),
    );
  }

  static ThemeData darkTheme() {
    final padrao = ThemeData(brightness: Brightness.dark);
    return ThemeData(
      brightness: Brightness.dark,
      textTheme: _alinharNumeros(padrao.textTheme),
      scaffoldBackgroundColor: AppColors.darkBg,
      primaryColor: AppColors.accent,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accentLight,
        surface: AppColors.darkSurface,
        error: AppColors.red,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.darkTextPri,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: AppColors.darkTextPri),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSheetBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.radiusXl)),
        ),
      ),
    );
  }

  static ThemeData lightTheme() {
    final padrao = ThemeData(brightness: Brightness.light);
    return ThemeData(
      brightness: Brightness.light,
      textTheme: _alinharNumeros(padrao.textTheme),
      scaffoldBackgroundColor: AppColors.lightBg,
      primaryColor: AppColors.accent,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        secondary: AppColors.accentLight,
        surface: AppColors.lightSurface,
        error: AppColors.red,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.lightTextPri,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: AppColors.lightTextPri),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSheetBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.radiusXl)),
        ),
      ),
    );
  }
}
