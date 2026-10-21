import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Reproduce una fuente autorizada del catálogo en una vista inmersiva.
/// La selección manual de calidad requiere que el proveedor publique variantes
/// de video (por ejemplo, un manifiesto HLS maestro); una URL única no permite
/// cambiar de resolución desde video_player.
class CatalogPlayerScreen extends StatefulWidget {
  const CatalogPlayerScreen({
    super.key,
    required this.title,
    required this.streamUrl,
    this.backupStreamUrls = const [],
  });

  final String title;
  final String streamUrl;
  final List<String> backupStreamUrls;

  @override
  State<CatalogPlayerScreen> createState() => _CatalogPlayerScreenState();
}

class _CatalogPlayerScreenState extends State<CatalogPlayerScreen> {
  VideoPlayerController? _controller;
  String? _error;
  bool _loading = true;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _enterImmersiveMode();
    _initialize();
  }

  Future<void> _enterImmersiveMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _initialize() async {
    final urls = <String>[];
    for (final raw in [widget.streamUrl, ...widget.backupStreamUrls]) {
      final value = raw.trim();
      if (value.isNotEmpty && !urls.contains(value)) urls.add(value);
    }

    String? lastError;
    for (final value in urls) {
      final uri = Uri.tryParse(value);
      if (uri == null ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.scheme != 'https') {
        lastError = 'Se omitió una fuente no válida.';
        continue;
      }

      VideoPlayerController? candidate;
      try {
        candidate = VideoPlayerController.networkUrl(uri);
        await candidate.initialize().timeout(const Duration(seconds: 9));
        if (!mounted) {
          await candidate.dispose();
          return;
        }
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
        return;
      } catch (_) {
        await candidate?.dispose();
        lastError = 'Una fuente no respondió o no admite este formato.';
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = urls.isEmpty
          ? 'Este título todavía no tiene fuentes de reproducción publicadas.'
          : 'No se pudo iniciar la reproducción. Se probaron las fuentes disponibles. ${lastError ?? ''}';
    });
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _initialize();
  }

  Future<void> _closePlayer() async {
    await _restoreSystemUi();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _restoreSystemUi();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  KeyEventResult _handleRemoteKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final controller = _controller;
    final value = controller?.value;
    if (controller == null || value == null || !value.isInitialized) {
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        _closePlayer();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      if (value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
      if (!_showControls && mounted) setState(() => _showControls = true);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final delta = event.logicalKey == LogicalKeyboardKey.arrowLeft
          ? const Duration(seconds: -10)
          : const Duration(seconds: 10);
      final target = value.position + delta;
      final duration = value.duration;
      final bounded = target < Duration.zero
          ? Duration.zero
          : target > duration
              ? duration
              : target;
      controller.seekTo(bounded);
      if (!_showControls && mounted) setState(() => _showControls = true);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (!_showControls && mounted) setState(() => _showControls = true);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      _closePlayer();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Offset? _lastDoubleTapPosition;

  void _handleDoubleTapSeek() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final position = _lastDoubleTapPosition;
    if (position == null) return;
    final width = MediaQuery.sizeOf(context).width;
    final delta = position.dx < width / 2
        ? const Duration(seconds: -10)
        : const Duration(seconds: 10);
    final target = controller.value.position + delta;
    final duration = controller.value.duration;
    final bounded = target < Duration.zero
        ? Duration.zero
        : target > duration
            ? duration
            : target;
    controller.seekTo(bounded);
    if (!_showControls && mounted) setState(() => _showControls = true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller?.value.isInitialized == true;
    return Focus(
      autofocus: true,
      onKeyEvent: _handleRemoteKey,
      child: PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) _restoreSystemUi();
        },
        child: Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 42),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              children: [
                                FilledButton.icon(
                                  onPressed: _retry,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('REINTENTAR'),
                                ),
                                OutlinedButton(
                                  onPressed: _closePlayer,
                                  child: const Text('VOLVER'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _showControls = !_showControls),
                      onDoubleTapDown: (details) {
                        _lastDoubleTapPosition = details.localPosition;
                      },
                      onDoubleTap: _handleDoubleTapSeek,
                      child: Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.center,
                        children: [
                          if (ready) Center(child: AspectRatio(
                            aspectRatio: controller!.value.aspectRatio > 0
                                ? controller.value.aspectRatio
                                : 16 / 9,
                            child: VideoPlayer(controller),
                          )),
                          if (_showControls) ...[
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xB8000000), Colors.transparent, Color(0xD9000000)],
                                  stops: [0, .45, 1],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              left: 12,
                              right: 12,
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Volver',
                                    onPressed: _closePlayer,
                                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                                  ),
                                  Expanded(
                                    child: Text(widget.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.hd_outlined, color: Colors.white70, size: 20),
                                  const SizedBox(width: 5),
                                  const Text('Automática según la fuente',
                                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                                ],
                              ),
                            ),
                            Center(
                              child: ValueListenableBuilder<VideoPlayerValue>(
                                valueListenable: controller!,
                                builder: (context, value, _) => IconButton.filledTonal(
                                  tooltip: value.isPlaying ? 'Pausar' : 'Reproducir',
                                  iconSize: 42,
                                  onPressed: () => value.isPlaying ? controller.pause() : controller.play(),
                                  icon: Icon(value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 20,
                              right: 20,
                              bottom: 14,
                              child: ValueListenableBuilder<VideoPlayerValue>(
                                valueListenable: controller,
                                builder: (context, value, _) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    VideoProgressIndicator(
                                      controller,
                                      allowScrubbing: true,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      colors: const VideoProgressColors(
                                        playedColor: Color(0xFF39FF14),
                                        bufferedColor: Colors.white38,
                                        backgroundColor: Colors.white24,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(_formatDuration(value.position),
                                          style: const TextStyle(fontSize: 12, color: Colors.white)),
                                        const Spacer(),
                                        Text(_formatDuration(value.duration),
                                          style: const TextStyle(fontSize: 12, color: Colors.white)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
          ),
        ),
      ),
    );
  }
}
