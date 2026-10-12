import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        const Text('Buenas noches',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
        const SizedBox(height: 22),
        Container(
          height: compact ? 300 : 360,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF343B61), Color(0xFF171C2D), Color(0xFF111521)],
            ),
            border: Border.all(color: Colors.white.withOpacity(.12)),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -8,
                bottom: -30,
                child: Icon(Icons.movie_filter_rounded,
                    size: compact ? 150 : 220,
                    color: Colors.white.withOpacity(.05)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _Pill(label: 'TU CENTRO DE ENTRETENIMIENTO'),
                  const SizedBox(height: 18),
                  const Text('Todo lo que\nquerés ver.',
                      style: TextStyle(fontSize: 42, height: 1, fontWeight: FontWeight.w900, letterSpacing: -1.6)),
                  const SizedBox(height: 14),
                  const Text('TV en vivo, películas, series y anime en una sola experiencia.',
                      style: TextStyle(color: AppTheme.muted, height: 1.5)),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Elegí TV EN VIVO en el menú lateral.')),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('EMPEZAR A VER'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text('EXPLORÁ POR CATEGORÍA',
            style: TextStyle(fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: compact ? 2 : 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.8,
          children: const [
            _CategoryTile('TV EN VIVO', Icons.live_tv_rounded),
            _CategoryTile('PELÍCULAS', Icons.local_movies_rounded),
            _CategoryTile('SERIES', Icons.video_library_rounded),
            _CategoryTile('ANIME', Icons.animation_rounded),
            _CategoryTile('DESTACADOS', Icons.auto_awesome_rounded),
            _CategoryTile('EXPLORAR', Icons.explore_rounded),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(.12),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppTheme.accent.withOpacity(.35)),
        ),
        child: Text(label, style: const TextStyle(color: AppTheme.accent, fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.w800)),
      );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile(this.label, this.icon);
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.panel,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withOpacity(.06)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .4))),
          ],
        ),
      );
}
