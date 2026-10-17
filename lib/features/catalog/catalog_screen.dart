import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_theme.dart';
import '../../models/media_models.dart';
import '../../services/catalog_service.dart';
import 'catalog_player_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.category, this.startVoiceSearch = false, this.onVoiceSearchConsumed});

  final String category;
  final bool startVoiceSearch;
  final VoidCallback? onVoiceSearchConsumed;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _searchController = TextEditingController();
  final _catalogService = CatalogService();
  late Future<List<_CatalogEntry>> _entriesFuture;
  bool _headerVisible = true;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _loadEntries();
    if (widget.startVoiceSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startVoiceSearch());
        widget.onVoiceSearchConsumed?.call();
      });
    }
  }

  Future<void> _startVoiceSearch() async {
    final supported = kIsWeb || defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows;
    if (!supported) {
      _showSearchMessage('La búsqueda por voz no está disponible en este sistema. Podés usar el teclado del control remoto.');
      return;
    }
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _listening = status == 'listening');
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _listening = false);
          _showSearchMessage('No se pudo reconocer la voz. Revisá el permiso del micrófono e intentá otra vez.');
        },
      );
      if (!mounted) return;
      if (!available) {
        _showSearchMessage('El reconocimiento de voz no está disponible. Revisá el permiso del micrófono o usá el teclado del control remoto.');
        return;
      }
      setState(() => _listening = true);
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: 'es_AR',
          listenFor: const Duration(seconds: 12),
          pauseFor: const Duration(seconds: 3),
        ),
        onResult: (result) {
          if (!mounted) return;
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) {
            _searchController.value = TextEditingValue(
              text: words,
              selection: TextSelection.collapsed(offset: words.length),
            );
            setState(() {});
          }
          if (result.finalResult) {
            setState(() => _listening = false);
            unawaited(_speech.stop());
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _listening = false);
        _showSearchMessage('No se pudo iniciar el micrófono. Usá el teclado del control remoto.');
      }
    }
  }

  void _showSearchMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 4)));
  }

  @override
  void didUpdateWidget(covariant CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      _entriesFuture = _loadEntries();
    }
  }

  @override
  void dispose() {
    unawaited(_speech.stop());
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadApprovedSubmissions(
    String mediaType,
  ) async {
    // The core catalog must remain available even before the optional
    // community-submissions migration has been applied to Supabase.
    try {
      return await _catalogService.getApprovedSubmissions(mediaType);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<_CatalogEntry>> _loadEntries() async {
    if (widget.category == 'SERIES') {
      final results = await Future.wait<dynamic>([
        _catalogService.getSeries(),
        _loadApprovedSubmissions('episode'),
      ]);
      final series = results[0] as List<SeriesModel>;
      final submittedEpisodes = results[1] as List<Map<String, dynamic>>;
      return <_CatalogEntry>[
        ...series.map(_CatalogEntry.fromSeries),
        ...submittedEpisodes.map(_CatalogEntry.fromSubmission),
      ];
    }

    final results = await Future.wait<dynamic>([
      _catalogService.getMovies(),
      _loadApprovedSubmissions('movie'),
    ]);
    final movies = results[0] as List<MovieModel>;
    final submittedMovies = results[1] as List<Map<String, dynamic>>;
    final entries = <_CatalogEntry>[
      ...movies.map(_CatalogEntry.fromMovie),
      ...submittedMovies.map(_CatalogEntry.fromSubmission),
    ];
    final category = widget.category.toLowerCase();

    if (widget.category == 'EXPLORAR' || category == 'películas' || category == 'peliculas') return entries;

    return entries.where((entry) {
      final searchable = '${entry.category} ${entry.genres.join(' ')} ${entry.title}'.toLowerCase();
      switch (category) {
        case 'anime':
          return searchable.contains('anime');
        case 'deportes':
          return searchable.contains('deporte') || searchable.contains('sport');
        case 'infantil':
          return searchable.contains('infantil') || searchable.contains('kids') || searchable.contains('children');
        case 'gratis':
          return searchable.contains('gratis') || searchable.contains('free');
        default:
          return searchable.contains(category);
      }
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Only the catalog's vertical viewport controls the header. Nested
        // horizontal poster rails must not hide it while the user browses sideways.
        if (notification is ScrollUpdateNotification &&
            notification.metrics.axis == Axis.vertical &&
            notification.depth == 0 &&
            notification.scrollDelta != null) {
          final delta = notification.scrollDelta!;
          // Ignore tiny layout/ballistic noise to avoid flicker on TV remotes.
          if (delta.abs() >= 1.5) {
            final scrollingDown = delta > 0;
            if (scrollingDown != !_headerVisible) {
              setState(() => _headerVisible = !scrollingDown);
            }
          }
        }
        return false;
      },
      child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _headerVisible ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Row(
            children: [
              Text(_catalogCategoryIcon(widget.category),
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.category,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'Contenido publicado desde el catálogo de MILTVPLUS.',
            style: TextStyle(color: AppTheme.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            autofocus: widget.category == 'EXPLORAR' && !widget.startVoiceSearch,
            controller: _searchController,
            textInputAction: TextInputAction.search,
            keyboardType: TextInputType.text,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar título, categoría o género',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _listening ? 'Escuchando…' : 'Buscar por voz',
                    onPressed: _listening ? () => unawaited(_speech.stop()) : () => unawaited(_startVoiceSearch()),
                    icon: Icon(_listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: _listening ? AppTheme.accent : null),
                  ),
                  if (query.isNotEmpty)
                    IconButton(
                      tooltip: 'Borrar búsqueda',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
              ],
            ) : const SizedBox.shrink(),
          ),
          Expanded(
            child: FutureBuilder<List<_CatalogEntry>>(
              future: _entriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _MessageState(
                    icon: Icons.cloud_off_rounded,
                    message: 'No se pudo cargar el catálogo publicado.',
                    detail: 'Verificá la conexión con Supabase, las tablas y las políticas RLS.',
                    action: FilledButton.icon(
                      onPressed: () => setState(() => _entriesFuture = _loadEntries()),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('REINTENTAR'),
                    ),
                  );
                }

                final entries = (snapshot.data ?? const <_CatalogEntry>[]).where((entry) {
                  final searchable =
                      '${entry.title} ${entry.category} ${entry.genres.join(' ')} ${entry.synopsis ?? ''}'
                          .toLowerCase();
                  return query.isEmpty || searchable.contains(query);
                }).toList(growable: false);

                if (entries.isEmpty) {
                  return _MessageState(
                    icon: Icons.video_library_outlined,
                    message: query.isEmpty
                        ? 'Todavía no hay contenido publicado para esta sección.'
                        : 'No hay títulos que coincidan con la búsqueda.',
                    detail: query.isEmpty
                        ? 'Cuando cargues contenido autorizado en Supabase y lo marques como publicado, aparecerá acá.'
                        : 'Probá con otro título, categoría o género.',
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth > 900
                        ? 4
                        : constraints.maxWidth > 550
                            ? 3
                            : 2;
                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: entries.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: .68,
                      ),
                      itemBuilder: (context, index) => _CatalogCard(entry: entries[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}


String _catalogCategoryIcon(String value) {
  final category = value.trim().toLowerCase();
  if (category.contains('deport') || category.contains('sport')) return '⚽';
  if (category.contains('cultur') || category.contains('document')) return '🎭';
  if (category.contains('noticia') || category.contains('news')) return '📰';
  if (category.contains('película') ||
      category.contains('pelicula') ||
      category.contains('cine') ||
      category.contains('movie') ||
      category.contains('explorar')) {
    return '🎬';
  }
  if (category.contains('serie') || category.contains('entreten')) return '🍿';
  if (category.contains('infantil') || category.contains('kids')) return '🧸';
  return '📺';
}

class _CatalogEntry {
  const _CatalogEntry({
    required this.title,
    required this.category,
    required this.genres,
    required this.posterUrl,
    required this.year,
    required this.synopsis,
    required this.streamUrl,
    this.streamUrls = const [],
    required this.seriesId,
  });

  final String title;
  final String category;
  final List<String> genres;
  final String? posterUrl;
  final int? year;
  final String? synopsis;
  final String? streamUrl;
  final List<String> streamUrls;
  final String? seriesId;

  factory _CatalogEntry.fromMovie(MovieModel movie) => _CatalogEntry(
        title: movie.title,
        category: movie.category,
        genres: movie.genres,
        posterUrl: movie.logo,
        year: movie.releaseYear,
        synopsis: movie.synopsis,
        streamUrl: movie.streamUrls.isNotEmpty ? movie.streamUrls.first : movie.urlStream,
        streamUrls: movie.streamUrls,
        seriesId: null,
      );

  factory _CatalogEntry.fromSeries(SeriesModel series) => _CatalogEntry(
        title: series.title,
        category: series.category,
        genres: series.genres,
        posterUrl: series.logo,
        year: series.releaseYear,
        synopsis: series.synopsis,
        streamUrl: null,
        streamUrls: const [],
        seriesId: series.id,
      );

  factory _CatalogEntry.fromSubmission(Map<String, dynamic> item) {
    final isEpisode = item['media_type'] == 'episode';
    final season = (item['season_number'] as num?)?.toInt();
    final episode = (item['episode_number'] as num?)?.toInt();
    final duration = (item['duration_seconds'] as num?)?.toInt();
    final rawTitle = item['title'] as String? ?? 'Sin título';
    final seriesTitle = item['series_title'] as String?;
    return _CatalogEntry(
      title: isEpisode && seriesTitle != null && seriesTitle.trim().isNotEmpty
          ? '$seriesTitle · $rawTitle'
          : rawTitle,
      category: [
        isEpisode ? 'Episodio' : 'Película de la comunidad',
        if (isEpisode && season != null && episode != null) 'T$season E$episode',
        if (duration != null && duration > 0) '${(duration / 60).ceil()} min',
      ].join(' · '),
      genres: const [],
      posterUrl: item['poster_url'] as String?,
      year: null,
      synopsis: item['description'] as String?,
      streamUrl: item['stream_url'] as String?,
      streamUrls: (item['stream_url'] as String?)?.trim().isNotEmpty == true
          ? <String>[(item['stream_url'] as String).trim()]
          : const <String>[],
      seriesId: null,
    );
  }
}

Future<void> _openSeriesEpisodes(
  BuildContext context,
  _CatalogEntry entry,
) async {
  final service = CatalogService();
  try {
    final episodes = await service.getEpisodes(entry.seriesId!);
    if (!context.mounted) return;
    if (episodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta serie todavía no tiene episodios disponibles.')),
      );
      return;
    }
    final selectedEpisode = await showModalBottomSheet<EpisodeModel>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(entry.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: episodes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final episode = episodes[index];
                    return ListTile(
                      leading: const Icon(Icons.play_circle_outline_rounded),
                      title: Text(episode.title),
                      subtitle: Text('Temporada ${episode.seasonNumber} · Episodio ${episode.episodeNumber}'),
                      onTap: () => Navigator.pop(sheetContext, episode),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selectedEpisode == null || !context.mounted) return;
    if (selectedEpisode.streamUrls.isEmpty && selectedEpisode.urlStream.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este episodio todavía no está disponible para reproducir.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogPlayerScreen(
          title: '${entry.title} · T${selectedEpisode.seasonNumber}E${selectedEpisode.episodeNumber}',
          streamUrl: selectedEpisode.streamUrls.isNotEmpty
              ? selectedEpisode.streamUrls.first
              : selectedEpisode.urlStream,
          backupStreamUrls: selectedEpisode.streamUrls.length > 1
              ? selectedEpisode.streamUrls.skip(1).toList(growable: false)
              : const <String>[],
        ),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudieron cargar los episodios. Revisá Supabase y las políticas de lectura.')),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.entry});

  final _CatalogEntry entry;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: entry.streamUrl != null && entry.streamUrl!.trim().isNotEmpty
            ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CatalogPlayerScreen(
                      title: entry.title,
                      streamUrl: entry.streamUrls.isNotEmpty
                          ? entry.streamUrls.first
                          : entry.streamUrl!,
                      backupStreamUrls: entry.streamUrls.length > 1
                          ? entry.streamUrls.skip(1).toList(growable: false)
                          : const <String>[],
                    ),
                  ),
                )
            : entry.seriesId != null
                ? () => _openSeriesEpisodes(context, entry)
                : () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Este título todavía no está disponible para reproducir.'),
                      ),
                    ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Expanded(
            child: Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppTheme.panel,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: Colors.white.withValues(alpha: .07)),
              ),
              child: entry.posterUrl == null || entry.posterUrl!.isEmpty
                  ? const Center(
                      child: Icon(Icons.movie_outlined, size: 48, color: AppTheme.accent),
                    )
                  : CachedNetworkImage(
                      imageUrl: entry.posterUrl!,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 120),
                      placeholder: (_, __) => const Center(
                        child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(Icons.movie_outlined, size: 48, color: AppTheme.accent),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 9),
          Text(entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(
            [if (entry.year != null) entry.year.toString(), entry.category].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.muted, fontSize: 11),
          ),
          if (entry.synopsis != null && entry.synopsis!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              entry.synopsis!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.muted, fontSize: 10, height: 1.25),
            ),
          ],
          ],
        ),
      );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    required this.detail,
    this.action,
  });

  final IconData icon;
  final String message;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: AppTheme.muted),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.5)),
              if (action != null) ...[
                const SizedBox(height: 14),
                action!,
              ],
            ],
          ),
        ),
      );
}
