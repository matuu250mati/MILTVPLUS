import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_item.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, required this.category});
  final String category;

  List<MediaItem> get items {
    if (category == 'PELÍCULAS') {
      return const [
        MediaItem(title: 'Horizonte', subtitle: 'Ciencia ficción · 2025', category: 'PELÍCULAS', symbol: '✦'),
        MediaItem(title: 'Zona Cero', subtitle: 'Acción · 2024', category: 'PELÍCULAS', symbol: '◈'),
        MediaItem(title: 'Noche Azul', subtitle: 'Drama · 2025', category: 'PELÍCULAS', symbol: '◉'),
        MediaItem(title: 'Último Viaje', subtitle: 'Aventura · 2023', category: 'PELÍCULAS', symbol: '✧'),
      ];
    }
    if (category == 'SERIES') {
      return const [
        MediaItem(title: 'Distrito 9', subtitle: 'Thriller · 2 temporadas', category: 'SERIES', symbol: '▣'),
        MediaItem(title: 'Código Norte', subtitle: 'Suspenso · 1 temporada', category: 'SERIES', symbol: '⌘'),
        MediaItem(title: 'Frecuencia', subtitle: 'Drama · 3 temporadas', category: 'SERIES', symbol: '◉'),
      ];
    }
    if (category == 'ANIME') {
      return const [
        MediaItem(title: 'Luna de Acero', subtitle: 'Anime · Acción', category: 'ANIME', symbol: '月'),
        MediaItem(title: 'Neo Tokio', subtitle: 'Anime · Sci-fi', category: 'ANIME', symbol: '新'),
        MediaItem(title: 'Espíritu Rojo', subtitle: 'Anime · Fantasía', category: 'ANIME', symbol: '火'),
      ];
    }
    return const [
      MediaItem(title: 'Novedades', subtitle: 'Explorá lo nuevo', category: 'EXPLORAR', symbol: '✦'),
      MediaItem(title: 'Recomendados', subtitle: 'Selección editorial', category: 'EXPLORAR', symbol: '◈'),
      MediaItem(title: 'Para descubrir', subtitle: 'Encontrá tu próxima historia', category: 'EXPLORAR', symbol: '◎'),
    ];
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          Text(category, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -.5)),
          const SizedBox(height: 7),
          const Text('Catálogo visual de muestra. Conectá tu proveedor de contenido autorizado.',
              style: TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 550 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: .73,
              ),
              itemBuilder: (context, index) => _MediaCard(item: items[index], index: index),
            );
          }),
        ],
      );
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
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, AppTheme.panel]),
              border: Border.all(color: Colors.white.withOpacity(.07)),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 10,
                  bottom: 2,
                  child: Text(item.symbol, style: TextStyle(fontSize: 70, color: Colors.white.withOpacity(.09))),
                ),
                Center(child: Text(item.symbol, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w300, color: AppTheme.accent))),
                const Positioned(top: 10, left: 10, child: Icon(Icons.play_circle_outline_rounded, color: Colors.white70)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
      ],
    );
  }
}
