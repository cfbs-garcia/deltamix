import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// Tema global escuro (Dark Neon Theme) para o Deltamix.
/// 
/// Configurado especificamente para emular telas automotivas de alto contraste
/// com iluminação neon verde, âmbar e ciano sobre superfícies pretas/grafites.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // TOKENS ESTÁTICOS DE CONVENIÊNCIA (COMPATIBILIDADE DIRETA DE DESIGN)
  // ---------------------------------------------------------------------------
  static const Color bg = Color(0xFF0B0B0B);
  static const Color surface = Color(0xFF161616);
  static const Color green = AppColors.ethanolNeon; // 0xFF00FF66
  static const Color white = Colors.white;
  static const Color muted = Color(0xFF888888);

  static const TextStyle logo = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,

      // Paleta principal do Material
      colorScheme: const ColorScheme.dark(
        primary: AppColors.ethanolNeon,
        onPrimary: AppColors.textOnNeon,
        primaryContainer: AppColors.ethanolDark,
        onPrimaryContainer: Colors.white,
        secondary: AppColors.gasolineNeon,
        onSecondary: Colors.black,
        tertiary: AppColors.obdCyan,
        onTertiary: Colors.black,
        error: AppColors.alertRed,
        onError: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),

      // Barra superior (AppBar)
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),

      // Botões principais (Pill-shaped Neon Green Button, idêntico à referência)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ethanolNeon,
          foregroundColor: AppColors.textOnNeon,
          elevation: 6,
          shadowColor: AppColors.ethanolGlow,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // Botões secundários (Outlined)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ethanolNeon,
          side: const BorderSide(color: AppColors.borderActive, width: 1.5),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Campos de Entrada (Inputs com fundo grafite e cantos arredondados)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceInput,
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.ethanolNeon, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.alertRed, width: 1.5),
        ),
      ),

      // Cartões e Paineis (Cards)
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
        selectedItemColor: AppColors.ethanolNeon,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),

      // Switches, Checkboxes e Sliders
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.ethanolNeon;
          return AppColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.ethanolDark;
          return AppColors.surfaceInput;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.ethanolNeon;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.textOnNeon),
        side: const BorderSide(color: AppColors.textMuted, width: 1.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),

      // Divisores
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 24,
      ),
    );
  }
}
