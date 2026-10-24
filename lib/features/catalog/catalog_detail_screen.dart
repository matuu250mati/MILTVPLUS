import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../services/catalog_preferences_service.dart';

/// Ficha de una película o serie con las acciones principales:
/// Reproducir, Me gusta, Favorito y Más.
///
/// La reproducción se resuelve dentro de la app mediante [onPlay]; esta
/// pantalla nunca abre un sitio web externo.
class CatalogDetailScreen extends StatefulWidget {
  const CatalogDetailScreen({
    super.key,
    required this.itemKey,
    required this.title,
    required this.category,
    required this.genres,
    required this.canPlay,
    required this.onPlay,
    this.posterUrl,
    this.backdropUrl,
    this.year,
    this.synopsis,
    this.preferences = const CatalogPreferencesService(),
  });

  final String itemKey;
  final String title;
  final String category;
  final List<String> genres;
  final bool canPlay;
  final Future<void> Function(BuildContext context) onPlay;
  final String? posterUrl;
  final String? backdropUrl;
  final int? year;
  final String? synopsis;
  final CatalogPreferencesService preferences;

  @override
  State<CatalogDetailScreen> createState() => _CatalogDetailScreenState();
}

class _CatalogDetailScreenState extends State<CatalogDetailScreen> {
  bool _favorite = false;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final favorite = await widget.preferences.isFavorite(widget.itemKey);
    final liked = await widget.preferences.isLiked(widget.itemKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _favorite = favorite;
      _liked = liked;
    });
  }

  Future<void> _toggleFavorite() async {
    final next = !_favorite;
    setState(() => _favorite = next);
    await widget.preferences.setFavorite(widget.itemKey, next);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(next ? 'Agregado a favoritos.' : 'Quitado de favoritos.')),
    );
  }

  Future<void> _toggleLike() async {
    final next = !_liked;
    setState(() => _liked = next);
    await widget.preferences.setLiked(widget.itemKey, next);
  }

  void _showMore() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Text(
                widget.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Categoría'),
              subtitle: Text(widget.category),
            ),
            if (widget.year != null)
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Año'),
                subtitle: Text(widget.year.toString()),
              ),
            if (widget.genres.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.theater_comedy_outlined),
                title: const Text('Géneros'),
                subtitle: Text(widget.genres.join(', ')),
              ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copiar título'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: widget.title));
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = (widget.backdropUrl != null && widget.backdropUrl!.isNotEmpty)
        ? widget.backdropUrl
        : widget.posterUrl;
    final synopsis = widget.synopsis?.trim() ?? '';
    final meta = [
      if (widget.year != null) widget.year.toString(),
      widget.category,
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: imageUrl == null || imageUrl.isEmpty
                ? const Center(
                    child: Icon(Icons.movie_outlined, size: 64, color: AppTheme.accent),
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.movie_outlined, size: 64, color: AppTheme.accent),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(meta, style: const TextStyle(color: AppTheme.muted)),
                if (widget.genres.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final genre in widget.genres) Chip(label: Text(genre)),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    autofocus: true,
                    onPressed: widget.canPlay ? () => widget.onPlay(context) : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(widget.canPlay ? 'Reproducir' : 'Próximamente'),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _toggleLike,
                      icon: Icon(_liked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined),
                      label: const Text('Me gusta'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _toggleFavorite,
                      icon: Icon(_favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                      label: const Text('Favorito'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _showMore,
                      icon: const Icon(Icons.more_horiz_rounded),
                      label: const Text('Más'),
                    ),
                  ],
                ),
                if (synopsis.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Sinopsis', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(synopsis, style: const TextStyle(height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
