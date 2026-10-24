import 'package:flutter/material.dart';
import '../../core/country_preference.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tv_channel.dart';
import '../../services/catalog_service.dart';
import '../../services/channel_storage_service.dart';
import '../../services/m3u_playlist_service.dart';
import 'live_player_screen.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key, this.categoryFilter, required this.onBack});

  /// When set, fetches published Supabase channels only from these categories.
  /// Local M3U channels are retained only when their metadata/name matches.
  final List<String>? categoryFilter;

  /// Returns to the Home/Dashboard when Android or a TV remote sends Back.
  final VoidCallback onBack;

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  final channels = <TvChannel>[];
  final channelStorage = ChannelStorageService();
  final catalogService = CatalogService();
  final m3uPlaylistService = M3uPlaylistService();
  bool _loadingChannels = false;
  int selected = -1;
  String _channelQuery = '';
  String _selectedGroup = 'Todos';
  String _selectedCountry = 'Todos';
  final TextEditingController _channelSearchController = TextEditingController();

  bool _matchesCategoryFilter(TvChannel channel) {
    final requested = widget.categoryFilter;
    // La sección general de TV en vivo excluye deportes: ese catálogo
    // se consulta únicamente desde la sección DEPORTES. El filtro usa la
    // clasificación canónica para M3U local, listas públicas y Supabase.
    if (requested == null || requested.isEmpty) {
      return channel.liveSection.trim().toLowerCase() != 'deportes';
    }

    final allowed = requested
        .map((value) => value.trim().toLowerCase())
        .toSet();
    return allowed.contains(channel.liveSection.trim().toLowerCase());
  }

  String _countryLabel(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    const labels = <String, String>{
      'ar': 'Argentina', 'arg': 'Argentina', 'argentina': 'Argentina',
      'argentine republic': 'Argentina',
      'us': 'Estados Unidos', 'usa': 'Estados Unidos',
      'united states': 'Estados Unidos',
      'united states of america': 'Estados Unidos',
      'gb': 'Reino Unido', 'uk': 'Reino Unido',
      'united kingdom': 'Reino Unido', 'great britain': 'Reino Unido',
      'es': 'España', 'spain': 'España', 'esp': 'España',
      'br': 'Brasil', 'brazil': 'Brasil', 'bra': 'Brasil',
      'mx': 'México', 'mexico': 'México', 'mex': 'México',
      'uy': 'Uruguay', 'ury': 'Uruguay',
      'cl': 'Chile', 'chl': 'Chile',
      'co': 'Colombia', 'col': 'Colombia',
      'pe': 'Perú', 'peru': 'Perú', 'per': 'Perú',
      'it': 'Italia', 'ita': 'Italia',
      'fr': 'Francia', 'fra': 'Francia',
      'de': 'Alemania', 'deu': 'Alemania',
      'pt': 'Portugal', 'prt': 'Portugal',
      'ca': 'Canadá', 'canada': 'Canadá', 'can': 'Canadá',
      'au': 'Australia', 'aus': 'Australia',
      'jp': 'Japón', 'japan': 'Japón', 'jpn': 'Japón',
    };
    return labels[normalized] ?? (value ?? '').trim();
  }

  String _streamIdentity(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty) return value.trim();
    return uri
        .replace(
          scheme: uri.scheme.toLowerCase(),
          host: uri.host.toLowerCase(),
          path: uri.normalizePath().path,
          fragment: '',
        )
        .toString();
  }

  @override
  void initState() {
    super.initState();
    loadSavedChannels();
    _applySavedCountry();
  }

  /// Opens Live TV already filtered to the country the user picked at sign-up.
  /// If no channel matches that country the list falls back to "Todos".
  Future<void> _applySavedCountry() async {
    final code = await CountryPreference.load();
    if (code == null || !mounted) return;
    setState(() => _selectedCountry = _countryLabel(code));
  }

  Future<void> loadSavedChannels({bool showFeedback = false}) async {
    if (_loadingChannels) return;
    setState(() => _loadingChannels = true);
    var remoteLoaded = false;
    var publicFallbackLoaded = false;
    try {
      final saved = await channelStorage.load();
      final merged = <String, TvChannel>{};

      void addUnique(TvChannel channel) {
        final key = _streamIdentity(channel.streamUrl);
        final existing = merged[key];
        if (existing == null) {
          merged[key] = channel;
          return;
        }
        final backupUrls = <String>{
          ...existing.backupStreamUrls,
          ...channel.streamUrls.where((url) => url != existing.streamUrl),
        }.where((url) => url != existing.streamUrl).toList(growable: false);
        merged[key] = TvChannel(
          name: existing.name,
          streamUrl: existing.streamUrl,
          groupTitle: existing.groupTitle ?? channel.groupTitle,
          country: existing.country ?? channel.country,
          language: existing.language ?? channel.language,
          category: channel.category ?? existing.category,
          logoUrl: existing.logoUrl ?? channel.logoUrl,
          tvgId: existing.tvgId ?? channel.tvgId,
          backupStreamUrls: backupUrls,
        );
      }

      for (final channel in saved) {
        if (_matchesCategoryFilter(channel)) addUnique(channel);
      }

      try {
        final remoteChannels = await catalogService.getChannels(
          categories: widget.categoryFilter,
        );
        for (final channel in remoteChannels) {
          final mappedChannel = TvChannel(
            name: channel.title,
            streamUrl: channel.urlStream,
            category: channel.category,
            country: channel.countryCode,
            backupStreamUrls: channel.streamUrls
                .where((url) => url != channel.urlStream)
                .toList(growable: false),
          );
          if (_matchesCategoryFilter(mappedChannel)) {
            addUnique(mappedChannel);
          }
        }
        remoteLoaded = true;
      } catch (_) {
        // Keep local channels usable when Supabase is offline or the user is signed out.
      }

      // Load the repository-owned playlist as the primary M3U source on
      // both the unified TV screen and genre-specific screens.
      try {
        final repositoryChannels =
            await m3uPlaylistService.importFromUrl(_repositoryPlaylist);
        for (final channel in repositoryChannels) {
          if (_matchesCategoryFilter(channel)) addUnique(channel);
        }
        publicFallbackLoaded = repositoryChannels.isNotEmpty;
        if (widget.categoryFilter == null || widget.categoryFilter!.isEmpty) {
          await channelStorage.save(merged.values.toList(growable: false));
        }
      } catch (_) {
        // Continue with Supabase and cached channels when GitHub Raw is offline.
      }

      // Cada sección importa sus propias listas públicas de canales lineales.
      // Estas fuentes NO se mezclan con el catálogo VOD de películas, series o anime.
      final requested = (widget.categoryFilter ?? const <String>[])
          .map((value) => value.trim().toLowerCase())
          .toSet();
      final sourceIds = <String>{};
      if (requested.isNotEmpty) {
        if (requested.any((value) => ['deportes', 'sports', 'sport'].contains(value))) {
          sourceIds.addAll(['sports', 'argentina']);
        }
        if (requested.any((value) => ['noticias', 'news'].contains(value))) {
          sourceIds.add('news');
        }
        if (requested.any((value) => ['tv argentina', 'argentina'].contains(value))) {
          sourceIds.add('argentina');
        }
        if (requested.any((value) => ['cultura/documentales', 'culture', 'documentary'].contains(value))) {
          sourceIds.addAll(['culture', 'documentary', 'science', 'education', 'travel']);
        }
        if (requested.any((value) => ['hbo/cine', 'movies', 'cinema'].contains(value))) {
          sourceIds.add('movies');
        }
        if (requested.any((value) => ['series en vivo', 'series'].contains(value))) {
          sourceIds.add('series');
        }
        if (requested.any((value) => ['entretenimiento y general', 'entertainment', 'general'].contains(value))) {
          sourceIds.addAll(['entertainment', 'general', 'comedy', 'cooking', 'classic', 'auto', 'business', 'weather']);
        }
        if (requested.any((value) => ['infantiles', 'kids'].contains(value))) {
          sourceIds.addAll(['kids', 'animation']);
        }
        if (requested.any((value) => ['música', 'musica', 'music'].contains(value))) {
          sourceIds.add('music');
        }
      }

      for (final item in _publicPlaylistSources.where((source) => sourceIds.contains(source.id))) {
        try {
          final additionalChannels = await m3uPlaylistService.importFromUrl(item.url);
          final sourceCategory = _sourceCategory(item.id);
          for (final channel in additionalChannels) {
            final categorizedChannel = TvChannel(
              name: channel.name,
              streamUrl: channel.streamUrl,
              groupTitle: channel.groupTitle,
              country: channel.country,
              language: channel.language,
              category: sourceCategory ?? channel.category,
              logoUrl: channel.logoUrl,
              tvgId: channel.tvgId,
              backupStreamUrls: channel.backupStreamUrls,
            );
            if (_matchesCategoryFilter(categorizedChannel)) addUnique(categorizedChannel);
          }
          publicFallbackLoaded = publicFallbackLoaded || additionalChannels.isNotEmpty;
        } catch (_) {
          // Una lista pública puede estar caída o geobloqueada; conservamos las demás fuentes.
        }
      }

      if (!mounted) return;
      setState(() {
        channels
          ..clear()
          ..addAll(merged.values);
        if (selected >= channels.length) selected = -1;
      });

      if (showFeedback) {
        final message = publicFallbackLoaded
            ? 'Lista pública inicial cargada: ${channels.length} señales. La reproducción se verifica al abrir cada canal.'
            : remoteLoaded
                ? 'Lista recargada: ${channels.length} señales disponibles.'
                : 'Lista local recargada. No se pudo actualizar el catálogo remoto.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo leer la lista local de canales.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingChannels = false);
    }
  }

  @override
  void dispose() {
    _channelSearchController.dispose();
    super.dispose();
  }

  static const _repositoryPlaylist =
      'https://raw.githubusercontent.com/matuu250mati/MILTVPLUS/main/IPTV-URL.TXT';

  static const _publicPlaylistSources = <({String id, String title, String subtitle, String url})>[
    (
      id: 'argentina',
      title: 'Argentina',
      subtitle: 'IPTV-org · canales catalogados por país',
      url: 'https://iptv-org.github.io/iptv/countries/ar.m3u',
    ),
    (
      id: 'spanish',
      title: 'Canales en español',
      subtitle: 'IPTV-org · canales catalogados por idioma',
      url: 'https://iptv-org.github.io/iptv/languages/spa.m3u',
    ),
    (
      id: 'news',
      title: 'Noticias',
      subtitle: 'IPTV-org · canales informativos en vivo',
      url: 'https://iptv-org.github.io/iptv/categories/news.m3u',
    ),
    (
      id: 'sports',
      title: 'Deportes',
      subtitle: 'IPTV-org · canales deportivos en vivo',
      url: 'https://iptv-org.github.io/iptv/categories/sports.m3u',
    ),
    (
      id: 'movies',
      title: 'Canales de películas',
      subtitle: 'IPTV-org · canales lineales, no catálogo VOD',
      url: 'https://iptv-org.github.io/iptv/categories/movies.m3u',
    ),
    (
      id: 'series',
      title: 'Canales de series',
      subtitle: 'IPTV-org · canales lineales, no episodios a demanda',
      url: 'https://iptv-org.github.io/iptv/categories/series.m3u',
    ),
    (
      id: 'documentary',
      title: 'Documentales',
      subtitle: 'IPTV-org · canales documentales en vivo',
      url: 'https://iptv-org.github.io/iptv/categories/documentary.m3u',
    ),
    (
      id: 'kids',
      title: 'Infantiles',
      subtitle: 'IPTV-org · canales infantiles en vivo',
      url: 'https://iptv-org.github.io/iptv/categories/kids.m3u',
    ),
    (
      id: 'music',
      title: 'Música',
      subtitle: 'IPTV-org · canales musicales en vivo',
      url: 'https://iptv-org.github.io/iptv/categories/music.m3u',
    ),
    (
      id: 'culture',
      title: 'Cultura y educación',
      subtitle: 'IPTV-org · señales culturales y educativas en vivo',
      url: 'https://iptv-org.github.io/iptv/categories/culture.m3u',
    ),
    (
      id: 'entertainment',
      title: 'Entretenimiento y general',
      subtitle: 'IPTV-org · señales generales de televisión en vivo',
      url: 'https://iptv-org.github.io/iptv/categories/entertainment.m3u',
    ),
    (
      id: 'general',
      title: 'Canales generales',
      subtitle: 'IPTV-org · señales generalistas en vivo',
      url: 'https://iptv-org.github.io/iptv/categories/general.m3u',
    ),
    (
      id: 'animation',
      title: 'Animación',
      subtitle: 'IPTV-org · canales de animación; no equivale a catálogo anime',
      url: 'https://iptv-org.github.io/iptv/categories/animation.m3u',
    ),
    (
      id: 'comedy',
      title: 'Comedia',
      subtitle: 'IPTV-org · canales de comedia en vivo',
      url: 'https://iptv-org.github.io/iptv/categories/comedy.m3u',
    ),
    (
      id: 'cooking',
      title: 'Cocina',
      subtitle: 'IPTV-org · canales de cocina en vivo',
      url: 'https://iptv-org.github.io/iptv/categories/cooking.m3u',
    ),
    (
      id: 'travel',
      title: 'Viajes',
      subtitle: 'IPTV-org · canales de viajes en vivo',
      url: 'https://iptv-org.github.io/iptv/categories/travel.m3u',
    ),
    (
      id: 'science',
      title: 'Ciencia',
      subtitle: 'IPTV-org · canales de ciencia en vivo',
      url: 'https://iptv-org.github.io/iptv/categories/science.m3u',
    ),
    (
      id: 'education',
      title: 'Educación',
      subtitle: 'IPTV-org · canales educativos en vivo',
      url: 'https://iptv-org.github.io/iptv/categories/education.m3u',
    ),
    (
      id: 'business',
      title: 'Negocios',
      subtitle: 'IPTV-org · canales de negocios en vivo',
      url: 'https://iptv-org.github.io/iptv/categories/business.m3u',
    ),
    (
      id: 'weather',
      title: 'Clima',
      subtitle: 'IPTV-org · canales meteorológicos en vivo',
      url: 'https://iptv-org.github.io/iptv/categories/weather.m3u',
    ),
    (
      id: 'classic',
      title: 'TV clásica',
      subtitle: 'IPTV-org · canales de televisión clásica en vivo',
      url: 'https://iptv-org.github.io/iptv/categories/classic.m3u',
    ),
    (
      id: 'auto',
      title: 'Autos y motorización',
      subtitle: 'IPTV-org · canales de automoción en vivo',
      url: 'https://iptv-org.github.io/iptv/categories/auto.m3u',
    ),
  ];

  Future<void> play(int index) async {
    if (index < 0 || index >= channels.length || !mounted) return;
    // Open the selected signal directly in the dedicated immersive player.
    // The player owns its controller and disposes it when the viewer exits.
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LivePlayerScreen(
          channels: List<TvChannel>.unmodifiable(channels),
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = channels.map((channel) => channel.liveSection).toSet().toList()..sort();
    final countries = channels
        .map((channel) => _countryLabel(channel.country))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()..sort();
    final activeGroup = groups.contains(_selectedGroup) ? _selectedGroup : 'Todos';
    final activeCountry = countries.contains(_selectedCountry) ? _selectedCountry : 'Todos';

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onBack();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Volver al inicio',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${channels.length} señales disponibles',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _ChannelList(
              channels: channels,
              selected: selected,
              query: _channelQuery,
              searchController: _channelSearchController,
              selectedGroup: activeGroup,
              groups: groups,
              selectedCountry: activeCountry,
              countries: countries,
              onQueryChanged: (value) => setState(() => _channelQuery = value),
              onGroupChanged: (value) => setState(() => _selectedGroup = value),
              onCountryChanged: (value) => setState(() => _selectedCountry = value),
              onSelect: play,
              loading: _loadingChannels,
            ),
          ),
        ],
      ),
    );
  }

}


String? _sourceCategory(String id) {
  switch (id) {
    case 'sports':
      return 'Deportes';
    case 'news':
      return 'Noticias';
    case 'movies':
      return 'HBO/Cine';
    case 'series':
      return 'Series en vivo';
    case 'documentary':
    case 'culture':
    case 'science':
    case 'education':
    case 'travel':
      return 'Cultura/Documentales';
    case 'kids':
    case 'animation':
      return 'Infantiles';
    case 'music':
      return 'Música';
    case 'entertainment':
    case 'general':
    case 'comedy':
    case 'cooking':
    case 'classic':
    case 'auto':
    case 'business':
    case 'weather':
      return 'Entretenimiento y general';
    default:
      return null;
  }
}

String _countryFlag(String value) {
  final code = value.trim().toUpperCase();
  if (code == 'TODOS' || code.isEmpty) return '';
  if (code.length == 2 &&
      code.codeUnits.every((unit) => unit >= 65 && unit <= 90)) {
    return String.fromCharCodes(code.codeUnits.map((unit) => 0x1F1E6 + unit - 65));
  }
  const known = <String, String>{
    'ARGENTINA': '🇦🇷',
    'ESTADOS UNIDOS': '🇺🇸',
    'UNITED STATES': '🇺🇸',
    'REINO UNIDO': '🇬🇧',
    'UNITED KINGDOM': '🇬🇧',
    'ESPAÑA': '🇪🇸',
    'SPAIN': '🇪🇸',
    'BRASIL': '🇧🇷',
    'BRAZIL': '🇧🇷',
    'MÉXICO': '🇲🇽',
    'MEXICO': '🇲🇽',
    'URUGUAY': '🇺🇾',
    'CHILE': '🇨🇱',
    'COLOMBIA': '🇨🇴',
    'PERÚ': '🇵🇪',
    'PERU': '🇵🇪',
  };
  return known[code] ?? '🌐';
}

String _categoryIcon(String value) {
  final category = value.trim().toLowerCase();
  if (category == 'todos') return '📺';
  if (category.contains('deport') || category.contains('sport')) return '⚽';
  if (category.contains('noticia') || category.contains('news')) return '📰';
  if (category.contains('cultur') || category.contains('document')) return '🎭';
  if (category.contains('película') ||
      category.contains('pelicula') ||
      category.contains('cine') ||
      category.contains('movie')) {
    return '🎬';
  }
  if (category.contains('entreten') || category.contains('series')) return '🍿';
  if (category.contains('infantil') || category.contains('kids')) return '🧸';
  if (category.contains('música') || category.contains('music')) return '🎵';
  if (category.contains('educación') || category.contains('educacion')) return '📚';
  return '📺';
}

String _normalizeCountry(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  // M3U providers mix ISO-2/ISO-3 codes and country names. Normalize both
  // sides to the same canonical value so selecting a flag chip actually filters.
  const aliases = <String, String>{
    'ar': 'argentina', 'arg': 'argentina', 'argentina': 'argentina',
    'argentine republic': 'argentina',
    'us': 'united states', 'usa': 'united states',
    'united states': 'united states', 'estados unidos': 'united states',
    'estados unidos de américa': 'united states',
    'united states of america': 'united states',
    'gb': 'united kingdom', 'uk': 'united kingdom',
    'united kingdom': 'united kingdom', 'reino unido': 'united kingdom',
    'great britain': 'united kingdom',
    'es': 'spain', 'esp': 'spain', 'spain': 'spain', 'españa': 'spain',
    'br': 'brazil', 'bra': 'brazil', 'brazil': 'brazil', 'brasil': 'brazil',
    'mx': 'mexico', 'mex': 'mexico', 'mexico': 'mexico', 'méxico': 'mexico',
    'uy': 'uruguay', 'ury': 'uruguay', 'uruguay': 'uruguay',
    'cl': 'chile', 'chl': 'chile', 'chile': 'chile',
    'co': 'colombia', 'col': 'colombia', 'colombia': 'colombia',
    'pe': 'peru', 'per': 'peru', 'peru': 'peru', 'perú': 'peru',
    'it': 'italy', 'ita': 'italy', 'italy': 'italy', 'italia': 'italy',
    'fr': 'france', 'fra': 'france', 'france': 'france', 'francia': 'france',
    'de': 'germany', 'deu': 'germany', 'germany': 'germany', 'alemania': 'germany',
    'pt': 'portugal', 'prt': 'portugal', 'portugal': 'portugal',
    'ca': 'canada', 'can': 'canada', 'canada': 'canada', 'canadá': 'canada',
    'au': 'australia', 'aus': 'australia', 'australia': 'australia',
    'jp': 'japan', 'jpn': 'japan', 'japan': 'japan', 'japón': 'japan',
  };
  return aliases[normalized] ?? normalized;
}

class _ChannelList extends StatelessWidget {
  const _ChannelList({
    required this.channels,
    required this.selected,
    required this.query,
    required this.searchController,
    required this.selectedGroup,
    required this.groups,
    required this.selectedCountry,
    required this.countries,
    required this.onQueryChanged,
    required this.onGroupChanged,
    required this.onCountryChanged,
    required this.onSelect,
    this.loading = false,
  });
  final List<TvChannel> channels;
  final int selected;
  final String query;
  final TextEditingController searchController;
  final String selectedGroup;
  final List<String> groups;
  final String selectedCountry;
  final List<String> countries;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onGroupChanged;
  final ValueChanged<String> onCountryChanged;
  final ValueChanged<int> onSelect;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final filteredIndices = <int>[
      for (var i = 0; i < channels.length; i++)
        if ((normalizedQuery.isEmpty ||
                channels[i].name.toLowerCase().contains(normalizedQuery) ||
                channels[i].streamUrl.toLowerCase().contains(normalizedQuery) ||
                (channels[i].groupTitle?.toLowerCase().contains(normalizedQuery) ?? false) ||
                (channels[i].country?.toLowerCase().contains(normalizedQuery) ?? false)) &&
            (selectedGroup == 'Todos' || channels[i].liveSection == selectedGroup) &&
            (selectedCountry == 'Todos' || _normalizeCountry(channels[i].country) == _normalizeCountry(selectedCountry)))
          i,
    ];
    return ColoredBox(
      color: AppTheme.panel.withValues(alpha: .35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(8, 10, 8, 8),
              child: Text('CANALES', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: TextField(
              controller: searchController,
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Buscar canal o país...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar búsqueda',
                        onPressed: () {
                          searchController.clear();
                          onQueryChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (groups.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(6, 8, 6, 4),
              child: Text('CATEGORÍA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.muted)),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                children: [
                  for (final value in <String>['Todos', ...groups])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('${_categoryIcon(value)} $value'),
                        selected: selectedGroup == value,
                        autofocus: selectedGroup == value,
                        onSelected: (_) => onGroupChanged(value),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (countries.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(6, 6, 6, 4),
              child: Text('PAÍS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.muted)),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final value in <String>['Todos', ...countries])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('${_countryFlag(value)} $value'),
                        selected: selectedCountry == value,
                        onSelected: (_) => onCountryChanged(value),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const Divider(height: 1, color: Color(0x223FFFFF)),
          Expanded(
            child: channels.isEmpty
                ? loading
                    ? const Center(child: CircularProgressIndicator())
                    : const Center(child: Padding(padding: EdgeInsets.all(18),
                        child: Text('Todavía no hay canales. Elegí una fuente pública o importá tu lista M3U.',
                            textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted, height: 1.5))))
                : filteredIndices.isEmpty
                    ? const Center(child: Padding(padding: EdgeInsets.all(18),
                        child: Text('No se encontraron canales con esa búsqueda.',
                            textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted))))
                    : ListView.separated(
                        itemCount: filteredIndices.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x1AFFFFFF)),
                        itemBuilder: (context, index) {
                          final channelIndex = filteredIndices[index];
                          final channel = channels[channelIndex];
                          return ListTile(
                            // Native Flutter focus support for Android TV / TV Box D-pad.
                            // Keep the existing layout; only expose a visible focus highlight.
                            autofocus: index == 0,
                            focusColor: AppTheme.accent.withValues(alpha: .16),
                            selected: selected == channelIndex,
                            selectedTileColor: AppTheme.accent.withValues(alpha: .08),
                            onTap: () => onSelect(channelIndex),
                            leading: channel.logoUrl?.isNotEmpty == true
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  channel.logoUrl!,
                                  width: 42,
                                  height: 32,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.live_tv_rounded,
                                    color: selected == channelIndex ? AppTheme.accent : AppTheme.muted,
                                  ),
                                ),
                              )
                            : Icon(Icons.live_tv_rounded, size: 22, color: selected == channelIndex ? AppTheme.accent : AppTheme.muted),
                            title: Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              [
                                if (channel.groupTitle?.isNotEmpty == true) channel.groupTitle!,
                                if (channel.country?.isNotEmpty == true) '${_countryFlag(channel.country!)} ${channel.country!}',
                                if (channel.groupTitle == null && channel.country == null) 'TV EN VIVO',
                              ].join(' · '),
                              style: const TextStyle(color: AppTheme.muted, fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
