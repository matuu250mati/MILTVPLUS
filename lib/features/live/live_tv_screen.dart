import 'package:flutter/material.dart';
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
    if (const {'ar', 'arg', 'argentina', 'argentine republic'}.contains(normalized)) return 'Argentina';
    if (const {'us', 'usa', 'united states', 'united states of america'}.contains(normalized)) return 'Estados Unidos';
    if (const {'gb', 'uk', 'united kingdom', 'great britain'}.contains(normalized)) return 'Reino Unido';
    return (value ?? '').trim();
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
        if ((existing.groupTitle == null && channel.groupTitle != null) ||
            (existing.country == null && channel.country != null) ||
            (existing.language == null && channel.language != null) ||
            (existing.category == null && channel.category != null) ||
            (existing.logoUrl == null && channel.logoUrl != null) ||
            (existing.tvgId == null && channel.tvgId != null)) {
          merged[key] = TvChannel(
            name: existing.name,
            streamUrl: existing.streamUrl,
            groupTitle: existing.groupTitle ?? channel.groupTitle,
            country: existing.country ?? channel.country,
            language: existing.language ?? channel.language,
            category: existing.category ?? channel.category,
            logoUrl: existing.logoUrl ?? channel.logoUrl,
            tvgId: existing.tvgId ?? channel.tvgId,
          );
        }
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

      // Deportes merges the global sports list with Argentina's country catalog.
      // Only channels identified as sports are shown in the Deportes section.
      final isSportsScreen = (widget.categoryFilter ?? const <String>[])
          .any((value) => value.trim().toLowerCase() == 'deportes');
      if (isSportsScreen) {
        for (final sourceId in const ['sports', 'argentina']) {
          for (final item in _publicPlaylistSources.where((source) => source.id == sourceId)) {
            try {
              final additionalChannels = await m3uPlaylistService.importFromUrl(item.url);
              for (final channel in additionalChannels) {
                if (_matchesCategoryFilter(channel)) addUnique(channel);
              }
            } catch (_) {
              // Keep local and remote channels if a public source is unavailable.
            }
          }
        }
      }

      // If the primary playlist is unavailable or contains no channels for the
      // selected genre, try a smaller, genre-specific public playlist.
      if (merged.isEmpty) {
        final requested = (widget.categoryFilter ?? const <String>[])
            .map((value) => value.trim().toLowerCase())
            .toSet();
        final sourceId = requested.contains('deportes')
            ? 'sports'
            : requested.contains('noticias')
                ? 'news'
                : requested.contains('tv argentina')
                    ? 'argentina'
                    : requested.contains('cultura/documentales')
                        ? 'culture'
                        : requested.contains('hbo/cine')
                            ? 'movies'
                            : null;
        final sourceUrls = <String>[
          if (sourceId != null)
            ..._publicPlaylistSources
                .where((source) => source.id == sourceId)
                .map((source) => source.url),
          if (sourceId == null && (widget.categoryFilter == null || widget.categoryFilter!.isEmpty))
            _curatedFreePlaylist,
        ];
        for (final sourceUrl in sourceUrls) {
          try {
            final publicChannels = await m3uPlaylistService.importFromUrl(sourceUrl);
            for (final channel in publicChannels) {
              if (_matchesCategoryFilter(channel)) addUnique(channel);
            }
            if (merged.isNotEmpty) {
              publicFallbackLoaded = true;
              if (widget.categoryFilter == null || widget.categoryFilter!.isEmpty) {
                await channelStorage.save(merged.values.toList(growable: false));
              }
              break;
            }
          } catch (_) {
            // Continue to the next safe public source.
          }
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
  static const _curatedFreePlaylist =
      'https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8';

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
    final size = MediaQuery.sizeOf(context);
    // Avoid squeezing channel labels into a narrow side column on phones/tablets.
    final compact = size.width < 900;
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
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      tooltip: 'Volver al inicio',
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.categoryFilter == null
                                ? 'TV EN VIVO'
                                : widget.categoryFilter!.contains('Deportes')
                                    ? 'DEPORTES'
                                    : 'TV EN VIVO',
                            maxLines: 2,
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 21 : 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${channels.length} señales disponibles · elegí una para reproducir',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
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

String _normalizeCountry(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  if (const {'ar', 'arg', 'argentina', 'argentine republic'}.contains(normalized)) return 'argentina';
  if (const {'us', 'usa', 'united states', 'united states of america'}.contains(normalized)) return 'united states';
  if (const {'gb', 'uk', 'united kingdom', 'great britain'}.contains(normalized)) return 'united kingdom';
  return normalized;
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
    return Container(
      decoration: BoxDecoration(color: AppTheme.panel.withValues(alpha: .92), borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: .07))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 17, 16, 12),
              child: Text('CANALES', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
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
              padding: EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text('CATEGORÍA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.muted)),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final value in <String>['Todos', ...groups])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(value),
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
              padding: EdgeInsets.fromLTRB(12, 6, 12, 4),
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
                        label: Text(value),
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
                                if (channel.country?.isNotEmpty == true) channel.country!,
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
