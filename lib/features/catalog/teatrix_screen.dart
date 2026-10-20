import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';

/// Opens Teatrix's official platform. This does not copy or redistribute its
/// catalogue; playback and access remain subject to Teatrix's own terms.
class TeatrixScreen extends StatefulWidget {
  const TeatrixScreen({super.key});

  @override
  State<TeatrixScreen> createState() => _TeatrixScreenState();
}

class _TeatrixScreenState extends State<TeatrixScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() {
              _loading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _loading = false;
                _error = 'No se pudo abrir Teatrix. Revisá la conexión e intentá nuevamente.';
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.teatrix.com/'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('TEATRIX · TEATRO'),
        backgroundColor: AppTheme.background,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Recargar Teatrix',
            onPressed: () {
              setState(() {
                _error = null;
                _loading = true;
              });
              _controller.reload();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(
                color: AppTheme.accent,
                backgroundColor: Colors.transparent,
              ),
            ),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 42, color: AppTheme.muted),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _loading = true;
                        });
                        _controller.loadRequest(Uri.parse('https://www.teatrix.com/'));
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
