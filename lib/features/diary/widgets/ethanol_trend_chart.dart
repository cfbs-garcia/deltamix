import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Gráfico de linha simples (sem dependências) da % de etanol ao longo do tempo.
/// O eixo vertical é fixo de 0% a 100%.
class EthanolTrendChart extends StatelessWidget {
  final List<double> values; // do mais antigo para o mais recente
  final double height;

  const EthanolTrendChart({super.key, required this.values, this.height = 150});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _TrendPainter(values)),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> values;
  _TrendPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPad = 36;
    const double topPad = 8;
    const double bottomPad = 6;
    final chart = Rect.fromLTWH(
      leftPad,
      topPad,
      size.width - leftPad,
      size.height - topPad - bottomPad,
    );

    double yFor(double pct) =>
        chart.bottom - chart.height * (pct.clamp(0.0, 100.0) / 100.0);

    // Linhas de grade + rótulos do eixo Y
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (final level in const [0, 50, 100]) {
      final y = yFor(level.toDouble());
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: '$level%',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    if (values.isEmpty) return;

    final dx = values.length > 1 ? chart.width / (values.length - 1) : 0.0;
    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          values.length > 1 ? chart.left + dx * i : chart.center.dx,
          yFor(values[i]),
        ),
    ];

    if (points.length > 1) {
      final line = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        line.lineTo(p.dx, p.dy);
      }

      // Área preenchida sob a linha
      final area = Path.from(line)
        ..lineTo(points.last.dx, chart.bottom)
        ..lineTo(points.first.dx, chart.bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.ethanolNeon.withValues(alpha: 0.28),
              AppColors.ethanolNeon.withValues(alpha: 0.0),
            ],
          ).createShader(chart),
      );

      // Linha principal
      canvas.drawPath(
        line,
        Paint()
          ..color = AppColors.ethanolNeon
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Ponto da última leitura, com brilho
    final last = points.last;
    canvas.drawCircle(
      last,
      9,
      Paint()..color = AppColors.ethanolNeon.withValues(alpha: 0.25),
    );
    canvas.drawCircle(last, 4.5, Paint()..color = AppColors.ethanolNeon);
    canvas.drawCircle(last, 2, Paint()..color = AppColors.background);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.values != values;
}
