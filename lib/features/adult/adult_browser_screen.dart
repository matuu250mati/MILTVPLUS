import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';

/// In-app adult browser. It intentionally keeps navigation state in memory only;
/// provider-side logging and tracking remain outside the app's control.
class AdultBrowserScreen extends StatefulWidget {
  const AdultBrowserScreen({super.key, required this.onLock});

  final VoidCallback onLock;

  @override
  State<AdultBrowserScreen> createState() => _AdultBrowserScreenState();
}

class _AdultBrowserScreenState extends State<AdultBrowserScreen> {
  static const _providers = <_AdultProvider>[
    _AdultProvider('Pornhub', 'https://www.pornhub.com/', 'https://www.pornhub.com/favicon.ico', Icons.play_circle_filled_rounded),
    _AdultProvider('XVideos', 'https://www.xvideos.com/', 'https://www.xvideos.com/favicon.ico', Icons.movie_rounded),
    _AdultProvider('XNXX', 'https://www.xnxx.com/', 'https://www.xnxx.com/favicon.ico', Icons.video_library_rounded),
    _AdultProvider('RedTube', 'https://www.redtube.com/', 'https://www.redtube.com/favicon.ico', Icons.smart_display_rounded),
    _AdultProvider('xHamster', 'https://xhamster.com/', 'https://xhamster.com/favicon.ico', Icons.ondemand_video_rounded),
    _AdultProvider('YouPorn', 'https://www.youporn.com/', 'https://www.youporn.com/favicon.ico', Icons.play_circle_outline_rounded),
    _AdultProvider('SpankBang', 'https://spankbang.com/', 'https://spankbang.com/favicon.ico', Icons.video_collection_rounded),
    _AdultProvider('Eporner', 'https://www.eporner.com/', 'https://www.eporner.com/favicon.ico', Icons.theaters_rounded),
  ];

  late final WebViewController _controller;
  int _selectedProvider = 0;
  bool _loading = true;
  bool _canGoBack = false;
  String? _errorMessage;
  bool _configured = false;
  bool _controlsVisible = true;
  Timer? _hideControlsTimer;
  int _providerLoadRequest = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    unawaited(_configureWebView());
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
  }

  Future<void> _configureWebView() async {
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.setBackgroundColor(const Color(0xFF080A10));
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            _hideControlsTimer?.cancel();
            setState(() {
              _loading = true;
              _errorMessage = null;
              _controlsVisible = true;
            });
          },
          onPageFinished: (_) async {
            final canGoBack = await _controller.canGoBack();
            if (!mounted) return;
            setState(() {
              _loading = false;
              _canGoBack = canGoBack;
            });
            _showControls();
          },
          onWebResourceError: (error) {
            if (!mounted || (error.isForMainFrame == false)) return;
            setState(() {
              _loading = false;
              _errorMessage =
                  'No se pudo cargar este sitio. Puede estar bloqueando WebView o no estar disponible.';
            });
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null || uri.scheme != 'https') {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
      _configured = true;
      await _loadProvider(0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'No se pudo iniciar el navegador integrado.';
      });
    }
  }

  Future<void> _loadProvider(int index) async {
    if (index < 0 || index >= _providers.length) return;
    final request = ++_providerLoadRequest;
    _hideControlsTimer?.cancel();
    setState(() {
      _selectedProvider = index;
      _loading = true;
      _errorMessage = null;
      _canGoBack = false;
      _controlsVisible = true;
    });
    // Each provider starts with a clean local WebView session. This avoids
    // carrying cookies or site storage from one provider into another.
    await _clearWebData();
    if (!mounted || request != _providerLoadRequest) return;
    try {
      await _controller.loadRequest(Uri.parse(_providers[index].url));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'No se pudo abrir este proveedor.';
      });
    }
  }

  Future<bool> _goBackOrLock() async {
    if (_configured && await _controller.canGoBack()) {
      await _controller.goBack();
      if (mounted) {
        final canGoBack = await _controller.canGoBack();
        if (mounted) setState(() => _canGoBack = canGoBack);
      }
      return true;
    }
    await _clearWebData();
    widget.onLock();
    return false;
  }

  Future<void> _clearWebData() async {
    // Run each cleanup independently so one unsupported WebView operation
    // does not prevent the remaining privacy cleanup steps.
    try {
      await _controller.clearCache();
    } catch (_) {
      // Best effort; WebView implementations differ by platform.
    }
    try {
      await _controller.clearLocalStorage();
    } catch (_) {
      // Best effort; WebView implementations differ by platform.
    }
    try {
      await WebViewCookieManager().clearCookies();
    } catch (_) {
      // Best effort; WebView implementations differ by platform.
    }
  }

  void _showControls() {
    if (!mounted) return;
    _hideControlsTimer?.cancel();
    setState(() => _controlsVisible = true);
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_loading && _errorMessage == null) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideControlsTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  Future<void> _showPrivacyNote() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151927),
        title: const Text('Privacidad de la sección +18'),
        content: const Text(
          'MILTVPLUS no guarda un historial propio de páginas visitadas. Al bloquear o salir de esta sección, la app intenta borrar caché, almacenamiento local y cookies del navegador integrado. Los proveedores externos pueden registrar conexiones o actividad en sus propios servidores; la app no puede impedirlo.',
          style: TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    unawaited(_clearWebData());
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_goBackOrLock());
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF080A10),
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (_configured)
                WebViewWidget(controller: _controller)
              else
                const SizedBox.expand(),
              if (_loading)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    ),
                  ),
                ),
              if (_errorMessage != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0xEE080A10),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.public_off_rounded,
                                size: 44, color: AppTheme.accent),
                            const SizedBox(height: 14),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(height: 1.45),
                            ),
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed: () => unawaited(_loadProvider(_selectedProvider)),
                              child: const Text('REINTENTAR'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                top: 12,
                right: _controlsVisible ? 8 : -92,
                bottom: 12,
                child: SafeArea(
                  child: Material(
                    color: const Color(0xD910131E),
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      width: 64,
                      child: Column(
                        children: [
                          IconButton(
                            tooltip: 'Volver o bloquear sección +18',
                            onPressed: () => unawaited(_goBackOrLock()),
                            icon: Icon(
                              _canGoBack ? Icons.arrow_back_rounded : Icons.lock_rounded,
                              color: AppTheme.accent,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Privacidad',
                            onPressed: _showPrivacyNote,
                            icon: const Icon(Icons.shield_outlined, color: AppTheme.muted),
                          ),
                          const Divider(height: 8, color: Color(0x30FFFFFF)),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              children: [
                                for (var index = 0; index < _providers.length; index++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: IconButton(
                                      tooltip: _providers[index].label,
                                      onPressed: () => unawaited(_loadProvider(index)),
                                      style: IconButton.styleFrom(
                                        backgroundColor: index == _selectedProvider
                                            ? AppTheme.accent.withValues(alpha: .20)
                                            : Colors.transparent,
                                        foregroundColor: index == _selectedProvider
                                            ? AppTheme.accent
                                            : Colors.white,
                                      ),
                                      icon: SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: Image.network(
                                          _providers[index].logoUrl,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.medium,
                                          errorBuilder: (_, __, ___) => Icon(_providers[index].icon, size: 25),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Divider(height: 8, color: Color(0x30FFFFFF)),
                          IconButton(
                            tooltip: 'Limpiar datos y salir',
                            onPressed: () async {
                              await _clearWebData();
                              widget.onLock();
                            },
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                          ),
                          IconButton(
                            tooltip: 'Contraer menú',
                            onPressed: _toggleControls,
                            icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (!_controlsVisible)
                Positioned(
                  top: 8,
                  right: 8,
                  child: SafeArea(
                    child: IconButton.filledTonal(
                      tooltip: 'Mostrar menú +18',
                      onPressed: _toggleControls,
                      icon: const Icon(Icons.menu_rounded),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _AdultProvider {
  const _AdultProvider(this.label, this.url, this.logoUrl, this.icon);

  final String label;
  final String url;
  final String logoUrl;
  final IconData icon;
}
