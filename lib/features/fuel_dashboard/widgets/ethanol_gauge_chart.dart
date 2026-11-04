import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// ============================================================================
/// MOSTRADOR CIRCULAR DE ETANOL (ETHANOL GAUGE CHART)
/// ============================================================================
///
/// Medidor animado de telemetria automotiva (0% a 100%):
/// - Arco de fundo escuro com marcas de graduação (ticks).
/// - Arco ativo com efeito Neon Glow cuja cor se altera dinamicamente
///   conforme o nível de etanol no tanque:
///     • 0% a 25%:  Vermelho Coral -> Laranja Âmbar (Predominância de Gasolina)
///     • 25% a 50%: Laranja Âmbar  -> Amarelo Ouro  (Gasolina Comum E27 / Flex Inicial)
///     • 50% a 75%: Amarelo Ouro   -> Verde-Lima    (Mistura Flex Intermediária)
///     • 75% a 100%: Verde-Lima    -> Verde Neon    (Predominância de Etanol)
/// - Suporte a estado de carregamento / polling da ECU.
class EthanolGaugeChart extends StatefulWidget {
  final double? percentage;
  final bool isLoading;

  const EthanolGaugeChart({
    super.key,
    required this.percentage,
    this.isLoading = false,
  });

  /// Calcula a cor dinâmica do medidor de acordo com o nível atual (0% a 100%).
  static Color colorForLevel(double pct) {
    final double clamped = pct.clamp(0.0, 100.0);
    if (clamped <= 25.0) {
      // Faixa 0% - 25%: Vermelho Alerta -> Laranja Gasolina
      return Color.lerp(
        AppColors.alertRed,
        AppColors.gasolineNeon,
        clamped / 25.0,
      )!;
    } else if (clamped <= 50.0) {
      // Faixa 25% - 50%: Laranja Gasolina -> Amarelo Ouro
      return Color.lerp(
        AppColors.gasolineNeon,
        const Color(0xFFFFD60A),
        (clamped - 25.0) / 25.0,
      )!;
    } else if (clamped <= 75.0) {
      // Faixa 50% - 75%: Amarelo Ouro -> Verde-Lima
      return Color.lerp(
        const Color(0xFFFFD60A),
        const Color(0xFF88E235),
        (clamped - 50.0) / 25.0,
      )!;
    } else {
      // Faixa 75% - 100%: Verde-Lima -> Verde Etanol Neon
      return Color.lerp(
        const Color(0xFF88E235),
        AppColors.ethanolNeon,
        (clamped - 75.0) / 25.0,
      )!;
    }
  }

  @override
  State<EthanolGaugeChart> createState() => _EthanolGaugeChartState();
}

class _EthanolGaugeChartState extends State<EthanolGaugeChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;
  double _oldPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.percentage ?? 0.0,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant EthanolGaugeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.percentage != oldWidget.percentage) {
      _oldPercentage = _animation.value;
      _animation = Tween<double>(
        begin: _oldPercentage,
        end: widget.percentage ?? 0.0,
      ).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Curves.easeOutCubic,
        ),
      );
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.15,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final double currentVal = _animation.value;
          final bool hasValue = widget.percentage != null;
          // Cor dinâmica conforme o nível animado atual
          final Color activeColor = EthanolGaugeChart.colorForLevel(currentVal);

          return CustomPaint(
            painter: _GaugePainter(
              percentage: currentVal,
              hasValue: hasValue,
              activeColor: activeColor,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  if (widget.isLoading && !hasValue) ...[
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.ethanolNeon,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Lendo ECU...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else if (hasValue) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          currentVal.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '%',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: activeColor,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isLoading) ...[
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: activeColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          widget.isLoading ? 'ATUALIZANDO...' : 'ETANOL',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w800,
                            color: activeColor,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Icon(
                      Icons.bluetooth_searching_rounded,
                      size: 36,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'SEM LEITURA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percentage;
  final bool hasValue;
  final Color activeColor;

  _GaugePainter({
    required this.percentage,
    required this.hasValue,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.52);
    final radius = size.width * 0.40;

    // Arco de 260 graus (de 140° a 400° / 40°)
    const startAngle = 140 * (math.pi / 180);
    const sweepAngle = 260 * (math.pi / 180);

    // 1. ARCO DE FUNDO (Track escuro)
    final bgPaint = Paint()
      ..color = const Color(0xFF20232B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // 2. ARCO ATIVO COM COR DINÂMICA POR NÍVEL (PROGRESSO + NEON GLOW)
    if (hasValue && percentage > 0) {
      final activeSweep = sweepAngle * (percentage.clamp(0.0, 100.0) / 100.0);

      // Glow suave de fundo acompanhando a cor do nível atual
      final glowPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        glowPaint,
      );

      // Linha principal neon com a cor do nível atual
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        activePaint,
      );
    }

    // 3. MARCAS DE GRADUAÇÃO INTERNAS (TICKS DE 0% A 100%)
    for (int i = 0; i <= 10; i++) {
      final double tickPct = i * 10.0;
      final bool isPassed = hasValue && percentage >= tickPct;

      final tickPaint = Paint()
        ..color = isPassed
            ? activeColor.withValues(alpha: 0.75)
            : const Color(0xFF454B5C)
        ..strokeWidth = 2;

      final tickAngle = startAngle + (sweepAngle * (i / 10));
      final inner = Offset(
        center.dx + (radius - 18) * math.cos(tickAngle),
        center.dy + (radius - 18) * math.sin(tickAngle),
      );
      final outer = Offset(
        center.dx + (radius - 10) * math.cos(tickAngle),
        center.dy + (radius - 10) * math.sin(tickAngle),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.hasValue != hasValue ||
        oldDelegate.activeColor != activeColor;
  }
}
