import 'dart:math';
import 'package:flutter/material.dart';

/// A widget that displays animated particles that fade in and out.
/// Particles stay in fixed positions and create an elegant ambient effect.
class ParticleAnimation extends StatefulWidget {
  /// Number of particles to display (default: 18)
  final int particleCount;

  /// Colors to use for particles (default: white and gray)
  /// Each particle will randomly pick one color from this list
  final List<Color> particleColors;

  /// Minimum particle size in pixels (default: 4)
  final double minSize;

  /// Maximum particle size in pixels (default: 8)
  final double maxSize;

  /// Duration of one animation cycle in seconds (default: 6.5)
  final double animationDurationSeconds;

  /// Minimum distance between particles in pixels (default: 50)
  final double minDistanceBetweenParticles;

  const ParticleAnimation({
    super.key,
    this.particleCount = 18,
    this.particleColors = const [
      Color(0xFFFFFFFF), // White
      Color(0xFF838383), // Gray
    ],
    this.minSize = 4.0,
    this.maxSize = 8.0,
    this.animationDurationSeconds = 6.5,
    this.minDistanceBetweenParticles = 50.0,
  });

  @override
  State<ParticleAnimation> createState() => _ParticleAnimationState();
}

class _ParticleAnimationState extends State<ParticleAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Particle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.animationDurationSeconds.toInt()),
    )..repeat();

    _particles = _generateParticles();
  }

  @override
  void didUpdateWidget(ParticleAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.particleCount != widget.particleCount ||
        oldWidget.minSize != widget.minSize ||
        oldWidget.maxSize != widget.maxSize) {
      _particles = _generateParticles();
    }
    if (oldWidget.animationDurationSeconds != widget.animationDurationSeconds) {
      _controller.duration = Duration(
        seconds: widget.animationDurationSeconds.toInt(),
      );
    }
  }

  List<Particle> _generateParticles() {
    // Will be populated with actual screen size in build
    return [];
  }

  List<Particle> _generateParticlesForSize(Size size) {
    final particles = <Particle>[];
    final maxAttempts = 100;

    for (int i = 0; i < widget.particleCount; i++) {
      Offset position;
      int attempts = 0;
      bool isValidPosition = false;

      // Find a position that's far enough from existing particles
      do {
        position = Offset(
          _random.nextDouble() * size.width,
          _random.nextDouble() * size.height,
        );

        // Check distance from all existing particles
        isValidPosition = true;
        for (final particle in particles) {
          final distance = (position - particle.position).distance;
          if (distance < widget.minDistanceBetweenParticles) {
            isValidPosition = false;
            break;
          }
        }

        attempts++;
      } while (!isValidPosition && attempts < maxAttempts);

      // If we couldn't find a valid position after max attempts, use the last one
      // This prevents infinite loops on small screens or with too many particles

      particles.add(
        Particle(
          position: position,
          size:
              widget.minSize +
              _random.nextDouble() * (widget.maxSize - widget.minSize),
          animationDelay:
              _random.nextDouble() *
              widget.animationDurationSeconds, // Random delay across full cycle
          color: widget
              .particleColors[_random.nextInt(widget.particleColors.length)],
        ),
      );
    }
    return particles;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Initialize particles if not already done or if size changed significantly
        if (_particles.isEmpty || _particles.length != widget.particleCount) {
          _particles = _generateParticlesForSize(constraints.biggest);
        }

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: constraints.biggest,
              painter: ParticlesPainter(
                particles: _particles,
                animationValue: _controller.value,
                animationDuration: widget.animationDurationSeconds,
              ),
            );
          },
        );
      },
    );
  }
}

/// Represents a single particle with fixed position and animation properties.
class Particle {
  final Offset position;
  final double size;
  final double animationDelay;
  final Color color;

  Particle({
    required this.position,
    required this.size,
    required this.animationDelay,
    required this.color,
  });
}

/// Custom painter to render particles with fade in/out animation.
class ParticlesPainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;
  final double animationDuration;

  ParticlesPainter({
    required this.particles,
    required this.animationValue,
    required this.animationDuration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final opacity = _calculateOpacity(particle);
      if (opacity <= 0) continue;

      final paint = Paint()
        ..color = particle.color.withOpacity(opacity)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);

      canvas.drawCircle(particle.position, particle.size / 2, paint);
    }
  }

  double _calculateOpacity(Particle particle) {
    // Calculate the adjusted animation value considering the particle's delay
    final totalAnimationTime = animationDuration;
    final delayFraction = particle.animationDelay / totalAnimationTime;

    // Adjust animation value by the delay
    var adjustedValue = (animationValue - delayFraction) % 1.0;
    if (adjustedValue < 0) adjustedValue += 1.0;

    // Animation curve with appearing/disappearing effect:
    // 0.0 - 0.20: Fade in (0% -> 42%)
    // 0.20 - 0.50: Stay visible (42%)
    // 0.50 - 0.70: Fade out (42% -> 0%)
    // 0.70 - 1.0: Invisible (0%)

    if (adjustedValue < 0.20) {
      // Fade in phase
      return (adjustedValue / 0.20) * 0.42;
    } else if (adjustedValue < 0.50) {
      // Stay visible phase
      return 0.42;
    } else if (adjustedValue < 0.70) {
      // Fade out phase
      return ((0.70 - adjustedValue) / 0.20) * 0.42;
    } else {
      // Invisible phase
      return 0.0;
    }
  }

  @override
  bool shouldRepaint(ParticlesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
