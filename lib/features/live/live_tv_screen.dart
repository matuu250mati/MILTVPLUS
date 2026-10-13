import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tv_channel.dart';
import '../../services/catalog_service.dart';
import '../../services/stream_service.dart';
import '../../services/channel_storage_service.dart';
import '../../services/m3u_playlist_service.dart';

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

  @override
  void initState() {
    super.initState();
    loadSavedChannels();
  }

  Future<void> loadSavedChannels({bool showFeedback = false}) async {
    if (_loadingChannels) return;
    setState(() => _loadingChannels = true);
    var remoteLoaded = false;
    try {
      final saved = await channelStorage.load();
      final merged = <String, TvChannel>{};

      void addUnique(TvChannel channel) {
        final key = '${channel.name.trim().toLowerCase()}|${channel.streamUrl.trim()}';
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

      if (!mounted) return;
      setState(() {
        channels
          ..clear()
          ..addAll(merged.values);
        if (selected >= channels.length) selected = -1;
      });

      if (showFeedback) {
        final message = remoteLoaded
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
              if (name.isEmpty || !service.isSupportedHlsUrl(url)) {
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

  Future<void> importPlaylist() async {
    final urlController = TextEditingController(
      text: 'https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8',
    );
    final playlistUrl = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importar lista M3U'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: urlController,
            keyboardType: TextInputType.url,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'URL pública o autorizada de la lista',
              hintText: 'https://servidor/lista.m3u8',
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

    setState(() {
      _loadingChannels = true;
      error = null;
    });
    try {
      final imported = await m3uPlaylistService.importFromUrl(playlistUrl);
      final merged = <String, TvChannel>{};
      for (final channel in channels) {
        merged.putIfAbsent(
          '${channel.name.trim().toLowerCase()}|${channel.streamUrl.trim()}',
          () => channel,
        );
      }
      for (final channel in imported) {
        merged.putIfAbsent(
          '${channel.name.trim().toLowerCase()}|${channel.streamUrl.trim()}',
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
            'Importación terminada: ${imported.length} señales leídas; ${combined.length} canales únicos guardados. La reproducción se verifica al abrir cada canal.',
          ),
        ),
      );
    } catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo importar la lista: $exception')),
      );
    } finally {
      if (mounted) setState(() => _loadingChannels = false);
    }
  }

  Future<void> play(int index) async {
    if (index < 0 || index >= channels.length) return;

    final requestId = ++_playRequestId;
    final channel = channels[index];
    final old = controller;
    setState(() {
      loading = true;
      error = null;
      selected = index;
      controller = null;
    });

    // Stop the previous signal immediately so audio never leaks across channels.
    try {
      await old?.pause();
    } catch (_) {
      // A controller may already be shutting down during rapid channel changes.
    }
    try {
      await old?.dispose();
    } catch (_) {
      // Continue opening the requested channel even if cleanup of the old one fails.
    }

    VideoPlayerController? next;
    Object? lastError;
    try {
      for (var attempt = 1; attempt <= 3; attempt++) {
        final candidate =
            VideoPlayerController.networkUrl(Uri.parse(channel.streamUrl));
        try {
          await candidate.initialize().timeout(const Duration(seconds: 20));
          next = candidate;
          break;
        } catch (exception) {
          lastError = exception;
          await candidate.dispose();
          if (attempt < 3) {
            await Future<void>.delayed(Duration(seconds: attempt));
          }
        }
      }

      if (next == null) {
        throw StateError('HLS initialization failed after retries: $lastError');
      }
      if (!mounted || requestId != _playRequestId) {
        await next.dispose();
        return;
      }

      await next.play();
      if (!mounted || requestId != _playRequestId) {
        await next.dispose();
        return;
      }
      setState(() {
        controller = next;
        loading = false;
      });
    } catch (_) {
      await next?.dispose();
      if (!mounted || requestId != _playRequestId) return;
      setState(() {
        controller = null;
        loading = false;
        error =
            'No se pudo abrir la señal tras 3 intentos. Verificá URL, conexión, formato HLS y permisos de la fuente.';
      });
    }
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
              label: const Text('IMPORTAR M3U'),
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
                    Expanded(flex: 2, child: _ChannelList(channels: channels, selected: selected, onSelect: play)),
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 7, child: _PlayerPanel(controller: controller, loading: loading, error: error)),
                    const SizedBox(width: 14),
                    Expanded(flex: 3, child: _ChannelList(channels: channels, selected: selected, onSelect: play)),
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
  const _ChannelList({required this.channels, required this.selected, required this.onSelect});
  final List<TvChannel> channels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: AppTheme.panel.withValues(alpha: .92), borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: .07))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 17, 16, 12),
                child: Text('CANALES', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2))),
            const Divider(height: 1, color: Color(0x223FFFFF)),
            Expanded(
              child: channels.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.all(18),
                      child: Text('Todavía no hay canales. Agregá una URL HLS desde el botón superior.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted, height: 1.5))))
                  : ListView.separated(
                      itemCount: channels.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x1AFFFFFF)),
                      itemBuilder: (context, index) => ListTile(
                        selected: selected == index,
                        selectedTileColor: AppTheme.accent.withValues(alpha: .08),
                        onTap: () => onSelect(index),
                        leading: Icon(Icons.circle, size: 9, color: selected == index ? AppTheme.accent : AppTheme.muted),
                        title: Text(channels[index].name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: const Text('HLS', style: TextStyle(color: AppTheme.muted, fontSize: 10)),
                      ),
                    ),
            ),
          ],
        ),
      );
}
