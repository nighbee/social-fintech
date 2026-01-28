import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:gap/gap.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Star> _stars = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Generate random stars
    final random = math.Random();
    for (int i = 0; i < 30; i++) {
      _stars.add(
        Star(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: random.nextDouble() * 2 + 1,
          opacity: random.nextDouble() * 0.5 + 0.5,
          twinkleSpeed: random.nextDouble() * 2 + 1,
          dx: (random.nextDouble() - 0.5) * 0.0005, // Horizontal movement speed
          dy: (random.nextDouble() - 0.5) * 0.0005, // Vertical movement speed
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: CustomAppBar(showLeading: false),
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.home),
      body: SafeArea(
        child: Stack(
          children: [
            // Animated starry background
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: StarryBackgroundPainter(
                    stars: _stars,
                    animationValue: _controller.value,
                  ),
                  child: Container(),
                );
              },
            ),
            // Content
            ListView(
              physics: const ClampingScrollPhysics(),
              children: [
                Gap(12),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Welcome to BrightBund',
                          style: context.theme.textStyles.titleLarge,
                        ),
                        Gap(20),
                        Text(
                          'Home page content will be added here',
                          style: context.theme.textStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class Star {
  final double x;
  final double y;
  final double size;
  final double opacity;
  final double twinkleSpeed;
  final double dx; // Horizontal velocity
  final double dy; // Vertical velocity

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.twinkleSpeed,
    required this.dx,
    required this.dy,
  });
}

class StarryBackgroundPainter extends CustomPainter {
  final List<Star> stars;
  final double animationValue;

  StarryBackgroundPainter({required this.stars, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final star in stars) {
      // Calculate twinkling opacity
      final twinkle =
          (math.sin(animationValue * 2 * math.pi * star.twinkleSpeed) + 1) / 2;
      final currentOpacity = star.opacity * (0.5 + twinkle * 0.5);

      paint.color = Colors.white.withOpacity(currentOpacity);

      // Calculate moving position
      final moveDistance = animationValue * 2 * math.pi;
      double currentX = (star.x + star.dx * moveDistance) % 1.0;
      double currentY = (star.y + star.dy * moveDistance) % 1.0;

      // Wrap around if negative
      if (currentX < 0) currentX += 1.0;
      if (currentY < 0) currentY += 1.0;

      // Draw star
      canvas.drawCircle(
        Offset(currentX * size.width, currentY * size.height),
        star.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(StarryBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
