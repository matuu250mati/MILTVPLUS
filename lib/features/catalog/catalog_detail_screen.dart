import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../models/media_models.dart';
import '../../services/catalog_service.dart';
import 'catalog_player_screen.dart';

/// Individual movie/series page. Metadata remains available even when a
/// playable stream has not been configured by the content owner.
class CatalogDetailScreen extends StatefulWidget {
  const CatalogDetailScreen({
    super.key,
    required this.title,
    required this.category,
    this.genres = const <String>[],
    this.posterUrl,
    this.backdropUrl,
    this.year,
    this.synopsis,
    this.streamUrl,
    this.backupStreamUrls = const <String>[],
    this.seriesId,
  });

  final String title;
  final String category;
  final List<String> genres;
  final String? posterUrl;
  final String? backdropUrl;
  final int? year;
  final String? synopsis;
  final String? streamUrl;
  final List<String> backupStreamUrls;
  final String? seriesId;

  @override
  State<CatalogDetailScreen> createState() => _CatalogDetailScreenState();
}

class _CatalogDetailScreenState extends State<CatalogDetailScreen> {
  final CatalogService _catalog = CatalogService();
  bool _liked = false;
  bool _likeLoaded = false;
  late Future<List<EpisodeModel>> _episodesFuture;

  String get _likeKey => 'miltv_catalog_like_${Uri.encodeComponent(widget.title)}';

  @override
  void initState() {
    super.initState();
    _loadLike();
    _episodesFuture = _loadEpisodes();
  }

  Future<void> _loadLike() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _liked = prefs.getBool(_likeKey) ?? false;
        _likeLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _likeLoaded = true);
    }
  }

  Future<List<EpisodeModel>> _loadEpisodes() async {
    if (widget.seriesId == null || widget.seriesId!.trim().isEmpty) {
      return const <EpisodeModel>[];
    }
    return _catalog.getEpisodes(widget.seriesId!);
  }

  Future<void> _toggleLike() async {
    final next = !_liked;
    setState(() => _liked = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_likeKey, next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el Me gusta en este dispositivo.')),
      );
    }
  }

  Future<void> _shareTitle() async {
    final details = <String>[
      widget.title,
      if (widget.year != null) widget.year.toString(),
      widget.category,
      if (widget.synopsis?.trim().isNotEmpty == true) widget.synopsis!.trim(),
      'MILTVPLUS',
    ].join('\n');
    try {
      await Share.share(details, subject: widget.title);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el menú para compartir.')),
      );
    }
  }

  Future<void> _playMovie() async {
    final url = widget.streamUrl?.trim() ?? '';
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta película todavía no tiene una fuente de reproducción configurada.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogPlayerScreen(
          title: widget.title,
          streamUrl: url,
          backupStreamUrls: widget.backupStreamUrls,
        ),
      ),
    );
  }

  Future<void> _playEpisode(EpisodeModel episode) async {
    final urls = episode.streamUrls.isNotEmpty
        ? episode.streamUrls
        : <String>[if (episode.urlStream.trim().isNotEmpty) episode.urlStream.trim()];
    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${episode.title} todavía no tiene una fuente de reproducción.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogPlayerScreen(
          title: '${widget.title} · T${episode.seasonNumber}E${episode.episodeNumber}',
          streamUrl: urls.first,
          backupStreamUrls: urls.length > 1 ? urls.skip(1).toList(growable: false) : const <String>[],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSeries = widget.seriesId != null && widget.seriesId!.isNotEmpty;
    final synopsis = widget.synopsis?.trim() ?? '';
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 245,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if ((widget.backdropUrl ?? widget.posterUrl)?.trim().isNotEmpty == true)
                    CachedNetworkImage(
                      imageUrl: (widget.backdropUrl ?? widget.posterUrl!).trim(),
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
                        colors: [Colors.transparent, Color(0xEE050912)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.year != null) _InfoChip(label: widget.year.toString()),
              _InfoChip(label: widget.category),
              ...widget.genres.take(4).map((genre) => _InfoChip(label: genre)),
            ],
          ),
          if (synopsis.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(synopsis, style: const TextStyle(color: AppTheme.muted, height: 1.45)),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isSeries ? null : _playMovie,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Reproducir'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: const Color(0xFF06101B),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: _liked ? 'Quitar Me gusta' : 'Me gusta',
                onPressed: _likeLoaded ? _toggleLike : null,
                icon: Icon(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                color: _liked ? Colors.pinkAccent : null,
              ),
              IconButton.filledTonal(
                tooltip: 'Compartir',
                onPressed: _shareTitle,
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
          if (isSeries) ...[
            const SizedBox(height: 24),
            const Text('Temporadas y episodios', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            FutureBuilder<List<EpisodeModel>>(
              future: _episodesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ));
                }
                if (snapshot.hasError) {
                  return const Text('No se pudieron cargar los episodios. Revisá la conexión y las políticas de lectura.',
                    style: TextStyle(color: AppTheme.muted));
                }
                final episodes = snapshot.data ?? const <EpisodeModel>[];
                if (episodes.isEmpty) {
                  return const Text('Esta serie todavía no tiene episodios publicados.',
                    style: TextStyle(color: AppTheme.muted));
                }
                final seasons = <int, List<EpisodeModel>>{};
                for (final episode in episodes) {
                  seasons.putIfAbsent(episode.seasonNumber, () => <EpisodeModel>[]).add(episode);
                }
                return Column(
                  children: seasons.entries.map((season) => Card(
                    color: AppTheme.panel,
                    child: ExpansionTile(
                      initiallyExpanded: seasons.length == 1,
                      title: Text('Temporada ${season.key}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${season.value.length} episodios'),
                      children: season.value.map((episode) {
                        final canPlay = episode.urlStream.trim().isNotEmpty || episode.streamUrls.isNotEmpty;
                        return ListTile(
                          leading: Icon(canPlay ? Icons.play_circle_fill_rounded : Icons.lock_outline_rounded,
                            color: canPlay ? AppTheme.accent : AppTheme.muted),
                          title: Text('${episode.episodeNumber}. ${episode.title}'),
                          subtitle: Text(canPlay ? 'Listo para reproducir' : 'Fuente pendiente de configurar'),
                          onTap: () => _playEpisode(episode),
                        );
                      }).toList(growable: false),
                    ),
                  )).toList(growable: false),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _posterFallback() => Container(
    color: AppTheme.panel,
    alignment: Alignment.center,
    child: const Icon(Icons.movie_outlined, size: 58, color: AppTheme.accent),
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(label),
    visualDensity: VisualDensity.compact,
    backgroundColor: AppTheme.panel,
    side: BorderSide(color: Colors.white.withValues(alpha: .1)),
  );
}
