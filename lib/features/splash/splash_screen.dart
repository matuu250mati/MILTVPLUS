import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onSkip});

  final VoidCallback? onSkip;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _showSkip = false;
  Future<void>? _skipDelay;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..forward();

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, .78, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _scale = Tween<double>(begin: .82, end: 1).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
  );

  late final Animation<double> _glow = Tween<double>(begin: .35, end: 1).animate(
    CurvedAnimation(parent: _controller, curve: const Interval(.08, .9, curve: Curves.easeOut)),
  );

  @override
  void initState() {
    super.initState();
    _skipDelay = Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showSkip = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -.18),
              radius: 1.12,
              colors: [
                Color(0xFF172D35),
                Color(0xFF101725),
                Color(0xFF070B12),
              ],
              stops: [0, .55, 1],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Soft brand-color halos add depth without relying on raster assets.
              AnimatedBuilder(
                animation: _glow,
                builder: (context, child) => Opacity(
                  opacity: _glow.value * .34,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.accent.withValues(alpha: .23),
                          const Color(0x0038D9FF),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              FadeTransition(
                opacity: _opacity,
                child: ScaleTransition(
                  scale: _scale,
                  child: FittedBox(
                    fit: BoxFit.contain, // Preserve the full composition on short or narrow TV viewports.
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _glow,
                        builder: (context, child) => Container(
                          width: 154,
                          height: 154,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(42),
                            color: const Color(0xFF091522),
                            border: Border.all(
                              color: AppTheme.accent.withValues(
                                alpha: .48 + (_glow.value * .42),
                              ),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accent.withValues(
                                  alpha: .12 + (_glow.value * .24),
                                ),
                                blurRadius: 44,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: const Color(0xFF38D9FF).withValues(
                                  alpha: .08 + (_glow.value * .12),
                                ),
                                blurRadius: 58,
                                spreadRadius: -6,
                              ),
                            ],
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(18),
                            child: CustomPaint(painter: _NeonTelevisionPainter()),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'MILTVPLUS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          letterSpacing: 5.5,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(color: Color(0x6658F5A8), blurRadius: 20),
                          ],
                        ),
                      ),
                      const SizedBox(height: 11),
                      const Text(
                        'ENTRETENIMIENTO ARGENTINO',
                        style: TextStyle(
                          color: Color(0xFF9AAAB8),
                          fontSize: 10,
                          letterSpacing: 2.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 42),
                      SizedBox(
                        width: 112,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: const LinearProgressIndicator(
                            minHeight: 3,
                            backgroundColor: Color(0xFF26323D),
                            valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                          ),
                        ),
                      ),
                    ],
                    ),
                  ),
                ),
              ),
              if (_showSkip && widget.onSkip != null)
                Positioned(
                  right: 20,
                  bottom: 18,
                  child: SafeArea(
                    child: TextButton.icon(
                      onPressed: widget.onSkip,
                      icon: const Icon(Icons.skip_next_rounded),
                      label: const Text('OMITIR INTRO'),
                      style: TextButton.styleFrom(foregroundColor: Colors.white70),
                    ),
                  ),
                ),
            ],
          ),
          ),
        ),
      );
}

class _NeonTelevisionPainter extends CustomPainter {
  const _NeonTelevisionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale);

    final glowPaint = Paint()
      ..color = const Color(0x6638D9FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final outlinePaint = Paint()
      ..color = AppTheme.accent
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
        ..color = AppTheme.accent
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
