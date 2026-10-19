import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';

/// Movie information page. Playback intentionally stays unavailable until
/// distribution rights and a verified, authorized stream URL are configured.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({
    super.key,
    required this.contentKey,
    required this.title,
    required this.category,
    required this.genres,
    required this.posterUrl,
    required this.year,
    required this.synopsis,
  });

  final String contentKey;
  final String title;
  final String category;
  final List<String> genres;
  final String? posterUrl;
  final int? year;
  final String? synopsis;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _favorite = false;
  bool _liked = false;
  bool _loaded = false;
  String get _favoriteKey => 'miltvplus.favorite.movie.${widget.contentKey}';
  String get _likeKey => 'miltvplus.like.movie.${widget.contentKey}';

  @override
  void initState() {
    super.initState();
    _loadReactions();
  }

  Future<void> _loadReactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _favorite = prefs.getBool(_favoriteKey) ?? false;
        _liked = prefs.getBool(_likeKey) ?? false;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _toggleFavorite() async {
    final next = !_favorite;
    setState(() => _favorite = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_favoriteKey, next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _favorite = !next);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el favorito en este dispositivo.')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(next ? 'Agregada a tus favoritos.' : 'Quitada de tus favoritos.')),
    );
  }

  Future<void> _toggleLike() async {
    final next = !_liked;
    setState(() => _liked = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_likeKey, next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _liked = !next);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar tu Me gusta en este dispositivo.')),
      );
      return;
    }
  }

  void _showUnavailable() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.panel,
        icon: const Icon(Icons.lock_clock_rounded, color: AppTheme.accent, size: 38),
        title: const Text('Estamos preparando este título'),
        content: const Text(
          'La ficha ya está disponible en MILTVPLUS, pero la reproducción todavía no está habilitada. '
          'Estamos trabajando para incorporar una fuente autorizada y confirmar la disponibilidad. '
          'Volvé a consultar más adelante.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final synopsis = widget.synopsis?.trim();
    final hasSynopsis = synopsis != null && synopsis.isNotEmpty;
    final tags = <String>[
      if (widget.year != null) widget.year.toString(),
      if (widget.category.trim().isNotEmpty) widget.category.trim(),
      ...widget.genres,
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 310,
            backgroundColor: AppTheme.background,
            foregroundColor: Colors.white,
            title: const Text('Detalles', style: TextStyle(fontWeight: FontWeight.w800)),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.posterUrl != null && widget.posterUrl!.trim().isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: widget.posterUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _posterFallback(),
                      placeholder: (_, __) => _posterFallback(),
                    )
                  else
                    _posterFallback(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x22000000), Color(0xF5080A10)],
                        stops: [0.15, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Text(
                      widget.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 28,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 12)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusChip(Icons.lock_clock_rounded, 'Reproducción próximamente'),
                    ...tags.map((tag) => _statusChip(Icons.local_offer_outlined, tag)),
                  ],
                ),
                const SizedBox(height: 22),
                const Text('SINOPSIS', style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                )),
                const SizedBox(height: 9),
                Text(
                  hasSynopsis
                      ? synopsis
                      : 'La descripción de este título todavía no fue agregada al catálogo. '
                        'La ficha se mostrará igualmente y podrá completarse cuando se disponga de información verificada.',
                  style: const TextStyle(color: Color(0xFFD9E0EC), height: 1.55, fontSize: 15),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loaded ? _toggleFavorite : null,
                        icon: Icon(_favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                        label: Text(_favorite ? 'En favoritos' : 'Agregar a favoritos'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _favorite ? const Color(0xFFFF5B79) : Colors.white,
                          side: BorderSide(color: _favorite ? const Color(0xFFFF5B79) : const Color(0xFF31506C)),
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loaded ? _toggleLike : null,
                        icon: Icon(_liked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined),
                        label: Text(_liked ? 'Te gusta' : 'Me gusta'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _liked ? AppTheme.accent : Colors.white,
                          side: BorderSide(color: _liked ? AppTheme.accent : const Color(0xFF31506C)),
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _showUnavailable,
                    icon: const Icon(Icons.lock_clock_rounded),
                    label: const Text('Reproducción próximamente'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: const Color(0xFF07101B),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Este título no se reproducirá hasta que se confirme la autorización correspondiente y se configure una fuente válida.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.45),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _posterFallback() => const ColoredBox(
        color: AppTheme.panel,
        child: Center(child: Icon(Icons.movie_outlined, size: 76, color: AppTheme.accent)),
      );

  Widget _statusChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF101A29),
          border: Border.all(color: const Color(0xFF234563)),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.accent),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
