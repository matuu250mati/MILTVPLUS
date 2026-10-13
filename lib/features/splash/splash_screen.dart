import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
  )..forward();

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, .72, curve: Curves.easeOut),
  );

  late final Animation<double> _scale = Tween<double>(begin: .78, end: 1).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -.2),
              radius: 1.15,
              colors: [Color(0xFF252B49), Color(0xFF0B0D15), AppTheme.background],
              stops: [0, .58, 1],
            ),
          ),
          child: Center(
            child: FadeTransition(
              opacity: _opacity,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 94,
                      height: 94,
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withValues(alpha: .28),
                            blurRadius: 42,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded, size: 70, color: Colors.black),
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      'MILTVPLUS',
                      style: TextStyle(
                        fontSize: 27,
                        letterSpacing: 5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'ENTRETENIMIENTO ARGENTINO',
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 9,
                        letterSpacing: 2.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 35),
                    const SizedBox(
                      width: 88,
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
