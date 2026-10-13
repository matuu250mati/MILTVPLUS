import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    return ListView(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 18, 10, compact ? 12 : 18, 24),
      children: [
        const Text('Buenas noches',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
        const SizedBox(height: 22),
        Container(
          height: compact ? 286 : 360,
          padding: EdgeInsets.all(compact ? 18 : 26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF343B61), Color(0xFF171C2D), Color(0xFF111521)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -8,
                bottom: -30,
                child: Icon(Icons.movie_filter_rounded,
                    size: compact ? 150 : 220,
                    color: Colors.white.withValues(alpha: .05)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _Pill(label: 'TU CENTRO DE ENTRETENIMIENTO'),
                  SizedBox(height: compact ? 12 : 18),
                  Text('Todo lo que\nquerés ver.',
                      style: TextStyle(fontSize: compact ? 34 : 42, height: 1.02, fontWeight: FontWeight.w900, letterSpacing: compact ? -1.1 : -1.6)),
                  const SizedBox(height: 12),
                  const Text('TV en vivo, películas, series y anime en una sola experiencia.',
                      style: TextStyle(color: AppTheme.muted, height: 1.5)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => onNavigate(0),
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
          children: [
            _CategoryTile('TV EN VIVO', Icons.live_tv_rounded, onTap: () => onNavigate(0)),
            _CategoryTile('PELÍCULAS', Icons.local_movies_rounded, onTap: () => onNavigate(2)),
            _CategoryTile('SERIES', Icons.video_library_rounded, onTap: () => onNavigate(3)),
            _CategoryTile('ANIME', Icons.animation_rounded, onTap: () => onNavigate(4)),
            _CategoryTile('DESTACADOS', Icons.auto_awesome_rounded, onTap: () => onNavigate(1)),
            _CategoryTile('EXPLORAR', Icons.explore_rounded, onTap: () => onNavigate(5)),
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
          color: AppTheme.accent.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppTheme.accent.withValues(alpha: .35)),
        ),
        child: Text(label, style: const TextStyle(color: AppTheme.accent, fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.w800)),
      );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile(this.label, this.icon, {required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.panel,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white.withValues(alpha: .06)),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.accent),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .4))),
              ],
            ),
          ),
        ),
      );
}
