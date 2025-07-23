import 'package:flutter/material.dart';
import 'dart:math' as math;

class ListeningBlobWidget extends StatefulWidget {
  const ListeningBlobWidget({super.key});

  @override
  State<ListeningBlobWidget> createState() => _ListeningBlobWidgetState();
}

class _ListeningBlobWidgetState extends State<ListeningBlobWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _morphController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _morphController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _morphController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D4FF).withValues(alpha: 0.15),
            const Color(0xFF20B2AA).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00D4FF).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated listening blob
          AnimatedBuilder(
            animation: Listenable.merge([_pulseController, _morphController]),
            builder: (context, child) {
              return CustomPaint(
                size: const Size(24, 24),
                painter: ListeningBlobPainter(
                  pulseProgress: _pulseController.value,
                  morphProgress: _morphController.value,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Text(
            'Listening...',
            style: TextStyle(
              color: const Color(0xFF00D4FF),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class ListeningBlobPainter extends CustomPainter {
  final double pulseProgress;
  final double morphProgress;

  ListeningBlobPainter({
    required this.pulseProgress,
    required this.morphProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 3;

    // Create pulsing blob with STT-specific styling
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF00D4FF), const Color(0xFF20B2AA)],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 2));

    // Pulse effect
    final pulseRadius =
        baseRadius * (1.0 + 0.5 * math.sin(pulseProgress * 2 * math.pi));

    // Create organic blob shape
    final path = Path();
    const pointCount = 8;

    for (int i = 0; i <= pointCount; i++) {
      final angle = (i / pointCount) * 2 * math.pi;
      final waveOffset =
          math.sin(morphProgress * 4 * math.pi + angle * 3) * 0.3;
      final radius = pulseRadius * (1.0 + waveOffset);

      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ListeningBlobPainter oldDelegate) {
    return oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.morphProgress != morphProgress;
  }
}
