import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:math' as math;
import '../../bloc/chat_bloc.dart';
import '../../bloc/chat_event.dart';
import '../../bloc/chat_state.dart';

class AnimatedBlobWidget extends StatefulWidget {
  final ChatMessage message;

  const AnimatedBlobWidget({super.key, required this.message});

  @override
  State<AnimatedBlobWidget> createState() => _AnimatedBlobWidgetState();
}

class _AnimatedBlobWidgetState extends State<AnimatedBlobWidget>
    with TickerProviderStateMixin {
  late AnimationController _morphController;
  late AnimationController _expandController;
  late AnimationController _pulseController;

  bool _showText = false;
  late List<double> _textRhythm;

  @override
  void initState() {
    super.initState();

    // Analyze text for rhythm-based pulsing
    _textRhythm = _analyzeTextForRhythm(widget.message.content);

    // Morphing animation synchronized with text rhythm
    _morphController = AnimationController(
      duration: Duration(
        milliseconds: (2000 + _textRhythm.length * 100).clamp(1000, 8000),
      ),
      vsync: this,
    );

    // Expansion animation for text reveal
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Pulse animation for glow effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _morphController.dispose();
    _expandController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  List<double> _analyzeTextForRhythm(String text) {
    final words = text.split(RegExp(r'\s+'));
    final rhythm = <double>[];

    for (final word in words) {
      // Create rhythm based on word characteristics
      double intensity = 0.5; // Base intensity

      // Longer words get higher intensity
      if (word.length > 8) {
        intensity += 0.3;
      } else if (word.length > 5) {
        intensity += 0.2;
      } else if (word.length < 3) {
        intensity -= 0.2;
      }

      // Important words get emphasis
      if (word.toLowerCase().contains(
        RegExp(
          r'(credit|score|analysis|financial|business|important|risk|loan)',
        ),
      )) {
        intensity += 0.4;
      }

      // Punctuation affects rhythm
      if (word.endsWith('.') || word.endsWith('!')) intensity += 0.3;
      if (word.endsWith(',') || word.endsWith(';')) intensity += 0.1;

      rhythm.add(intensity.clamp(0.2, 1.0));
    }

    return rhythm.isEmpty ? [0.5] : rhythm;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final isTtsSpeaking = state.isTtsSpeaking;
        final isCurrentlyBeingSpoken =
            !widget.message.isUserMessage &&
            isTtsSpeaking &&
            _isLastNonUserMessage(state.messages);

        // Control animations based on TTS state - IMPROVED LOGIC
        if (isCurrentlyBeingSpoken) {
          if (!_morphController.isAnimating) {
            _morphController.repeat();
          }
          if (!_pulseController.isAnimating) {
            _pulseController.repeat();
          }
        } else {
          // Ensure animations stop immediately when TTS stops
          if (_morphController.isAnimating) {
            _morphController.stop();
            _morphController.reset();
          }
          if (_pulseController.isAnimating) {
            _pulseController.stop();
            _pulseController.reset();
          }
        }

        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Control buttons
                _buildControlButtons(context, state),

                const SizedBox(width: 12),

                // Animated blob
                _buildAnimatedBlob(context, isCurrentlyBeingSpoken),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButtons(BuildContext context, ChatState state) {
    final isTtsSpeaking = state.isTtsSpeaking;
    final isCurrentlyBeingSpoken =
        !widget.message.isUserMessage &&
        isTtsSpeaking &&
        _isLastNonUserMessage(state.messages);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // TTS control button
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(
              0xFF88BDF2,
            ).withValues(alpha: 0.15), // blue shade
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF6A89A7).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: IconButton(
            onPressed: () {
              final bloc = context.read<ChatBloc>();
              if (isCurrentlyBeingSpoken) {
                bloc.add(StopTtsEvent());
              } else {
                bloc.add(StartTtsEvent(widget.message.content));
              }
            },
            icon: Icon(
              isCurrentlyBeingSpoken ? Icons.pause : Icons.play_arrow,
              size: 16,
              color: const Color(0xFF6A89A7), // blue shade
            ),
            padding: EdgeInsets.zero,
          ),
        ),

        const SizedBox(width: 8),

        // Text toggle button
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(
              0xFF88BDF2,
            ).withValues(alpha: _showText ? 0.25 : 0.15), // blue shade
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF6A89A7).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: IconButton(
            onPressed: () {
              setState(() {
                _showText = !_showText;
                if (_showText) {
                  _expandController.forward();
                } else {
                  _expandController.reverse();
                }
              });
            },
            icon: Icon(
              _showText ? Icons.visibility_off : Icons.visibility,
              size: 16,
              color: const Color(0xFF6A89A7), // blue shade
            ),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedBlob(BuildContext context, bool isActive) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _morphController,
        _expandController,
        _pulseController,
      ]),
      builder: (context, child) {
        // Calculate dynamic size for text expansion
        final baseWidth = 70.0;
        final baseHeight = 70.0;
        final maxWidth = 600.0;
        final maxHeight = 225.0; // REDUCED by 25% from 300px to 225px

        final currentWidth =
            baseWidth + (maxWidth - baseWidth) * _expandController.value;
        final currentHeight =
            baseHeight + (maxHeight - baseHeight) * _expandController.value;

        return CustomPaint(
          size: Size(currentWidth, currentHeight),
          painter: BlobPainter(
            morphProgress: _morphController.value,
            expandProgress: _expandController.value,
            pulseProgress: _pulseController.value,
            isActive: isActive,
            showText: _showText,
            textRhythm: _textRhythm,
          ),
          child: _showText
              ? _buildTextContainer(currentWidth, currentHeight)
              : null,
        );
      },
    );
  }

  Widget _buildTextContainer(double width, double height) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Text(
          widget.message.content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  bool _isLastNonUserMessage(List<ChatMessage> messages) {
    for (int i = messages.length - 1; i >= 0; i--) {
      if (!messages[i].isUserMessage) {
        return messages[i] == widget.message;
      }
    }
    return false;
  }
}

class BlobPainter extends CustomPainter {
  final double morphProgress;
  final double expandProgress;
  final double pulseProgress;
  final bool isActive;
  final bool showText;
  final List<double> textRhythm;

  BlobPainter({
    required this.morphProgress,
    required this.expandProgress,
    required this.pulseProgress,
    required this.isActive,
    required this.showText,
    required this.textRhythm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = _createGradient(
        size,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Add pulsating glow effect when active
    if (isActive) {
      final glowIntensity = _calculateGlowIntensity();
      final glowPaint = Paint()
        ..color = const Color(
          0xFF88BDF2,
        ).withValues(alpha: 0.2 + 0.3 * glowIntensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + 6 * glowIntensity);

      canvas.drawPath(_createBlobPath(size, true), glowPaint);
    }

    // Draw main blob
    canvas.drawPath(_createBlobPath(size, false), paint);
  }

  double _calculateGlowIntensity() {
    if (!isActive || textRhythm.isEmpty) return 0.5;

    // Calculate current word position in rhythm
    final rhythmPosition =
        (morphProgress * textRhythm.length) % textRhythm.length;
    final currentWordIntensity = textRhythm[rhythmPosition.floor()];

    // Add base pulsing with text-synchronized variation
    final basePulse = 0.5 + 0.3 * math.sin(pulseProgress * 2 * math.pi);
    final textModulation = currentWordIntensity * 0.4;

    return (basePulse + textModulation).clamp(0.0, 1.0);
  }

  LinearGradient _createGradient(Size size) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF223A5E), // Navy
        Color(0xFF335C81), // Muted blue
        Color(0xFF88BDF2), // Soft blue accent
      ],
      stops: [0.0, 0.7, 1.0],
    );
  }

  Path _createBlobPath(Size size, bool isGlow) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);

    if (showText) {
      // Smooth morphing to speech bubble with pulsating border
      final borderRadius =
          12.0 + (isActive ? 6.0 * math.sin(pulseProgress * 3 * math.pi) : 0.0);

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: size.width - (isGlow ? 0 : 4),
          height: size.height - (isGlow ? 0 : 4),
        ),
        Radius.circular(borderRadius),
      );
      path.addRRect(rect);
    } else {
      // Organic blob with 2D Perlin noise morphing
      path.addPath(_createOrganicBlob(size, center, isGlow), Offset.zero);
    }

    return path;
  }

  Path _createOrganicBlob(Size size, Offset center, bool isGlow) {
    final path = Path();
    final baseRadius = (size.width / 2) - (isGlow ? 0 : 2);

    // Get text rhythm intensity for this moment
    final rhythmIntensity = _getTextRhythmIntensity();

    // Create organic blob with flowing deformations
    const pointCount = 32; // Smooth but not overkill
    final blobPoints = <Offset>[];

    final time = morphProgress * 3; // Medium speed for energy

    for (int i = 0; i < pointCount; i++) {
      final angle = (i / pointCount) * 2 * math.pi;

      // Start with base circle
      double radius = baseRadius;

      if (isActive) {
        // Layer 1: Overall breathing (gentle size variation)
        final breathing = 1.0 + 0.08 * math.sin(time * 1.2) * rhythmIntensity;

        // Layer 2: Primary flowing tendrils (5-6 main bulges)
        final tendril1 = math.sin(angle * 5 + time * 2.0) * 0.15; // 5 tendrils
        final tendril2 = math.sin(angle * 6 + time * 1.7) * 0.12; // 6 tendrils
        final tendril3 =
            math.sin(angle * 4 - time * 2.3) * 0.10; // 4 tendrils (offset)

        // Layer 3: Secondary flowing waves (smoother transitions)
        final wave1 = math.sin(angle * 3 + time * 2.8) * 0.08;
        final wave2 = math.sin(angle * 7 - time * 1.5) * 0.06;
        final wave3 = math.sin(angle * 8 + time * 3.2) * 0.05;

        // Layer 4: Fine detail (keeps it organic, not mechanical)
        final detail1 = math.sin(angle * 9 + time * 4.1) * 0.04;
        final detail2 = math.sin(angle * 11 - time * 2.9) * 0.03;
        final detail3 = math.sin(angle * 13 + time * 3.7) * 0.02;

        // Combine all layers - tendrils are dominant for visible flowing effect
        final tendrils =
            (tendril1 + tendril2 + tendril3) * 0.8; // Stronger tendril effect
        final waves = (wave1 + wave2 + wave3) * 0.6; // Medium smoothing waves
        final details =
            (detail1 + detail2 + detail3) * 0.4; // Subtle organic detail

        final totalDeformation = (tendrils + waves + details) * rhythmIntensity;

        radius = baseRadius * breathing * (1.0 + totalDeformation);
      }

      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      blobPoints.add(Offset(x, y));
    }

    // Create smooth curves
    if (blobPoints.isNotEmpty) {
      path.moveTo(blobPoints[0].dx, blobPoints[0].dy);

      for (int i = 0; i < blobPoints.length; i++) {
        final current = blobPoints[i];
        final next = blobPoints[(i + 1) % blobPoints.length];

        // Simple but effective smooth curves
        final midPoint = Offset(
          (current.dx + next.dx) / 2,
          (current.dy + next.dy) / 2,
        );

        path.quadraticBezierTo(
          current.dx,
          current.dy,
          midPoint.dx,
          midPoint.dy,
        );
      }
      path.close();
    }

    return path;
  }

  double _getTextRhythmIntensity() {
    if (!isActive || textRhythm.isEmpty) return 0.7;

    // Map morph progress to text rhythm
    final rhythmPosition =
        (morphProgress * textRhythm.length) % textRhythm.length;
    final currentIndex = rhythmPosition.floor();
    final nextIndex = (currentIndex + 1) % textRhythm.length;
    final fraction = rhythmPosition - currentIndex;

    // Smooth interpolation between rhythm values
    final currentIntensity = textRhythm[currentIndex];
    final nextIntensity = textRhythm[nextIndex];

    return (currentIntensity + (nextIntensity - currentIntensity) * fraction)
        .clamp(0.4, 1.2);
  }

  @override
  bool shouldRepaint(BlobPainter oldDelegate) {
    return oldDelegate.morphProgress != morphProgress ||
        oldDelegate.expandProgress != expandProgress ||
        oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.isActive != isActive ||
        oldDelegate.showText != showText;
  }
}
