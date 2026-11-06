import 'package:flutter/material.dart';

/// Reusable Telebirr-inspired fintech background
///
/// Features:
/// - Soft light-lime/mint tinted backdrop (#F5F9ED / #F8FBF3)
/// - Subtle radial glow (#E2F6DF)
/// - Thin, delicate concentric ripple circles (#B9E8D1)
/// - Positioned off-screen at top-right and bottom-left
/// - Completely non-intrusive, zero pointer-event interference
/// - Cached on a RepaintBoundary for maximum 60fps performance
class TelebirrBackground extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const TelebirrBackground({
    super.key,
    required this.child,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: TelebirrRipplePainter(isDark: isDark),
            size: Size.infinite,
          ),
        ),
        child,
      ],
    );
  }
}

class TelebirrRipplePainter extends CustomPainter {
  final bool isDark;

  const TelebirrRipplePainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (isDark) {
      // Dark Mode: Deep fintech slate with subtle emerald ripples
      final bgPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF131B2E),
            Color(0xFF0B1120),
          ],
        ).createShader(rect);
      canvas.drawRect(rect, bgPaint);

      final glowPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.85, -0.65),
          radius: 1.1,
          colors: [
            const Color(0xFF10B981).withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ).createShader(rect);
      canvas.drawRect(rect, glowPaint);

      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..isAntiAlias = true;

      _drawRipples(canvas, size, linePaint);
      return;
    }

    // Light Mode: Official Telebirr-inspired Palette
    // 1. Primary Background (#F5F9ED) & Secondary (#F8FBF3)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFF8FBF3),
          Color(0xFFF5F9ED),
          Color(0xFFEFF7E8),
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Soft Green Glow (#E2F6DF) radiating from top right
    final topGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.85, -0.55),
        radius: 1.15,
        colors: [
          const Color(0xFFE2F6DF).withValues(alpha: 0.85),
          const Color(0xFFE2F6DF).withValues(alpha: 0.30),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, topGlow);

    // 3. Secondary Soft Green Glow (#E2F6DF) from bottom left
    final bottomGlow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.85, 0.85),
        radius: 0.95,
        colors: [
          const Color(0xFFE2F6DF).withValues(alpha: 0.70),
          const Color(0xFFE2F6DF).withValues(alpha: 0.20),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bottomGlow);

    // 4. Concentric Ripple Lines (#B9E8D1)
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..isAntiAlias = true;

    _drawRipples(canvas, size, linePaint);
  }

  void _drawRipples(Canvas canvas, Size size, Paint basePaint) {
    // Cluster 1: radiating from top-right / partially outside screen
    final c1 = Offset(size.width * 0.92, -size.height * 0.04);
    final radii1 = [
      75.0,
      145.0,
      230.0,
      330.0,
      445.0,
      575.0,
      720.0,
      880.0,
      1055.0,
      1245.0,
    ];
    for (int i = 0; i < radii1.length; i++) {
      final r = radii1[i];
      final alpha = (0.44 - (i * 0.026)).clamp(0.12, 0.44);
      basePaint.color = isDark
          ? const Color(0xFF10B981).withValues(alpha: alpha * 0.4)
          : const Color(0xFFB9E8D1).withValues(alpha: alpha);
      canvas.drawCircle(c1, r, basePaint);
    }

    // Cluster 2: radiating from bottom-left / partially outside screen
    final c2 = Offset(-size.width * 0.14, size.height * 0.95);
    final radii2 = [
      95.0,
      190.0,
      300.0,
      425.0,
      565.0,
      720.0,
      895.0,
      1085.0,
    ];
    for (int i = 0; i < radii2.length; i++) {
      final r = radii2[i];
      final alpha = (0.38 - (i * 0.026)).clamp(0.10, 0.38);
      basePaint.color = isDark
          ? const Color(0xFF10B981).withValues(alpha: alpha * 0.35)
          : const Color(0xFFB9E8D1).withValues(alpha: alpha);
      canvas.drawCircle(c2, r, basePaint);
    }
  }

  @override
  bool shouldRepaint(covariant TelebirrRipplePainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

