import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';
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
  String _genreFilter = 'Todos';
  String _yearFilter = 'Todos';
  final _catalogService = CatalogService();
  late Future<List<MovieModel>> _moviesFuture;

  @override
  void initState() {
    super.initState();
    _moviesFuture = _catalogService.getMovies();
  }

  Widget _buildRemoteMovies() {
    final query = _searchController.text.trim().toLowerCase();
    return FutureBuilder<List<MovieModel>>(
      future: _moviesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off_rounded, size: 42),
                const SizedBox(height: 12),
                const Text('No se pudo cargar el catálogo de Supabase.', textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(snapshot.error.toString(), textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => setState(() { _moviesFuture = _catalogService.getMovies(); }),
                  icon: const Icon(Icons.refresh_rounded), label: const Text('REINTENTAR'),
                ),
              ]),
            ),
          );
        }
        final movies = (snapshot.data ?? const <MovieModel>[]).where((movie) {
          final searchable = '${movie.title} ${movie.category} ${movie.genres.join(' ')} ${movie.synopsis ?? ''}'.toLowerCase();
          return query.isEmpty || searchable.contains(query);
        }).toList(growable: false);
        if (movies.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(query.isEmpty
                ? 'No hay películas visibles. Verificá que estén publicadas y que la sesión tenga permiso de lectura.'
                : 'No hay películas que coincidan con la búsqueda.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.muted, height: 1.5)),
          ));
        }
        return LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 550 ? 3 : 2;
          return GridView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: movies.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns, crossAxisSpacing: 14,
              mainAxisSpacing: 14, childAspectRatio: .68,
            ),
            itemBuilder: (context, index) {
              final movie = movies[index];
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Container(
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppTheme.panel,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: Colors.white.withValues(alpha: .07)),
                  ),
                  child: movie.logo == null || movie.logo!.isEmpty
                      ? const Center(child: Icon(Icons.movie_outlined, size: 48, color: AppTheme.accent))
                      : Image.network(movie.logo!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.movie_outlined, size: 48, color: AppTheme.accent))),
                )),
                const SizedBox(height: 9),
                Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text([if (movie.releaseYear != null) movie.releaseYear.toString(), movie.category].join(' · '),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
              ]);
            },
          );
        });
      },
    );
  }

  List<MediaItem> get items {
    if (widget.category == 'PELÍCULAS') {
      return const [
        MediaItem(title: 'Horizonte', subtitle: 'Ciencia ficción · 2025', category: 'PELÍCULAS', symbol: '✦'),
        MediaItem(title: 'Zona Cero', subtitle: 'Acción · 2024', category: 'PELÍCULAS', symbol: '◈'),
        MediaItem(title: 'Noche Azul', subtitle: 'Drama · 2025', category: 'PELÍCULAS', symbol: '◉'),
        MediaItem(title: 'Último Viaje', subtitle: 'Aventura · 2023', category: 'PELÍCULAS', symbol: '✧'),
      ];
    }
    if (widget.category == 'SERIES') {
      return const [
        MediaItem(title: 'Distrito 9', subtitle: 'Thriller · 2 temporadas', category: 'SERIES', symbol: '▣'),
        MediaItem(title: 'Código Norte', subtitle: 'Suspenso · 1 temporada', category: 'SERIES', symbol: '⌘'),
        MediaItem(title: 'Frecuencia', subtitle: 'Drama · 3 temporadas', category: 'SERIES', symbol: '◉'),
      ];
    }
    if (widget.category == 'ANIME') {
      return const [
        MediaItem(title: 'Luna de Acero', subtitle: 'Anime · Acción', category: 'ANIME', symbol: '月'),
        MediaItem(title: 'Neo Tokio', subtitle: 'Anime · Sci-fi', category: 'ANIME', symbol: '新'),
        MediaItem(title: 'Espíritu Rojo', subtitle: 'Anime · Fantasía', category: 'ANIME', symbol: '火'),
      ];
    }
    if (widget.category == 'DEPORTES') {
      return const [
        MediaItem(title: 'En vivo', subtitle: 'Deportes · Directo', category: 'DEPORTES', symbol: '⚽'),
        MediaItem(title: 'Resumen deportivo', subtitle: 'Destacados · Recap', category: 'DEPORTES', symbol: '🏆'),
        MediaItem(title: 'Documentales deportivos', subtitle: 'Documental · Archivo', category: 'DEPORTES', symbol: '◉'),
      ];
    }
    if (widget.category == 'INFANTIL') {
      return const [
        MediaItem(title: 'Pequeñas aventuras', subtitle: 'Animación · Familiar', category: 'INFANTIL', symbol: '★'),
        MediaItem(title: 'Planeta curioso', subtitle: 'Educativo · Infantil', category: 'INFANTIL', symbol: '◎'),
        MediaItem(title: 'Cuentos de colores', subtitle: 'Cuentos · Familiar', category: 'INFANTIL', symbol: '✿'),
      ];
    }
    if (widget.category == 'GRATIS') {
      return const [
        MediaItem(title: 'Cine abierto', subtitle: 'Selección gratuita', category: 'GRATIS', symbol: '✦'),
        MediaItem(title: 'Clásicos para descubrir', subtitle: 'Dominio público', category: 'GRATIS', symbol: '◈'),
        MediaItem(title: 'Canales abiertos', subtitle: 'TV · Fuente autorizada', category: 'GRATIS', symbol: '▣'),
      ];
    }
    return const [
      MediaItem(title: 'Novedades', subtitle: 'Explorá lo nuevo', category: 'EXPLORAR', symbol: '✦'),
      MediaItem(title: 'Recomendados', subtitle: 'Selección editorial', category: 'EXPLORAR', symbol: '◈'),
      MediaItem(title: 'Para descubrir', subtitle: 'Encontrá tu próxima historia', category: 'EXPLORAR', symbol: '◎'),
    ];
  }

  String _genre(MediaItem item) => item.subtitle.split('·').first.trim();

  String? _year(MediaItem item) {
    final match = RegExp(r'\b(?:19|20)\d{2}\b').firstMatch(item.subtitle);
    return match?.group(0);
  }

  List<String> get genres => ['Todos', ...{
        for (final item in items) _genre(item),
      }.toList()..sort()];

  List<String> get years => [
        'Todos',
        ...{
          for (final item in items)
            if (_year(item) != null) _year(item)!,
        }.toList()
          ..sort((a, b) => b.compareTo(a)),
      ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.category == 'PELÍCULAS') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('PELÍCULAS', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -.5)),
          const SizedBox(height: 7),
          const Text('Catálogo conectado a Supabase.', style: TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar película o género',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty ? null : IconButton(
                tooltip: 'Borrar búsqueda',
                onPressed: () { _searchController.clear(); setState(() {}); },
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildRemoteMovies()),
        ]),
      );
    }
    final query = _searchController.text.trim().toLowerCase();
    final filtered = items.where((item) {
      final matchesQuery = query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.subtitle.toLowerCase().contains(query);
      final matchesGenre = _genreFilter == 'Todos' || _genre(item) == _genreFilter;
      final matchesYear = _yearFilter == 'Todos' || _year(item) == _yearFilter;
      return matchesQuery && matchesGenre && matchesYear;
    }).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        Text(widget.category,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -.5)),
        const SizedBox(height: 7),
        const Text(
          'Catálogo de demostración. Para cargar bibliotecas masivas, configurá un proveedor de contenido autorizado.',
          style: TextStyle(color: AppTheme.muted),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar título o género',
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
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String>(
                initialValue: _genreFilter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Género'),
                items: genres.map((genre) => DropdownMenuItem(value: genre, child: Text(genre))).toList(),
                onChanged: (value) => setState(() => _genreFilter = value ?? 'Todos'),
              ),
            ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                initialValue: _yearFilter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Año'),
                items: years.map((year) => DropdownMenuItem(value: year, child: Text(year))).toList(),
                onChanged: (value) => setState(() => _yearFilter = value ?? 'Todos'),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                _genreFilter = 'Todos';
                _yearFilter = 'Todos';
                _searchController.clear();
              }),
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Limpiar filtros'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('No hay títulos que coincidan con estos filtros.')),
          )
        else
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 550 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: .73,
              ),
              itemBuilder: (context, index) => _MediaCard(item: filtered[index], index: index),
            );
          }),
      ],
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.item, required this.index});
  final MediaItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    const colors = [Color(0xFF29314F), Color(0xFF3A254A), Color(0xFF1E4146), Color(0xFF4A3529)];
    final color = colors[index % colors.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, AppTheme.panel],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: .07)),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 10,
                  bottom: 2,
                  child: Text(item.symbol,
                      style: TextStyle(fontSize: 70, color: Colors.white.withValues(alpha: .09))),
                ),
                Center(
                  child: Text(item.symbol,
                      style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w300, color: AppTheme.accent)),
                ),
                const Positioned(
                  top: 10,
                  left: 10,
                  child: Icon(Icons.play_circle_outline_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
      ],
    );
  }
}
