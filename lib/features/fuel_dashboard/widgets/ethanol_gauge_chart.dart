import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// ============================================================================
/// MOSTRADOR CIRCULAR DE ETANOL (ETHANOL GAUGE CHART)
/// ============================================================================
///
/// Medidor animado de telemetria automotiva (0% a 100%):
/// - Arco de fundo escuro com marcas de graduação (ticks).
/// - Arco ativo em Verde Neon com efeito glow reluzente.
/// - Suporte a estado de carregamento / polling da ECU.
class EthanolGaugeChart extends StatefulWidget {
  final double? percentage;
  final bool isLoading;

  const EthanolGaugeChart({
    super.key,
    required this.percentage,
    this.isLoading = false,
  });

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
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.percentage ?? 0.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
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
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ));
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

          return CustomPaint(
            painter: _GaugePainter(
              percentage: currentVal,
              hasValue: widget.percentage != null,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  if (widget.isLoading) ...[
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
                  ] else if (widget.percentage != null) ...[
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
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Text(
                          '%',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ethanolNeon,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'ETANOL',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ethanolNeon,
                      ),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.power_off_rounded,
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

  _GaugePainter({
    required this.percentage,
    required this.hasValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.52);
    final radius = size.width * 0.40;

    // Arco de 220 graus (de 160° a 380° / 20°)
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

    // 2. ARCO ATIVO EM VERDE NEON (PROGRESSO)
    if (hasValue && percentage > 0) {
      final activeSweep = sweepAngle * (percentage.clamp(0.0, 100.0) / 100.0);

      // Glow suave de fundo
      final glowPaint = Paint()
        ..color = AppColors.ethanolNeon.withValues(alpha: 0.35)
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

      // Linha principal neon
      final activePaint = Paint()
        ..color = AppColors.ethanolNeon
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

    // 3. MARCAS DE GRADUAÇÃO (TICKS)
    final tickPaint = Paint()
      ..color = const Color(0xFF454B5C)
      ..strokeWidth = 2;

    for (int i = 0; i <= 10; i++) {
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
    return oldDelegate.percentage != percentage || oldDelegate.hasValue != hasValue;
  }
}
