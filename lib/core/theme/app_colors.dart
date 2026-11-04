import 'package:flutter/material.dart';

/// Paleta de cores do Deltamix no estilo Dark Neon / Cyber-Automotive.
/// 
/// Inspirada em painéis de telemetria automotiva e na estética Dark Neon:
/// - Verde Neon: Representa Etanol (Eco, Renovável, Potência Flex) e Ações Principais.
/// - Âmbar/Laranja Neon: Representa Gasolina (Combustão clássica, densidade energética).
/// - Ciano Neon: Representa Conexão OBD-II / Bluetooth e Telemetria em tempo real.
/// - Grafite & Ônix: Fundos profundos e cartões foscos de alto contraste.
abstract class AppColors {
  // ==========================================
  // FUNDOS E SUPERFÍCIES (Dark / OLED)
  // ==========================================
  /// Fundo principal da aplicação (Preto Ônix profundo)
  static const Color background = Color(0xFF0F1115);

  /// Fundo de cartões, painéis e scaffolds elevados
  static const Color surface = Color(0xFF181A20);

  /// Cartões internos e modais com destaque
  static const Color surfaceCard = Color(0xFF1F222A);

  /// Fundo de campos de texto (Inputs) e chips desativados
  static const Color surfaceInput = Color(0xFF262A34);

  /// Linhas de divisão, bordas e separadores sutis
  static const Color border = Color(0xFF2F3441);

  /// Borda de foco em campos normais
  static const Color borderActive = Color(0xFF3E4554);

  // ==========================================
  // CORES DE COMBUSTÍVEL E DESTAQUE (NEON ACCENTS)
  // ==========================================

  /// [ETANOL / BRAND] Verde Neon vibrante (Cor principal do App)
  /// Usado em botões principais, % de etanol alto e medidores ecológicos.
  static const Color ethanolNeon = Color(0xFF00FF66);
  static const Color ethanolGlow = Color(0x5500FF66);
  static const Color ethanolDark = Color(0xFF00B347);

  /// [GASOLINA] Âmbar / Laranja Neon
  /// Usado para percentual de gasolina, alertas de proporção e indicadores térmicos.
  static const Color gasolineNeon = Color(0xFFFF9F1C);
  static const Color gasolineGlow = Color(0x55FF9F1C);
  static const Color gasolineDark = Color(0xFFD97706);

  /// [OBD-II / BLUETOOTH] Ciano Elétrico Neon
  /// Usado para status de pareamento, taxa de polling e telemetria de sensores.
  static const Color obdCyan = Color(0xFF00E5FF);
  static const Color obdCyanGlow = Color(0x5500E5FF);

  /// [ALERTA / RESERVA] Coral Neon
  /// Usado para falhas na ECU, tanque na reserva ou erro no scanner.
  static const Color alertRed = Color(0xFFFF3B56);
  static const Color dangerNeon = alertRed;
  static const Color alertRedGlow = Color(0x55FF3B56);

  // ==========================================
  // TIPOGRAFIA E ÍCONES
  // ==========================================
  /// Texto de alto contraste (Títulos e leituras principais)
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Texto secundário (Legendas e unidades de medida km/h, L)
  static const Color textSecondary = Color(0xFF9EACB9);

  /// Texto esmaecido (Placeholders e timestamps)
  static const Color textMuted = Color(0xFF5E6573);

  /// Texto escuro aplicado sobre botões verde neon
  static const Color textOnNeon = Color(0xFF0A120D);

  // ==========================================
  // GRADIENTES
  // ==========================================

  /// Gradiente de mistura de combustível (Etanol -> Gasolina)
  /// Perfeito para barras de progresso do tanque Flex e mostradores (Gauges).
  static const LinearGradient fuelBlendGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      ethanolNeon,
      Color(0xFF88E235), // Tom de transição intermediário
      gasolineNeon,
    ],
  );

  /// Gradiente sutil para cartões de telemetria com profundidade
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF222630),
      Color(0xFF181A20),
    ],
  );

  /// Gradiente neon para o botão principal
  static const LinearGradient neonButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00FF7F),
      Color(0xFF00E65B),
    ],
  );

  // ==========================================
  // SOMBRAS COM EFEITO NEON GLOW (BRILHO)
  // ==========================================

  /// Efeito de luz neon verde emitida por botões e medidores ativos
  static List<BoxShadow> get ethanolNeonShadow => [
        BoxShadow(
          color: ethanolNeon.withValues(alpha: 0.35),
          blurRadius: 18,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
      ];

  /// Efeito de luz neon âmbar para medidores de gasolina
  static List<BoxShadow> get gasolineNeonShadow => [
        BoxShadow(
          color: gasolineNeon.withValues(alpha: 0.35),
          blurRadius: 18,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
      ];

  /// Efeito de luz ciano para cartões de conexão Bluetooth
  static List<BoxShadow> get obdNeonShadow => [
        BoxShadow(
          color: obdCyan.withValues(alpha: 0.30),
          blurRadius: 16,
          spreadRadius: 1,
          offset: const Offset(0, 4),
        ),
      ];
}
