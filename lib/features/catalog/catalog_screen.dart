import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/media_models.dart';
import '../../services/catalog_service.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.category});

  final String category;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _searchController = TextEditingController();
  final _catalogService = CatalogService();
  late Future<List<_CatalogEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _loadEntries();
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
    _searchController.dispose();
    super.dispose();
  }

  Future<List<_CatalogEntry>> _loadEntries() async {
    if (widget.category == 'SERIES') {
      final series = await _catalogService.getSeries();
      return series.map(_CatalogEntry.fromSeries).toList(growable: false);
    }

    final movies = await _catalogService.getMovies();
    final entries = movies.map(_CatalogEntry.fromMovie).toList(growable: false);
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.category,
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -.5)),
          const SizedBox(height: 7),
          const Text(
            'Contenido publicado desde el catálogo de MILTVPLUS.',
            style: TextStyle(color: AppTheme.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar título, categoría o género',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Borrar búsqueda',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 16),
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
    );
  }
}

class _CatalogEntry {
  const _CatalogEntry({
    required this.title,
    required this.category,
    required this.genres,
    required this.posterUrl,
    required this.year,
    required this.synopsis,
  });

  final String title;
  final String category;
  final List<String> genres;
  final String? posterUrl;
  final int? year;
  final String? synopsis;

  factory _CatalogEntry.fromMovie(MovieModel movie) => _CatalogEntry(
        title: movie.title,
        category: movie.category,
        genres: movie.genres,
        posterUrl: movie.logo,
        year: movie.releaseYear,
        synopsis: movie.synopsis,
      );

  factory _CatalogEntry.fromSeries(SeriesModel series) => _CatalogEntry(
        title: series.title,
        category: series.category,
        genres: series.genres,
        posterUrl: series.logo,
        year: series.releaseYear,
        synopsis: series.synopsis,
      );
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.entry});

  final _CatalogEntry entry;

  @override
  Widget build(BuildContext context) => Column(
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
                  : Image.network(
                      entry.posterUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.muted, fontSize: 11),
          ),
        ],
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
