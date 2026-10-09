import 'package:flutter/material.dart';

class AppTheme {
  // Cores principais
  static const Color bg = Color(0xFF0B0B0B);
  static const Color surface = Color(0xFF121212);
  static const Color navBg = Color(0xFF161616);
  static const Color green = Color(0xFF00FF66);
  static const Color white = Colors.white;
  static const Color muted = Colors.white54;

  // Textos comuns
  static const TextStyle logo = TextStyle(
    color: white,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  // Decoração padrão para Inputs
// No seu app_styles.dart, altere o hintText para labelText:
static InputDecoration input(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: muted, fontSize: 14),
    prefixIcon: Icon(icon, color: muted, size: 20),
    filled: true,
    fillColor: surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: green)),
  );
}

  // Estilo padrão para Botões
  static ButtonStyle button = ElevatedButton.styleFrom(
    backgroundColor: green,
    foregroundColor: Colors.black,
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
  );
}