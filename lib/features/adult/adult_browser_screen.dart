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
    _AdultProvider('Pornhub', 'https://www.pornhub.com/'),
    _AdultProvider('XVideos', 'https://www.xvideos.com/'),
    _AdultProvider('xHamster', 'https://xhamster.com/'),
    _AdultProvider('YouPorn', 'https://www.youporn.com/'),
    _AdultProvider('RedTube', 'https://www.redtube.com/'),
    _AdultProvider('XNXX', 'https://www.xnxx.com/'),
    _AdultProvider('SpankBang', 'https://spankbang.com/'),
    _AdultProvider('Tube8', 'https://www.tube8.com/'),
    _AdultProvider('Eporner', 'https://www.eporner.com/'),
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
            setState(() {
              _loading = true;
              _errorMessage = null;
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
                    color: Color(0xEE080A10),
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
                top: _controlsVisible ? 0 : -180,
                left: 0,
                right: 0,
                child: Material(
                  color: const Color(0xF510131E),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 48,
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Atrás',
                                onPressed: () => unawaited(_goBackOrLock()),
                                icon: Icon(
                                  _canGoBack ? Icons.arrow_back_rounded : Icons.lock_rounded,
                                  color: AppTheme.accent,
                                ),
                              ),
                              const Expanded(
                                child: Text(
                                  '+18 · NAVEGACIÓN PRIVADA LOCAL',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .6,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Información de privacidad',
                                onPressed: _showPrivacyNote,
                                icon: const Icon(Icons.shield_outlined, color: AppTheme.muted),
                              ),
                              IconButton(
                                tooltip: 'Limpiar datos y salir',
                                onPressed: () async {
                                  await _clearWebData();
                                  widget.onLock();
                                },
                                icon: const Icon(Icons.close_rounded, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 48,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                            scrollDirection: Axis.horizontal,
                            itemCount: _providers.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final selected = index == _selectedProvider;
                              return ChoiceChip(
                                label: Text(_providers[index].label),
                                selected: selected,
                                autofocus: selected,
                                showCheckmark: false,
                                onSelected: (_) => unawaited(_loadProvider(index)),
                                selectedColor: AppTheme.accent,
                                backgroundColor: const Color(0xFF20243C),
                                labelStyle: TextStyle(
                                  color: selected ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                                side: BorderSide(
                                  color: selected
                                      ? AppTheme.accent
                                      : Colors.white.withValues(alpha: .12),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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
                      onPressed: _showControls,
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
  const _AdultProvider(this.label, this.url);

  final String label;
  final String url;
}
