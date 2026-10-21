import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/tv_channel.dart';
import '../../services/hls_variant_service.dart';

class LivePlayerScreen extends StatefulWidget {
  const LivePlayerScreen({
    super.key,
    required this.channels,
    required this.initialIndex,
  });

  final List<TvChannel> channels;
  final int initialIndex;

  @override
  State<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends State<LivePlayerScreen> {
  final _variantService = HlsVariantService();
  VideoPlayerController? _controller;
  WebViewController? _webController;
  bool _webMode = false;
  List<HlsVariant> _variants = const [];
  int _index = 0;
  int _requestId = 0;
  String? _error;
  bool _loading = true;
  bool _controlsVisible = true;
  bool _variantsLoading = false;
  bool _recovering = false;
  int _activeStreamIndex = 0;
  Timer? _hideControlsTimer;

  TvChannel get _channel => widget.channels.isEmpty
      ? const TvChannel(name: 'Sin canales disponibles', streamUrl: '')
      : widget.channels[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.channels.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.channels.length - 1).toInt();
    if (widget.channels.isEmpty) {
      _loading = false;
      _error = 'No hay canales disponibles. Importá una lista M3U o recargá el catálogo.';
    }
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (widget.channels.isNotEmpty) {
      _openChannel(_index);
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _requestId++;
    final current = _controller;
    _controller = null;
    if (current != null) unawaited(current.dispose());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _showControls() {
    if (!mounted) return;
    setState(() => _controlsVisible = true);
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      // Embedded official web players have no VideoPlayerController; their
      // overlay must still auto-hide so the page remains interactive.
      if (mounted && (_webMode || _controller?.value.isPlaying == true)) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  Future<void> _openChannel(
    int index, {
    String? streamOverride,
    int startFrom = 0,
    bool recovering = false,
  }) async {
    if (widget.channels.isEmpty || index < 0 || index >= widget.channels.length) return;
    final request = ++_requestId;
    final channel = widget.channels[index];
    final urls = <String>[];
    for (final raw in [
      if (streamOverride != null) streamOverride,
      ...channel.streamUrls,
    ]) {
      final value = raw.trim();
      if (value.isNotEmpty && !urls.contains(value)) urls.add(value);
    }

    final previous = _controller;
    _controller = null;
    _webController = null;
    _webMode = false;
    setState(() {
      _index = index;
      _loading = true;
      _error = null;
      _variants = const [];
      _variantsLoading = false;
      _controlsVisible = true;
      _recovering = recovering;
    });
    try {
      await previous?.pause();
    } catch (_) {}
    try {
      await previous?.dispose();
    } catch (_) {}
    if (!mounted || request != _requestId) return;

    var lastFailure = 'No se encontró una fuente de reproducción válida.';
    for (var candidateIndex = startFrom; candidateIndex < urls.length; candidateIndex++) {
      final uri = Uri.tryParse(urls[candidateIndex]);
      if (uri == null ||
          !uri.hasAuthority ||
          uri.userInfo.isNotEmpty ||
          uri.scheme != 'https') {
        lastFailure = 'Se omitió una URL de transmisión no válida.';
        continue;
      }

      // Some broadcasters publish their official live signal as a YouTube
      // live page instead of a direct HLS URL. Keep this limited to YouTube
      // hosts; arbitrary web pages are still rejected by the playlist parser.
      if (_isSupportedWebPlayerUrl(uri)) {
        try {
          final web = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(Colors.black);
          await web.loadRequest(uri).timeout(const Duration(seconds: 12));
          if (!mounted || request != _requestId) return;
          _webController = web;
          _webMode = true;
          _activeStreamIndex = candidateIndex;
          setState(() {
            _loading = false;
            _error = null;
            _recovering = false;
          });
          _showControls();
          return;
        } catch (_) {
          if (!mounted || request != _requestId) return;
          lastFailure = 'No se pudo abrir el reproductor oficial de YouTube.';
          continue;
        }
      }

      final next = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      try {
        await next.initialize().timeout(const Duration(seconds: 12));
        if (!mounted || request != _requestId) {
          await next.dispose();
          return;
        }
        next.setLooping(false);
        await next.play();
        if (!mounted || request != _requestId) {
          await next.dispose();
          return;
        }
        _activeStreamIndex = candidateIndex;
        _controller = next;
        next.addListener(() => _handleControllerUpdate(next, request));
        setState(() {
          _loading = false;
          _error = null;
          _recovering = false;
        });
        _showControls();
        unawaited(_loadVariants(urls[candidateIndex], request));
        return;
      } catch (_) {
        try {
          await next.dispose();
        } catch (_) {}
        if (!mounted || request != _requestId) return;
        lastFailure = 'La fuente no respondió o no pudo iniciar la reproducción.';
      }
    }

    if (!mounted || request != _requestId) return;
    setState(() {
      _loading = false;
      _recovering = false;
      _error = urls.isEmpty
          ? 'Este canal todavía no tiene una URL de transmisión publicada.'
          : 'No se pudo reproducir esta señal con las fuentes disponibles. $lastFailure';
    });
  }

  bool _isSupportedWebPlayerUrl(Uri uri) {
    if (uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    const youtubeHosts = <String>{
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
      'youtu.be',
      'youtube-nocookie.com',
      'www.youtube-nocookie.com',
    };
    // Telefe's own live page hosts its player on mitelefe.com. Allow only
    // that broadcaster domain and YouTube, not arbitrary web pages.
    return youtubeHosts.contains(host) ||
        host == 'mitelefe.com' ||
        host.endsWith('.mitelefe.com');
  }

  void _handleControllerUpdate(VideoPlayerController controller, int request) {
    if (!mounted ||
        request != _requestId ||
        !identical(_controller, controller) ||
        !controller.value.hasError ||
        _recovering) {
      return;
    }
    // Runtime failures (for example, expired URLs or a stopped HLS origin)
    // trigger a silent attempt at the next configured mirror.
    _recoverFromFailure(controller, request);
  }

  Future<void> _recoverFromFailure(
    VideoPlayerController controller,
    int request,
  ) async {
    if (_recovering ||
        request != _requestId ||
        !identical(_controller, controller)) {
      return;
    }
    _recovering = true;
    final nextIndex = _activeStreamIndex + 1;
    await _openChannel(_index, startFrom: nextIndex, recovering: true);
  }

  Future<void> _loadVariants(String source, int request) async {
    if (mounted) setState(() => _variantsLoading = true);
    final variants = await _variantService.loadVariants(source);
    if (!mounted || request != _requestId) return;
    setState(() {
      _variants = variants;
      _variantsLoading = false;
    });
  }

  Future<void> _chooseQuality(HlsVariant variant) async {
    if (variant.url.isEmpty || variant.url == _channel.streamUrl) {
      await _openChannel(_index);
      return;
    }
    await _openChannel(_index, streamOverride: variant.url);
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
    _showControls();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.channelUp) {
      if (widget.channels.isEmpty) return KeyEventResult.handled;
      _openChannel((_index - 1 + widget.channels.length) % widget.channels.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.channelDown) {
      if (widget.channels.isEmpty) return KeyEventResult.handled;
      _openChannel((_index + 1) % widget.channels.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.mediaPlayPause || key == LogicalKeyboardKey.space) {
      _togglePlayback();
      _showControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.backspace) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      _showControls();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller?.value.isInitialized == true;
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _webMode ? null : _showControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_webMode && _webController != null)
                Listener(
                  // Pointer listeners do not claim the gesture, so the web
                  // player remains tappable while a hidden app overlay can be
                  // brought back with a touch.
                  onPointerDown: (_) {
                    if (!_controlsVisible) _showControls();
                  },
                  child: WebViewWidget(controller: _webController!),
                )
              else if (ready)
                Center(
                  child: AspectRatio(
                    aspectRatio: controller!.value.aspectRatio > 0
                        ? controller.value.aspectRatio
                        : 16 / 9,
                    child: VideoPlayer(controller),
                  ),
                )
              else if (!_loading && _error == null)
                const Center(child: Icon(Icons.live_tv, size: 76, color: Colors.white24)),
              if (_loading)
                const Center(child: CircularProgressIndicator(color: Colors.white)),
              if (_error != null)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.signal_wifi_connected_no_internet_4, size: 44, color: Colors.white70),
                          const SizedBox(height: 16),
                          Text(_channel.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: () => _openChannel(_index),
                                icon: const Icon(Icons.refresh),
                                label: const Text('REINTENTAR'),
                              ),
                              OutlinedButton(
                                onPressed: widget.channels.length > 1
                                    ? () => _openChannel((_index + 1) % widget.channels.length)
                                    : null,
                                child: const Text('SIGUIENTE CANAL'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_controlsVisible)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xCC000000), Colors.transparent, Color(0xD9000000)],
                          stops: [0, .42, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_controlsVisible)
                Positioned(
                  top: 8,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      IconButton(
                        autofocus: false,
                        onPressed: () => Navigator.of(context).maybePop(),
                        color: Colors.white,
                        tooltip: 'Volver',
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_channel.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                            Text('EN VIVO · Canal ${_index + 1} de ${widget.channels.length}',
                                style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                      if (_variantsLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      PopupMenuButton<HlsVariant>(
                        tooltip: 'Configurar calidad de imagen',
                        onSelected: _chooseQuality,
                        color: const Color(0xFF17191F),
                        itemBuilder: (context) => [
                          const PopupMenuItem<HlsVariant>(
                            value: HlsVariant(url: '', label: 'Auto'),
                            child: Text('Automática (adaptativa)', style: TextStyle(color: Colors.white)),
                          ),
                          if (_variants.isEmpty)
                            const PopupMenuItem<HlsVariant>(
                              enabled: false,
                              child: Text(
                                'El proveedor no publica calidades manuales',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                          ..._variants.map((variant) => PopupMenuItem<HlsVariant>(
                            value: variant,
                            child: Text(variant.label, style: const TextStyle(color: Colors.white)),
                          )),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.settings_rounded, color: Colors.white),
                              SizedBox(width: 6),
                              Text('CALIDAD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_controlsVisible)
                Positioned(
                  bottom: 18,
                  left: 20,
                  right: 20,
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: widget.channels.length > 1
                            ? () => _openChannel((_index - 1 + widget.channels.length) % widget.channels.length)
                            : null,
                        tooltip: 'Canal anterior',
                        icon: const Icon(Icons.skip_previous),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        onPressed: _togglePlayback,
                        tooltip: controller?.value.isPlaying == true ? 'Pausar' : 'Reproducir',
                        icon: Icon(controller?.value.isPlaying == true ? Icons.pause : Icons.play_arrow),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        onPressed: widget.channels.length > 1
                            ? () => _openChannel((_index + 1) % widget.channels.length)
                            : null,
                        tooltip: 'Canal siguiente',
                        icon: const Icon(Icons.skip_next),
                      ),
                      const Spacer(),
                      const Text('↑/↓ CAMBIAR CANAL', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
