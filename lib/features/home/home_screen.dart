import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/media_models.dart';
import '../../services/catalog_service.dart';
import '../catalog/catalog_player_screen.dart';

/// Responsive streaming dashboard. All media rows are populated from the
/// published catalog; no sample channels or fictional titles are injected.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CatalogService _catalog = CatalogService();
  late Future<_HomeData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_HomeData> _loadData() async {
    final results = await Future.wait<dynamic>([
      _safeChannels(),
      _safeMovies(),
      _safeSeries(),
    ]);
    return _HomeData(
      channels: results[0] as List<ChannelModel>,
      movies: results[1] as List<MovieModel>,
      series: results[2] as List<SeriesModel>,
    );
  }

  Future<List<ChannelModel>> _safeChannels() async {
    try {
      return await _catalog.getChannels();
    } catch (_) {
      return const [];
    }
  }

  Future<List<MovieModel>> _safeMovies() async {
    try {
      return await _catalog.getMovies();
    } catch (_) {
      return const [];
    }
  }

  Future<List<SeriesModel>> _safeSeries() async {
    try {
      return await _catalog.getSeries();
    } catch (_) {
      return const [];
    }
  }

  void _reload() => setState(() => _dataFuture = _loadData());

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 620;
        final medium = width >= 620 && width < 1000;
        final side = compact ? 10.0 : medium ? 18.0 : 24.0;
        return FutureBuilder<_HomeData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              );
            }
            final data = snapshot.data ?? const _HomeData.empty();
            return RefreshIndicator(
              color: AppTheme.accent,
              onRefresh: () async => _reloadAndWait(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(side, 8, side, compact ? 24 : 28),
                children: [
                  _DashboardHeader(
                    compact: compact,
                    onNavigate: widget.onNavigate,
                    onMenu: () => Scaffold.of(context).openDrawer(),
                  ),
                  SizedBox(height: compact ? 14 : 20),
                  _HeroBanner(
                    compact: compact,
                    onPlay: () => widget.onNavigate(5),
                  ),
                  SizedBox(height: compact ? 16 : 20),
                  _CategoryStrip(
                    compact: compact,
                    width: width,
                    onNavigate: widget.onNavigate,
                  ),
                  SizedBox(height: compact ? 20 : 26),
                  _SectionHeader(
                    title: 'Canales en vivo',
                    icon: Icons.live_tv_rounded,
                    color: const Color(0xFF18F17B),
                    onSeeAll: () => widget.onNavigate(0),
                  ),
                  const SizedBox(height: 10),
                  if (data.channels.isEmpty)
                    _EmptyRow(
                      message: 'Los canales publicados aparecerán acá.',
                      actionLabel: 'Abrir TV en vivo',
                      onAction: () => widget.onNavigate(0),
                    )
                  else
                    _ChannelRail(
                      channels: data.channels.take(compact ? 8 : 12).toList(),
                      compact: compact,
                      onOpenLive: () => widget.onNavigate(0),
                    ),
                  SizedBox(height: compact ? 20 : 26),
                  _SectionHeader(
                    title: 'Películas populares',
                    icon: Icons.local_movies_rounded,
                    color: const Color(0xFF18F17B),
                    onSeeAll: () => widget.onNavigate(2),
                  ),
                  const SizedBox(height: 10),
                  if (data.movies.isEmpty)
                    _EmptyRow(
                      message: 'Todavía no hay películas publicadas.',
                      actionLabel: 'Explorar catálogo',
                      onAction: () => widget.onNavigate(8),
                    )
                  else
                    _PosterRail<MovieModel>(
                      items: data.movies,
                      compact: compact,
                      titleOf: (item) => item.title,
                      imageOf: (item) => item.logo,
                      subtitleOf: (item) => [
                        if (item.releaseYear != null) item.releaseYear.toString(),
                        item.category,
                      ].join(' · '),
                      onTap: (item) => _openMovie(item),
                    ),
                  SizedBox(height: compact ? 20 : 26),
                  _SectionHeader(
                    title: 'Series destacadas',
                    icon: Icons.video_library_rounded,
                    color: const Color(0xFFCA5BFF),
                    onSeeAll: () => widget.onNavigate(3),
                  ),
                  const SizedBox(height: 10),
                  if (data.series.isEmpty)
                    _EmptyRow(
                      message: 'Las series publicadas aparecerán en esta fila.',
                      actionLabel: 'Ver series',
                      onAction: () => widget.onNavigate(3),
                    )
                  else
                    _PosterRail<SeriesModel>(
                      items: data.series,
                      compact: compact,
                      titleOf: (item) => item.title,
                      imageOf: (item) => item.logo,
                      subtitleOf: (item) => [
                        if (item.releaseYear != null) item.releaseYear.toString(),
                        item.category,
                      ].join(' · '),
                      onTap: (item) => widget.onNavigate(3),
                    ),
                  if (snapshot.hasError) ...[
                    const SizedBox(height: 12),
                    _EmptyRow(
                      message: 'No se pudieron cargar todos los datos.',
                      actionLabel: 'Reintentar',
                      onAction: _reload,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _reloadAndWait() async {
    final next = _loadData();
    setState(() => _dataFuture = next);
    try {
      await next;
    } catch (_) {
      // The section-level empty/error states remain visible and retryable.
    }
  }

  Future<void> _openMovie(MovieModel movie) async {
    if (movie.urlStream.trim().isEmpty) {
      widget.onNavigate(2);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogPlayerScreen(
          title: movie.title,
          streamUrl: movie.urlStream,
        ),
      ),
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.channels,
    required this.movies,
    required this.series,
  });

  const _HomeData.empty()
      : channels = const [],
        movies = const [],
        series = const [];

  final List<ChannelModel> channels;
  final List<MovieModel> movies;
  final List<SeriesModel> series;
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.compact,
    required this.onNavigate,
    required this.onMenu,
  });

  final bool compact;
  final ValueChanged<int> onNavigate;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Abrir menú',
          onPressed: onMenu,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.menu_rounded),
        ),
        Container(
          width: compact ? 38 : 46,
          height: compact ? 38 : 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              colors: [Color(0xFFB8FF35), Color(0xFF00B8FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: .16),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF07101B), size: 32),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 19 : 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -.6,
              ),
              children: const [
                TextSpan(text: 'MILTV '),
                TextSpan(text: 'PLUS', style: TextStyle(color: AppTheme.accent)),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Buscar contenido',
          onPressed: () => onNavigate(8),
          icon: const Icon(Icons.search_rounded),
        ),
        IconButton(
          tooltip: 'Configuración',
          onPressed: () => onNavigate(11),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.compact, required this.onPlay});

  final bool compact;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 218 : 300,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF17608B).withValues(alpha: .75)),
        gradient: const LinearGradient(
          colors: [Color(0xFF102D4D), Color(0xFF07101E), Color(0xFF030812)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: compact ? -20 : 10,
            top: compact ? 8 : 4,
            child: Icon(
              Icons.sports_soccer_rounded,
              size: compact ? 190 : 285,
              color: const Color(0xFFB8FF35).withValues(alpha: .16),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xF5070D18),
                  Color(0xD9070D18),
                  Color(0x65070D18),
                  Color(0x12070D18),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0, .38, .72, 1],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 16 : 26),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 300 : 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const _LivePill(label: 'FÚTBOL · EN VIVO'),
                  const SizedBox(height: 10),
                  Text(
                    'COPA LIBERTADORES',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 25 : 38,
                      height: 1.03,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.7,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Explorá las señales deportivas disponibles en MILTVPLUS.',
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFE1E7F2),
                      height: 1.25,
                      fontSize: compact ? 11 : 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onPlay,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: const Color(0xFF06101B),
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 15 : 22,
                        vertical: compact ? 10 : 14,
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Ver ahora', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accent.withValues(alpha: .45)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.accent,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
      );
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.compact,
    required this.width,
    required this.onNavigate,
  });

  final bool compact;
  final double width;
  final ValueChanged<int> onNavigate;

  static const _categories = <_CategoryInfo>[
    _CategoryInfo('TV en vivo', Icons.live_tv_rounded, Color(0xFF18CFFF), 0),
    _CategoryInfo('Deportes', Icons.sports_soccer_rounded, Color(0xFF18F17B), 5),
    _CategoryInfo('Películas', Icons.local_movies_rounded, Color(0xFF598CFF), 2),
    _CategoryInfo('Series', Icons.video_library_rounded, Color(0xFFCA5BFF), 3),
    _CategoryInfo('Anime', Icons.animation_rounded, Color(0xFFFF674F), 4),
  ];

  @override
  Widget build(BuildContext context) {
    final cardWidth = compact
        ? ((width - 50) / 5).clamp(58.0, 78.0).toDouble()
        : width >= 1200 ? 108.0 : 98.0;
    return SizedBox(
      height: compact ? 92 : 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => SizedBox(width: compact ? 6 : 10),
        itemBuilder: (context, index) {
          final item = _categories[index];
          return SizedBox(
            width: cardWidth,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                focusColor: AppTheme.selectedAccent.withValues(alpha: .24),
                hoverColor: AppTheme.selectedAccent.withValues(alpha: .14),
                onTap: () => onNavigate(item.route),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF08111D).withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: item.color.withValues(alpha: .65), width: 1.1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, color: item.color, size: compact ? 26 : 36),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: compact ? 9.5 : 10.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryInfo {
  const _CategoryInfo(this.title, this.icon, this.color, this.route);
  final String title;
  final IconData icon;
  final Color color;
  final int route;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
    required this.onSeeAll,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -.2),
            ),
          ),
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFBFD8F4),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Ver todos', style: TextStyle(fontSize: 11)),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFBFD8F4), size: 19),
        ],
      );
}

class _ChannelRail extends StatelessWidget {
  const _ChannelRail({required this.channels, required this.compact, required this.onOpenLive});
  final List<ChannelModel> channels;
  final bool compact;
  final VoidCallback onOpenLive;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: compact ? 116 : 138,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: channels.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final channel = channels[index];
            final width = compact ? 142.0 : 168.0;
            return SizedBox(
              width: width,
              child: Material(
                color: const Color(0xB9081121),
                borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  focusColor: AppTheme.selectedAccent.withValues(alpha: .24),
                  hoverColor: AppTheme.selectedAccent.withValues(alpha: .14),
                  onTap: onOpenLive,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0xFF17436C)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Center(
                            child: channel.logo == null || channel.logo!.trim().isEmpty
                                ? const Icon(Icons.live_tv_rounded, size: 30, color: AppTheme.accent)
                                : CachedNetworkImage(
                                    imageUrl: channel.logo!,
                                    fit: BoxFit.contain,
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.live_tv_rounded,
                                      color: AppTheme.accent,
                                      size: 30,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF087B43),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text('VIVO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(channel.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          channel.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.muted, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class _PosterRail<T> extends StatelessWidget {
  const _PosterRail({
    required this.items,
    required this.compact,
    required this.titleOf,
    required this.imageOf,
    required this.subtitleOf,
    required this.onTap,
  });

  final List<T> items;
  final bool compact;
  final String Function(T) titleOf;
  final String? Function(T) imageOf;
  final String Function(T) subtitleOf;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    final cardWidth = compact ? 112.0 : 142.0;
    return SizedBox(
      height: compact ? 220 : 270,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          final image = imageOf(item);
          return SizedBox(
            width: cardWidth,
            child: InkWell(
              onTap: () => onTap(item),
              focusColor: AppTheme.selectedAccent.withValues(alpha: .24),
              hoverColor: AppTheme.selectedAccent.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppTheme.panel,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1D527A)),
                      ),
                      child: image == null || image.trim().isEmpty
                          ? const Center(child: Icon(Icons.movie_outlined, color: AppTheme.accent, size: 40))
                          : CachedNetworkImage(
                              imageUrl: image,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                                ),
                              ),
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(Icons.movie_outlined, color: AppTheme.accent, size: 40),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    titleOf(item),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, height: 1.15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitleOf(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 9),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppTheme.panel.withValues(alpha: .75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .07)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppTheme.muted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
            ),
            TextButton(onPressed: onAction, child: Text(actionLabel, style: const TextStyle(fontSize: 10))),
          ],
        ),
      );
}
