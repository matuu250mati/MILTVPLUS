import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tv_channel.dart';
import '../../services/catalog_service.dart';
import '../../services/stream_service.dart';
import '../../services/channel_storage_service.dart';
import '../../services/m3u_playlist_service.dart';
import 'live_player_screen.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});
  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  final channels = <TvChannel>[];
  final service = const StreamService();
  final channelStorage = ChannelStorageService();
  final catalogService = CatalogService();
  final m3uPlaylistService = M3uPlaylistService();
  VideoPlayerController? controller;
  String? error;
  bool loading = false;
  bool _loadingChannels = false;
  int selected = -1;
  int _playRequestId = 0;
  String _channelQuery = '';
  final TextEditingController _channelSearchController = TextEditingController();

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
        merged.putIfAbsent(key, () => channel);
      }

      for (final channel in saved) {
        addUnique(channel);
      }

      try {
        final remoteChannels = await catalogService.getChannels();
        for (final channel in remoteChannels) {
          addUnique(TvChannel(name: channel.title, streamUrl: channel.urlStream));
        }
        remoteLoaded = true;
      } catch (_) {
        // Keep local channels usable when Supabase is offline or the user is signed out.
      }

      // On a fresh install, load a curated free-to-air source so the screen
      // does not start empty when neither local channels nor Supabase are configured.
      if (merged.isEmpty) {
        try {
          final publicChannels =
              await m3uPlaylistService.importFromUrl(_curatedFreePlaylist);
          for (final channel in publicChannels) {
            addUnique(channel);
          }
          publicFallbackLoaded = publicChannels.isNotEmpty;
          if (publicFallbackLoaded) {
            await channelStorage.save(merged.values.toList(growable: false));
          }
        } catch (_) {
          // Keep the screen usable even when the public playlist is unavailable.
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
    controller?.dispose();
    _channelSearchController.dispose();
    super.dispose();
  }

  Future<void> addChannel() async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final result = await showDialog<TvChannel>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Agregar señal autorizada'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre del canal')),
              const SizedBox(height: 12),
              TextField(controller: urlController, keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'URL HLS (.m3u8)', hintText: 'https://servidor/stream.m3u8')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCELAR')),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final url = urlController.text.trim();
              final parsedUrl = Uri.tryParse(url);
              if (name.isEmpty || !service.isSupportedHlsUrl(url) || parsedUrl == null || parsedUrl.userInfo.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresá un nombre y una URL HTTP(S) HLS válida.')));
                return;
              }
              Navigator.pop(dialogContext, TvChannel(name: name, streamUrl: url));
            },
            child: const Text('AGREGAR'),
          ),
        ],
      ),
    );
    nameController.dispose();
    urlController.dispose();
    if (result != null && mounted) {
      final normalizedUrl = _streamIdentity(result.streamUrl);
      final duplicate = channels.any(
        (channel) => _streamIdentity(channel.streamUrl) == normalizedUrl,
      );
      if (duplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ese canal ya está guardado.')),
        );
        return;
      }
      setState(() => channels.add(result));
      try {
        await channelStorage.save(channels);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El canal se agregó, pero no se pudo guardar en este dispositivo.')),
          );
        }
      }
      await play(channels.length - 1);
    }
  }

  static const _curatedFreePlaylist =
      'https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8';
  static const _globalPublicPlaylist =
      'https://iptv-org.github.io/iptv/index.m3u';

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
  ];

  Future<void> importPlaylist() async {
    final source = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fuentes de TV en vivo'),
        content: SizedBox(
          width: 520,
          height: 480,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.verified_outlined),
                title: const Text('Lista pública curada'),
                subtitle: const Text('Free-TV · señales gratuitas seleccionadas'),
                onTap: () => Navigator.pop(dialogContext, 'free-tv'),
              ),
              ListTile(
                leading: const Icon(Icons.public_rounded),
                title: const Text('Catálogo público global'),
                subtitle: const Text('IPTV-org · catálogo comunitario internacional'),
                onTap: () => Navigator.pop(dialogContext, 'iptv-org'),
              ),
              const Divider(),
              ..._publicPlaylistSources.map((item) => ListTile(
                    leading: const Icon(Icons.live_tv_rounded),
                    title: Text(item.title),
                    subtitle: Text(item.subtitle),
                    onTap: () => Navigator.pop(dialogContext, item.id),
                  )),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('Usar mi propia lista M3U'),
                subtitle: const Text('Ingresar una URL pública o autorizada'),
                onTap: () => Navigator.pop(dialogContext, 'custom'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCELAR'),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;

    if (source == 'free-tv') {
      await _importPlaylistUrl(_curatedFreePlaylist, 'Free-TV');
      return;
    }
    if (source == 'iptv-org') {
      await _importPlaylistUrl(_globalPublicPlaylist, 'IPTV-org');
      return;
    }
    for (final item in _publicPlaylistSources) {
      if (source == item.id) {
        await _importPlaylistUrl(item.url, item.title);
        return;
      }
    }

    final urlController = TextEditingController();
    final playlistUrl = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importar lista M3U propia'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: urlController,
            keyboardType: TextInputType.url,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'URL pública o autorizada de la lista',
              hintText: 'https://servidor/lista.m3u',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, urlController.text.trim()),
            child: const Text('IMPORTAR'),
          ),
        ],
      ),
    );
    urlController.dispose();
    if (playlistUrl == null || playlistUrl.isEmpty || !mounted) return;
    await _importPlaylistUrl(playlistUrl, 'lista propia');
  }

  Future<void> _importPlaylistUrl(String playlistUrl, String sourceName) async {
    if (!mounted) return;
    setState(() {
      _loadingChannels = true;
      error = null;
    });
    try {
      final imported = await m3uPlaylistService.importFromUrl(playlistUrl);
      final merged = <String, TvChannel>{};
      for (final channel in channels) {
        merged.putIfAbsent(
          _streamIdentity(channel.streamUrl),
          () => channel,
        );
      }
      for (final channel in imported) {
        merged.putIfAbsent(
          _streamIdentity(channel.streamUrl),
          () => channel,
        );
      }
      final combined = merged.values.toList(growable: false);
      await channelStorage.save(combined);
      if (!mounted) return;
      setState(() {
        channels
          ..clear()
          ..addAll(combined);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$sourceName: ${imported.length} señales importadas; ${combined.length} canales únicos guardados. La reproducción se confirma al abrir cada canal.',
          ),
        ),
      );
    } catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo importar $sourceName: $exception')),
      );
    } finally {
      if (mounted) setState(() => _loadingChannels = false);
    }
  }

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
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TV EN VIVO', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  SizedBox(height: 5),
                  Text('Tus señales, en un solo lugar.', style: TextStyle(color: AppTheme.muted)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Recargar lista de canales',
              onPressed: _loadingChannels ? null : () => loadSavedChannels(showFeedback: true),
              icon: Icon(_loadingChannels ? Icons.sync_rounded : Icons.refresh_rounded),
            ),
            const SizedBox(width: 4),
            OutlinedButton.icon(
              onPressed: _loadingChannels ? null : importPlaylist,
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('FUENTES DE TV'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: addChannel,
              icon: const Icon(Icons.add_rounded),
              label: const Text('AGREGAR'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: compact
              ? Column(
                  children: [
                    Expanded(flex: 3, child: _PlayerPanel(controller: controller, loading: loading, error: error)),
                    const SizedBox(height: 12),
                    Expanded(flex: 2, child: _ChannelList(channels: channels, selected: selected, query: _channelQuery, searchController: _channelSearchController, onQueryChanged: (value) => setState(() => _channelQuery = value), onSelect: play)),
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 7, child: _PlayerPanel(controller: controller, loading: loading, error: error)),
                    const SizedBox(width: 14),
                    Expanded(flex: 3, child: _ChannelList(channels: channels, selected: selected, query: _channelQuery, searchController: _channelSearchController, onQueryChanged: (value) => setState(() => _channelQuery = value), onSelect: play)),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({required this.controller, required this.loading, required this.error});
  final VideoPlayerController? controller;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final ready = controller?.value.isInitialized == true;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFF030407), borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: .08))),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (ready)
            Center(child: AspectRatio(
              aspectRatio: controller!.value.aspectRatio > 0 ? controller!.value.aspectRatio : 16 / 9,
              child: VideoPlayer(controller!),
            ))
          else
            const Icon(Icons.live_tv_rounded, size: 70, color: Color(0xFF343A4B)),
          if (loading) const CircularProgressIndicator(),
          if (error != null)
            Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
          if (!ready && !loading && error == null)
            const Positioned(bottom: 28, left: 20, right: 20,
                child: Text('Agregá una URL HLS autorizada para comenzar.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted))),
          if (ready)
            Positioned(
              bottom: 10,
              right: 10,
              child: IconButton.filledTonal(
                onPressed: () => controller!.value.isPlaying ? controller!.pause() : controller!.play(),
                icon: Icon(controller!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChannelList extends StatelessWidget {
  const _ChannelList({
    required this.channels,
    required this.selected,
    required this.query,
    required this.searchController,
    required this.onQueryChanged,
    required this.onSelect,
  });
  final List<TvChannel> channels;
  final int selected;
  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final filteredIndices = <int>[
      for (var i = 0; i < channels.length; i++)
        if (normalizedQuery.isEmpty ||
            channels[i].name.toLowerCase().contains(normalizedQuery) ||
            channels[i].streamUrl.toLowerCase().contains(normalizedQuery))
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
          const Divider(height: 1, color: Color(0x223FFFFF)),
          Expanded(
            child: channels.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(18),
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
                            selected: selected == channelIndex,
                            selectedTileColor: AppTheme.accent.withValues(alpha: .08),
                            onTap: () => onSelect(channelIndex),
                            leading: Icon(Icons.circle, size: 9, color: selected == channelIndex ? AppTheme.accent : AppTheme.muted),
                            title: Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: const Text('HLS', style: TextStyle(color: AppTheme.muted, fontSize: 10)),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
