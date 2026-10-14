import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Reproduces a provider-authorized VOD URL using the native Flutter player.
class CatalogPlayerScreen extends StatefulWidget {
  const CatalogPlayerScreen({
    super.key,
    required this.title,
    required this.streamUrl,
  });

  final String title;
  final String streamUrl;

  @override
  State<CatalogPlayerScreen> createState() => _CatalogPlayerScreenState();
}

class _CatalogPlayerScreenState extends State<CatalogPlayerScreen> {
  VideoPlayerController? _controller;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final uri = Uri.tryParse(widget.streamUrl.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.scheme != 'https') {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'La URL de reproducción del proveedor no es válida.';
        });
      }
      return;
    }

    VideoPlayerController? candidate;
    try {
      candidate = VideoPlayerController.networkUrl(uri);
      await candidate.initialize().timeout(const Duration(seconds: 25));
      await candidate.play();
      if (!mounted) {
        await candidate.dispose();
        return;
      }
      setState(() {
        _controller = candidate;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      await candidate?.dispose();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo reproducir este título. Comprobá que el proveedor habilite esta URL y que el formato sea compatible.';
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller?.value.isInitialized == true;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      backgroundColor: const Color(0xFF080A10),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AspectRatio(
            aspectRatio: ready && controller!.value.aspectRatio > 0
                ? controller.value.aspectRatio
                : 16 / 9,
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: _loading
                  ? const CircularProgressIndicator()
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 42),
                              const SizedBox(height: 12),
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _retry,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('REINTENTAR'),
                              ),
                            ],
                          ),
                        )
                      : ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: controller!,
                          builder: (context, value, _) => Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(controller),
                              IconButton.filledTonal(
                                tooltip: value.isPlaying ? 'Pausar' : 'Reproducir',
                                iconSize: 36,
                                onPressed: () => value.isPlaying
                                    ? controller.pause()
                                    : controller.play(),
                                icon: Icon(value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded),
                              ),
                              Positioned(
                                left: 12,
                                right: 12,
                                bottom: 10,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    VideoProgressIndicator(
                                      controller,
                                      allowScrubbing: true,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      colors: const VideoProgressColors(
                                        playedColor: Color(0xFFE50914),
                                        bufferedColor: Colors.white38,
                                        backgroundColor: Colors.white24,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          _formatDuration(value.position),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _formatDuration(value.duration),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ),
        ),
      ),
    );
  }
}
