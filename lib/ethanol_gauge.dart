import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'app_styles.dart';

/// Gauge Chart customizado no estilo velocímetro/medidor automotivo (0 a 100%)
/// para exibir a porcentagem de etanol lida via OBD-II.
class EthanolGaugeChart extends StatelessWidget {
  /// Valor atual de 0.0 a 100.0, ou null quando ainda não há leitura disponível.
  final double? percentage;

  /// Indica se uma leitura/inicialização está em andamento.
  final bool isLoading;

  const EthanolGaugeChart({
    super.key,
    required this.percentage,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasData = percentage != null;
    final double targetValue = (percentage ?? 0.0).clamp(0.0, 100.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: targetValue),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return AspectRatio(
          aspectRatio: 1.08,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _EthanolGaugePainter(
                    value: animatedValue,
                    hasData: hasData,
                  ),
                ),
              ),
              // Valor centralizado dentro do arco do Gauge
              Padding(
                padding: const EdgeInsets.only(top: 18.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasData ? '${animatedValue.toStringAsFixed(1)}%' : '--%',
                      style: TextStyle(
                        color: hasData ? AppTheme.white : AppTheme.muted,
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLoading) ...[
                          const SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: AppTheme.green,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          isLoading ? 'LENDO ECU...' : 'ETANOL',
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EthanolGaugePainter extends CustomPainter {
  final double value;
  final bool hasData;

  _EthanolGaugePainter({
    required this.value,
    required this.hasData,
  });

  // Ângulo inicial: 135° (canto inferior esquerdo) e varredura total de 270° até 45° (inferior direito)
  static const double _startAngle = 3 * math.pi / 4; // 135°
  static const double _totalSweep = 3 * math.pi / 2; // 270°

  // Cores das 4 faixas externas (0-25, 25-50, 50-75, 75-100) fiéis ao estilo Gauge Chart
  static const List<Color> _segmentColors = [
    Color(0xFFF51616), // 0 - 25: Vermelho
    Color(0xFFFF9100), // 25 - 50: Laranja
    Color(0xFFFFEA00), // 50 - 75: Amarelo
    Color(0xFF00A838), // 75 - 100: Verde
  ];

  /// Interpola suavemente a cor do arco principal interno conforme a porcentagem (0..100).
  Color _interpolatedBandColor(double pct) {
    final double clamped = pct.clamp(0.0, 100.0);
    if (clamped <= 25.0) {
      return Color.lerp(
        const Color(0xFFE51C23),
        const Color(0xFFFF9100),
        clamped / 25.0,
      )!;
    } else if (clamped <= 50.0) {
      return Color.lerp(
        const Color(0xFFFF9100),
        const Color(0xFFF5E600),
        (clamped - 25.0) / 25.0,
      )!;
    } else if (clamped <= 75.0) {
      return Color.lerp(
        const Color(0xFFF5E600),
        const Color(0xFF9EC400),
        (clamped - 50.0) / 25.0,
      )!;
    } else {
      return Color.lerp(
        const Color(0xFF9EC400),
        const Color(0xFF00C853),
        (clamped - 75.0) / 25.0,
      )!;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 0.56);
    final double maxRadius = math.min(size.width * 0.46, size.height * 0.52);

    // Espessuras proporcionais ao tamanho disponível
    final double outerStroke = maxRadius * 0.085;
    final double ringGap = maxRadius * 0.042;
    final double innerStroke = maxRadius * 0.22;

    final double labelRadius = maxRadius * 0.95;
    final double outerRadius = maxRadius * 0.80;
    final double innerRadius =
        outerRadius - (outerStroke / 2) - ringGap - (innerStroke / 2);

    final Color activeColor = _interpolatedBandColor(value);

    // 1. Brilho radial suave no centro (fiel ao efeito luminoso central do Gauge Chart)
    if (hasData) {
      final Rect glowRect = Rect.fromCircle(
        center: center,
        radius: innerRadius + innerStroke * 0.4,
      );
      final Paint glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            activeColor.withValues(alpha: 0.24),
            activeColor.withValues(alpha: 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(glowRect);
      canvas.drawCircle(center, innerRadius + innerStroke * 0.4, glowPaint);
    }

    // 2. Anel externo dividido em 4 faixas (0-25, 25-50, 50-75, 75-100) com pontas arredondadas
    final Rect outerRect = Rect.fromCircle(center: center, radius: outerRadius);
    final double segmentSweep = _totalSweep / 4;
    // Compensação angular do StrokeCap.round + espaçamento limpo entre as faixas
    final double outerCapAngle = (outerStroke / 2) / outerRadius;
    final double gapPadding = outerCapAngle + 0.022;

    for (int i = 0; i < 4; i++) {
      final double segStart = _startAngle + (i * segmentSweep) + gapPadding;
      final double segSweep = segmentSweep - (2 * gapPadding);
      final Color segColor = _segmentColors[i];

      // Sombra/glow externo discreto de cada faixa
      final Paint segGlowPaint = Paint()
        ..color = segColor.withValues(alpha: hasData ? 0.28 : 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerStroke * 1.35
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawArc(outerRect, segStart, segSweep, false, segGlowPaint);

      // Traço principal da faixa externa
      final Paint segPaint = Paint()
        ..color = hasData ? segColor : segColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerStroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(outerRect, segStart, segSweep, false, segPaint);
    }

    // 3. Arco principal interno espesso
    final Rect innerRect = Rect.fromCircle(center: center, radius: innerRadius);
    final double innerCapAngle = (innerStroke / 2) / innerRadius;
    // Alinha visualmente as pontas arredondadas do arco interno com os extremos 0 e 100 do externo
    final double innerInset = math.max(0.0, innerCapAngle - outerCapAngle + gapPadding);
    final double innerStart = _startAngle + innerInset;
    final double innerSweep = _totalSweep - (2 * innerInset);

    final Paint innerTrackPaint = Paint()
      ..color = hasData ? activeColor : const Color(0xFF1E1E1E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = innerStroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(innerRect, innerStart, innerSweep, false, innerTrackPaint);

    // Sombra interna sutil na borda côncava para dar profundidade 3D ao anel espesso
    final double shadowRadius = innerRadius - (innerStroke * 0.36);
    final Paint innerDepthPaint = Paint()
      ..color = Colors.black.withValues(alpha: hasData ? 0.22 : 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = innerStroke * 0.24
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: shadowRadius),
      innerStart,
      innerSweep,
      false,
      innerDepthPaint,
    );

    // 4. Rótulos da escala (0, 25, 50, 75, 100) ao redor do anel externo
    const List<int> ticks = [0, 25, 50, 75, 100];
    for (final int tick in ticks) {
      final double fraction = tick / 100.0;
      final double angle = _startAngle + (fraction * _totalSweep);

      final Offset labelPos = Offset(
        center.dx + math.cos(angle) * labelRadius,
        center.dy + math.sin(angle) * labelRadius,
      );

      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: '$tick',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: maxRadius * 0.105,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset(labelPos.dx - tp.width / 2, labelPos.dy - tp.height / 2),
      );
    }

    // 5. Ponteiro / Marcador em cápsula branca (estilo pino radial sobre o anel espesso)
    if (hasData) {
      final double clamped = value.clamp(0.0, 100.0);
      // Mapeia 0..100 linearmente com as marcas 0, 25, 50, 75, 100 mantendo as extremidades sobre o arco
      final double rawAngle = _startAngle + (clamped / 100.0) * _totalSweep;
      final double pointerAngle = rawAngle.clamp(
        _startAngle + 0.04,
        _startAngle + _totalSweep - 0.04,
      );
      final Offset dir = Offset(math.cos(pointerAngle), math.sin(pointerAngle));

      final Offset pInner = center + dir * (innerRadius - innerStroke * 0.56);
      final Offset pOuter = center + dir * (innerRadius + innerStroke * 0.56);

      // Sombra difusa do ponteiro
      final Paint needleShadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..strokeWidth = maxRadius * 0.068
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawLine(pInner, pOuter, needleShadowPaint);

      // Contorno escuro nítido da cápsula
      final Paint needleBorderPaint = Paint()
        ..color = const Color(0xFF1A1A1A)
        ..strokeWidth = maxRadius * 0.058
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(pInner, pOuter, needleBorderPaint);

      // Preenchimento branco puro da cápsula
      final Paint needleFillPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = maxRadius * 0.038
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(pInner, pOuter, needleFillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EthanolGaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.hasData != hasData;
  }
}
