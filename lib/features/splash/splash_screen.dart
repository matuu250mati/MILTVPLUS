import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  late final AnimationController _ambientController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _introController,
    curve: const Interval(0, .82, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _scale = Tween<double>(begin: .80, end: 1).animate(
    CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _glow = CurvedAnimation(
    parent: _ambientController,
    curve: Curves.easeInOutSine,
  );

  @override
  void dispose() {
    _introController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF030609),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final contentWidth = math.min(width * .92, 620.0);
          // Flutter lays out in logical pixels already; never multiply by
          // devicePixelRatio, which would make the UI oversized on dense screens.
          final scale = math.min(contentWidth / 430.0, height / 700.0)
              .clamp(.42, 1.55)
              .toDouble();

          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -.12),
                    radius: 1.12,
                    colors: [
                      Color(0xFF102B32),
                      Color(0xFF0B1720),
                      Color(0xFF030609),
                    ],
                    stops: [0, .48, 1],
                  ),
                ),
              ),
              // Lightweight vector particles: crisp at any resolution and cheap
              // enough for Android TV boxes as well as high-density displays.
              CustomPaint(
                painter: _AmbientParticlesPainter(_ambientController),
                isComplex: false,
                willChange: true,
              ),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: contentWidth,
                    child: FadeTransition(
                      opacity: _opacity,
                      child: ScaleTransition(
                        scale: _scale,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _glow,
                              builder: (context, child) {
                                final pulse = _glow.value;
                                final logoSize = 154 * scale;
                                return Container(
                                  width: logoSize,
                                  height: logoSize,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(logoSize * .27),
                                    color: const Color(0xFF07131D),
                                    border: Border.all(
                                      color: const Color(0xFF00FF66).withValues(
                                        alpha: .48 + pulse * .42,
                                      ),
                                      width: math.max(1, scale * 1.5),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00FF66).withValues(
                                          alpha: .12 + pulse * .22,
                                        ),
                                        blurRadius: 38 * scale,
                                        spreadRadius: 1 * scale,
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFF38D9FF).withValues(
                                          alpha: .08 + pulse * .14,
                                        ),
                                        blurRadius: 52 * scale,
                                        spreadRadius: -6 * scale,
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(18 * scale),
                                    child: CustomPaint(
                                      painter: const _NeonTelevisionPainter(),
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: 28 * scale),
                            Text(
                              'MILTVPLUS',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 29 * scale,
                                letterSpacing: 5.5 * scale,
                                fontWeight: FontWeight.w900,
                                shadows: const [
                                  Shadow(
                                    color: Color(0x6658F5A8),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 10 * scale),
                            Text(
                              'ENTRETENIMIENTO ARGENTINO',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                color: const Color(0xFF9AAAB8),
                                fontSize: 10 * scale,
                                letterSpacing: 2.1 * scale,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 38 * scale),
                            AnimatedBuilder(
                              animation: _glow,
                              builder: (context, child) => Container(
                                width: 220 * scale,
                                height: math.max(3.0, 4 * scale),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1D2A32),
                                  borderRadius: BorderRadius.circular(99),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00FF66).withValues(
                                        alpha: .12 + _glow.value * .12,
                                      ),
                                      blurRadius: 16 * scale,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment(-1.3 + 2.6 * _glow.value, 0),
                                        end: Alignment(-.3 + 2.6 * _glow.value, 0),
                                        colors: const [
                                          Color(0xFF087D52),
                                          Color(0xFF00FF66),
                                          Color(0xFF38D9FF),
                                          Color(0xFF00FF66),
                                        ],
                                        stops: const [0, .38, .58, 1],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 15 * scale),
                            Text(
                              'PREPARANDO TU EXPERIENCIA',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFF71828D),
                                fontSize: 9 * scale,
                                letterSpacing: 1.8 * scale,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Keep this local reference useful during accessibility/TV QA.
              Positioned(
                right: 0,
                bottom: 0,
                child: SizedBox(
                  width: 1,
                  height: 1,
                  child: ExcludeSemantics(
                    child: Text(
                      media.size.width > 0 ? 'MILTVPLUS' : '',
                      style: const TextStyle(fontSize: 1),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AmbientParticlesPainter extends CustomPainter {
  _AmbientParticlesPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final phase = animation.value * math.pi * 2;
    for (var i = 0; i < 34; i++) {
      final xUnit = ((i * 73 + 19) % 997) / 997.0;
      final yBase = ((i * 137 + 41) % 991) / 991.0;
      final drift = math.sin(phase + i * .71) * .012;
      final point = Offset(
        (xUnit + drift).clamp(.015, .985) * size.width,
        yBase * size.height,
      );
      final shimmer = (.18 + .36 * (1 + math.sin(phase + i)) / 2);
      final paint = Paint()
        ..color = Color.lerp(
          const Color(0xFF00FF66),
          const Color(0xFF38D9FF),
          (i % 5) / 4,
        )!.withValues(alpha: shimmer)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(point, i % 7 == 0 ? 1.6 : .8, paint);
    }

    final linePaint = Paint()
      ..color = const Color(0xFF38D9FF).withValues(alpha: .055)
      ..strokeWidth = 1;
    for (var i = 0; i < 8; i++) {
      final x = size.width * (i / 7);
      canvas.drawLine(
        Offset(x, size.height * .12),
        Offset(x, size.height * .88),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientParticlesPainter oldDelegate) => false;
}

class _NeonTelevisionPainter extends CustomPainter {
  const _NeonTelevisionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = math.min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate(
      (size.width - 100 * scale) / 2,
      (size.height - 100 * scale) / 2,
    );
    canvas.scale(scale);

    final glowPaint = Paint()
      ..color = const Color(0xAA38D9FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final outlinePaint = Paint()
      ..color = const Color(0xFF00FF66)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()..color = const Color(0xFF071426);
    final antennaPaint = Paint()
      ..color = const Color(0xFF38D9FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final screen = RRect.fromRectAndRadius(
      const Rect.fromLTWH(12, 29, 76, 51),
      const Radius.circular(10),
    );

    canvas.drawLine(const Offset(39, 25), const Offset(27, 12), antennaPaint);
    canvas.drawLine(const Offset(61, 25), const Offset(73, 12), antennaPaint);
    canvas.drawRRect(screen, glowPaint);
    canvas.drawRRect(screen, fillPaint);
    canvas.drawRRect(screen, outlinePaint);

    final play = Path()
      ..moveTo(43, 40)
      ..quadraticBezierTo(41, 38, 41, 43)
      ..lineTo(41, 66)
      ..quadraticBezierTo(41, 70, 45, 67)
      ..lineTo(65, 56)
      ..quadraticBezierTo(69, 54, 65, 51)
      ..close();
    canvas.drawPath(
      play,
      Paint()
        ..color = const Color(0xFF00FF66)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(play, Paint()..color = Colors.white);
    canvas.drawLine(const Offset(42, 85), const Offset(58, 85), outlinePaint);
    canvas.drawLine(const Offset(50, 81), const Offset(50, 85), outlinePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
