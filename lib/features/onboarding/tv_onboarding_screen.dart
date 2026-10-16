import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../shell/app_shell.dart';

/// First authenticated launch flow. Hardware details are read for diagnostics;
/// the installation ID is generated locally and is not a hardware fingerprint.
class TvOnboardingScreen extends StatefulWidget {
  const TvOnboardingScreen({super.key});

  @override
  State<TvOnboardingScreen> createState() => _TvOnboardingScreenState();
}

class _TvOnboardingScreenState extends State<TvOnboardingScreen> {
  int _step = 0; // 0 syncing, 1 complete, 2 terms
  bool _busy = true;
  bool _accepted = false;
  String? _error;
  String _deviceLabel = 'Dispositivo compatible';
  String _installationId = '';
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _synchronize();
  }

  Future<void> _synchronize() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      var installationId = preferences.getString('miltv_installation_id_v1');
      if (installationId == null || installationId.isEmpty) {
        final random = Random.secure();
        installationId = List<int>.generate(
          16,
          (_) => random.nextInt(256),
        ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
        await preferences.setString('miltv_installation_id_v1', installationId);
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = DeviceInfoPlugin();
      var label = defaultTargetPlatform.name;
      if (!kIsWeb) {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final info = await deviceInfo.androidInfo;
            label = 'Android · ${info.manufacturer} ${info.model} · Android ${info.version.release}';
          case TargetPlatform.iOS:
            final info = await deviceInfo.iosInfo;
            label = 'iOS · ${info.model} · ${info.systemVersion}';
          case TargetPlatform.macOS:
            final info = await deviceInfo.macOsInfo;
            label = 'macOS · ${info.model} · ${info.osRelease}';
          case TargetPlatform.windows:
            final info = await deviceInfo.windowsInfo;
            label = 'Windows · ${info.productName}';
          case TargetPlatform.linux:
            final info = await deviceInfo.linuxInfo;
            label = 'Linux · ${info.prettyName}';
          case TargetPlatform.fuchsia:
            label = 'Fuchsia';
        }
      }

      if (!mounted) return;
      setState(() {
        _installationId = installationId!;
        _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
        _deviceLabel = label;
        _busy = false;
        _step = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No pudimos completar la comprobación del dispositivo. Revisá los permisos y volvé a intentar.';
      });
    }
  }

  Future<void> _acceptTerms() async {
    if (!_accepted || _busy) return;
    setState(() => _busy = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('miltv_terms_accepted_v1', true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AppShell()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo guardar tu aceptación. Intentá nuevamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.3,
            colors: [Color(0xFF14283A), AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(wide ? 36 : 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Card(
                  color: AppTheme.panel.withValues(alpha: .97),
                  child: Padding(
                    padding: EdgeInsets.all(wide ? 32 : 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.ondemand_video_rounded,
                            color: AppTheme.accent, size: 58),
                        const SizedBox(height: 12),
                        const Text(
                          'MILTVPLUS',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _step == 0
                              ? 'Sincronización del dispositivo'
                              : _step == 1
                                  ? 'Sincronización completada'
                                  : 'Términos y condiciones de uso',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.accent, fontSize: 19, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 24),
                        if (_step == 0) ...[
                          if (_busy) ...[
                            const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
                            const SizedBox(height: 18),
                            const Text(
                              'Comprobando la información disponible del sistema y preparando la navegación por control remoto…',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.muted, height: 1.5),
                            ),
                          ] else ...[
                            Text(_deviceLabel, textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            Text('Versión: $_appVersion', textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            const Text(
                              'La navegación usa los eventos de teclado estándar de Flutter (flechas y OK/Enter). La disponibilidad exacta de teclas depende del dispositivo y debe comprobarse en el televisor.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.muted, height: 1.5),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              autofocus: true,
                              onPressed: _synchronize,
                              child: const Text('VOLVER A INTENTAR'),
                            ),
                            FilledButton(
                              onPressed: () => setState(() => _step = 1),
                              child: const Text('CONTINUAR'),
                            ),
                          ],
                        ] else if (_step == 1) ...[
                          const Icon(Icons.check_circle_outline_rounded, color: AppTheme.accent, size: 56),
                          const SizedBox(height: 16),
                          Text(_deviceLabel, textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text('Versión de la aplicación: $_appVersion', textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          const Text(
                            'Se guardó un identificador local de esta instalación. No es un identificador de hardware ni garantiza compatibilidad con todos los mandos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.muted, height: 1.5),
                          ),
                          const SizedBox(height: 8),
                          Text('ID de instalación: $_installationId', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                          const SizedBox(height: 22),
                          FilledButton(
                            autofocus: true,
                            onPressed: () => setState(() => _step = 2),
                            child: const Text('CONTINUAR'),
                          ),
                        ] else ...[
                          const Text(
                            'Antes de continuar, tené en cuenta:',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '• Usá MILTVPLUS respetando las leyes aplicables y los derechos de distribución del contenido.\n\n'
                            '• No compartas tu contraseña ni los códigos de acceso.\n\n'
                            '• La disponibilidad y reproducción del contenido dependen de la fuente, la conexión y la compatibilidad del dispositivo.\n\n'
                            '• La comprobación inicial no garantiza que todos los mandos, televisores o formatos de vídeo sean compatibles.',
                            style: TextStyle(color: AppTheme.muted, height: 1.5),
                          ),
                          const SizedBox(height: 16),
                          Focus(
                            child: CheckboxListTile(
                              value: _accepted,
                              onChanged: _busy ? null : (value) => setState(() => _accepted = value ?? false),
                              activeColor: AppTheme.accent,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text('Leí y acepto estos términos de uso.'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                          ],
                          const SizedBox(height: 14),
                          FilledButton(
                            autofocus: true,
                            onPressed: _accepted && !_busy ? _acceptTerms : null,
                            child: _busy
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('ACEPTAR Y CONTINUAR'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
