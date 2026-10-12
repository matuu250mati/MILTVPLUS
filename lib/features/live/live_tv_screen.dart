import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tv_channel.dart';
import '../../services/stream_service.dart';
import '../../services/channel_storage_service.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});
  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  final channels = <TvChannel>[];
  final service = const StreamService();
  final channelStorage = ChannelStorageService();
  VideoPlayerController? controller;
  String? error;
  bool loading = false;
  int selected = -1;

  @override
  void initState() {
    super.initState();
    loadSavedChannels();
  }

  Future<void> loadSavedChannels() async {
    try {
      final saved = await channelStorage.load();
      if (!mounted) return;
      setState(() => channels.addAll(saved));
    } catch (_) {
      // Playback UI remains available if local preferences cannot be read.
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

  Future<void> play(int index) async {
    final channel = channels[index];
    setState(() {
      loading = true;
      error = null;
      selected = index;
    });
    final old = controller;
    try {
      // Keep the current stream alive while the next source initializes.
      final next = VideoPlayerController.networkUrl(Uri.parse(channel.streamUrl));
      await next.initialize().timeout(const Duration(seconds: 20));
      if (!mounted) {
        await next.dispose();
        return;
      }
      await next.play();
      setState(() {
        controller = next;
        loading = false;
      });
      await old?.dispose();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'No se pudo abrir la señal. Verificá URL, conexión, formato HLS y permisos de la fuente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;
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
            FilledButton.icon(onPressed: addChannel, icon: const Icon(Icons.add_rounded), label: const Text('AGREGAR')),
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
