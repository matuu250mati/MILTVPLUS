import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/accessibility_settings.dart';
import '../../core/supabase_config.dart';
import '../auth/auth_screen.dart';
import '../onboarding/miltvplus_guide.dart';
import '../../services/ota_update_service.dart';
import '../../services/m3u_playlist_service.dart';
import '../../services/channel_storage_service.dart';
import '../../models/tv_channel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _profileKey = 'miltv_profile_name_v1';
  static const _providerUrlKey = 'miltv_provider_url_v1';

  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _checkingUpdates = false;
  double _textScale = 1.0;
  String? _providerStatus;
  bool _importingPlaylist = false;
  final _playlistUrlController = TextEditingController();
  final _playlistService = M3uPlaylistService();
  final _channelStorage = ChannelStorageService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _nameController.text = preferences.getString(_profileKey) ?? 'Usuario MILTVPLUS';
      _urlController.text = preferences.getString(_providerUrlKey) ?? '';
      _textScale = preferences.getDouble('miltvplus_accessibility_text_scale_v1') ?? 1.0;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    final name = _nameController.text.trim();
    final rawUrl = _urlController.text.trim();
    if (name.isEmpty) {
      _showMessage('Ingresá un nombre de perfil.');
      return;
    }
    if (rawUrl.isNotEmpty) {
      final uri = Uri.tryParse(rawUrl);
      if (uri == null ||
          !uri.hasAuthority ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
        _showMessage('La URL debe comenzar con https:// o http://.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_profileKey, name);
      if (rawUrl.isEmpty) {
        await preferences.remove(_providerUrlKey);
      } else {
        await preferences.setString(_providerUrlKey, rawUrl);
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _providerStatus = rawUrl.isEmpty
            ? 'No hay proveedor configurado.'
            : 'Dirección guardada en este dispositivo. La vinculación de cuenta requiere un servidor compatible.';
      });
      _showMessage('Configuración guardada.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('No se pudo guardar la configuración.');
    }
  }

  Future<void> _setTextScale(double value) async {
    setState(() => _textScale = value);
    try {
      await AppAccessibilitySettings.setTextScale(value);
      if (mounted) _showMessage('Tamaño de texto actualizado.');
    } catch (_) {
      if (mounted) _showMessage('No se pudo guardar el tamaño de texto.');
    }
  }

  Future<void> _checkForUpdates() async {
    if (_checkingUpdates) return;
    setState(() => _checkingUpdates = true);
    try {
      final result = await OtaUpdateService().checkAndInstall();
      if (!mounted) return;
      _showMessage(result.message);
    } catch (_) {
      if (mounted) {
        _showMessage('No se pudo comprobar la actualización. Revisá la conexión e intentá otra vez.');
      }
    } finally {
      if (mounted) setState(() => _checkingUpdates = false);
    }
  }

  static const _playlistSources = <({String title, String url})>[
    (title: 'Deportes internacionales', url: 'https://iptv-org.github.io/iptv/categories/sports.m3u'),
    (title: 'Canales de Argentina', url: 'https://iptv-org.github.io/iptv/countries/ar.m3u'),
    (title: 'Canales en español', url: 'https://iptv-org.github.io/iptv/languages/spa.m3u'),
    (title: 'Catálogo global', url: 'https://iptv-org.github.io/iptv/index.m3u'),
    (title: 'Lista gratuita curada', url: 'https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8'),
  ];

  Future<void> _importPlaylist(String url, String title) async {
    final normalizedUrl = url.trim();
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      _showMessage('Ingresá una URL HTTPS válida de una lista propia o autorizada.');
      return;
    }
    if (_importingPlaylist) return;
    setState(() => _importingPlaylist = true);
    try {
      final imported = await _playlistService.importFromUrl(normalizedUrl);
      final merged = <String, TvChannel>{};
      for (final channel in await _channelStorage.load()) {
        merged.putIfAbsent(_streamIdentity(channel.streamUrl), () => channel);
      }
      for (final channel in imported) {
        merged.putIfAbsent(_streamIdentity(channel.streamUrl), () => channel);
      }
      await _channelStorage.save(merged.values.toList(growable: false));
      _showMessage('$title: ${imported.length} señales leídas; ${merged.length} señales únicas guardadas en este dispositivo.');
    } catch (_) {
      _showMessage('No se pudo cargar $title. Verificá que la lista sea pública, HTTPS y compatible con M3U.');
    } finally {
      if (mounted) setState(() => _importingPlaylist = false);
    }
  }

  String _streamIdentity(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty) return value.trim();
    return uri.replace(scheme: uri.scheme.toLowerCase(), host: uri.host.toLowerCase(),
        path: uri.normalizePath().path, fragment: '').toString();
  }

  Future<void> _importCustomPlaylist() async {
    final url = _playlistUrlController.text.trim();
    if (url.isEmpty) {
      _showMessage('Pegá primero la URL HTTPS de tu lista M3U.');
      return;
    }
    await _importPlaylist(url, 'Lista propia');
  }

  void _clearImageCache() {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
    _showMessage('Caché de imágenes en memoria limpiada.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAuth() async {
    if (!isSupabaseConfigured) {
      _showMessage(supabaseConfigurationError ?? 'Supabase no está configurado.');
      return;
    }
    final authenticated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (authContext) => AuthScreen(
          onAuthenticated: () => Navigator.of(authContext).pop(true),
        ),
      ),
    );
    if (mounted && authenticated == true) setState(() {});
  }


  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _playlistUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final user = isSupabaseConfigured ? Supabase.instance.client.auth.currentUser : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        const Text('PERFIL Y CONFIGURACIÓN',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('Administrá tu perfil y las conexiones de este dispositivo.',
            style: TextStyle(color: AppTheme.muted)),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_circle_outlined, color: AppTheme.accent, size: 26),
                  SizedBox(width: 10),
                  Text('Perfil local', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre de perfil',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _saveSettings,
                  child: Text(_saving ? 'GUARDANDO…' : 'GUARDAR PERFIL'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.link_rounded, color: AppTheme.accent, size: 25),
                  SizedBox(width: 10),
                  Text('Proveedor de contenido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Guardá la dirección de tu servidor autorizado. La autenticación y sincronización necesitan una API compatible.',
                style: TextStyle(color: AppTheme.muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL base del servidor',
                  hintText: 'https://tu-servidor.example',
                  prefixIcon: Icon(Icons.dns_outlined),
                ),
              ),
              if (_providerStatus != null) ...[
                const SizedBox(height: 12),
                Text(_providerStatus!, style: const TextStyle(color: AppTheme.muted, height: 1.4)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _saveSettings,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('GUARDAR CONEXIÓN'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.playlist_add_check_circle_rounded, color: Color(0xFF57D9A3), size: 27),
                SizedBox(width: 10),
                Expanded(child: Text('Cargar listas de canales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 8),
              const Text(
                'Administrá las listas desde acá para que TV en vivo y Deportes tengan todo el espacio disponible. Solo se importan señales públicas o que estés autorizado a usar.',
                style: TextStyle(color: AppTheme.muted, height: 1.5),
              ),
              const SizedBox(height: 12),
              for (final source in _playlistSources)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _importingPlaylist ? null : () => _importPlaylist(source.url, source.title),
                      icon: const Icon(Icons.download_rounded),
                      label: Text(source.title),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _playlistUrlController,
                keyboardType: TextInputType.url,
                minLines: 1,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Mi lista M3U/M3U8 (HTTPS)',
                  hintText: 'https://servidor/mi-lista.m3u',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _importingPlaylist ? null : _importCustomPlaylist,
                  icon: _importingPlaylist
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.playlist_add_rounded),
                  label: Text(_importingPlaylist ? 'CARGANDO LISTA…' : 'IMPORTAR LISTA PROPIA'),
                ),
              ),
              const SizedBox(height: 14),
              const Divider(color: Color(0x22FFFFFF)),
              const Row(children: [
                Icon(Icons.satellite_alt_rounded, color: Color(0xFF65B7FF), size: 25),
                SizedBox(width: 10),
                Expanded(child: Text('Codificador o sintonizador', style: TextStyle(fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 6),
              const Text(
                'MILTVPLUS puede importar una URL de red o una lista expuesta por un equipo compatible. Un decodificador HDMI común no se puede detectar ni leer directamente desde una app Android: hace falta un sintonizador compatible con Android o un equipo que publique su salida en la red. No compartas claves de canales cifrados ni señales sin autorización.',
                style: TextStyle(color: AppTheme.muted, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: AppTheme.accent, size: 25),
                  SizedBox(width: 10),
                  Text('Cuenta MILTVPLUS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isSupabaseConfigured
                    ? (user?.email ?? 'No hay una sesión iniciada.')
                    : (supabaseConfigurationError ?? 'Cuenta no disponible: falta configurar Supabase.'),
                style: const TextStyle(color: AppTheme.muted),
              ),
              const SizedBox(height: 14),
              if (user == null) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isSupabaseConfigured ? _openAuth : null,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('INICIAR SESIÓN / CREAR CUENTA'),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await Supabase.instance.client.auth.signOut();
                        if (mounted) {
                          setState(() {});
                          _showMessage('Sesión cerrada.');
                        }
                      } catch (_) {
                        if (mounted) _showMessage('No se pudo cerrar la sesión. Intentá de nuevo.');
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('CERRAR SESIÓN'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.cleaning_services_outlined, color: AppTheme.accent, size: 25),
                  SizedBox(width: 10),
                  Text('Almacenamiento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Limpiá imágenes guardadas en memoria. Esta acción no borra tus canales, perfil ni PIN de seguridad.',
                style: TextStyle(color: AppTheme.muted, height: 1.5),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _clearImageCache,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('LIMPIAR CACHÉ DE IMÁGENES'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Información de MILTVPLUS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 12),
            _InfoRow(icon: Icons.security_rounded, color: Color(0xFF5BE58B), title: 'Seguridad', description: 'PIN de +18 protegido en almacenamiento seguro; las cuentas y los catálogos remotos dependen de Supabase y sus permisos.'),
            _InfoRow(icon: Icons.live_tv_rounded, color: Color(0xFF58C7FF), title: 'TV en vivo', description: 'Listas públicas, listas M3U autorizadas, búsqueda, filtros y reproducción a pantalla completa.'),
            _InfoRow(icon: Icons.sports_soccer_rounded, color: Color(0xFFFFB74D), title: 'Deportes', description: 'Catálogos internacionales y señales argentinas gratuitas disponibles en las fuentes importadas.'),
            _InfoRow(icon: Icons.lock_rounded, color: Color(0xFFB79CFF), title: 'Zona +18', description: 'Acceso con cuenta, confirmación de mayoría de edad y PIN local. No reemplaza controles parentales del dispositivo.'),
            _InfoRow(icon: Icons.system_update_alt_rounded, color: Color(0xFFFF7CA8), title: 'Actualizaciones', description: 'La actualización automática requiere que exista una versión publicada en GitHub Releases.'),
            _InfoRow(icon: Icons.satellite_alt_rounded, color: Color(0xFF65B7FF), title: 'Equipos externos', description: 'Solo se integran sintonizadores compatibles o dispositivos que publiquen una señal autorizada por red; no se captura HDMI genérico.'),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.accessibility_new_rounded, color: AppTheme.accent, size: 25),
                  SizedBox(width: 10),
                  Text('Accesibilidad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Elegí un tamaño de texto más cómodo. El cambio se aplica a toda la aplicación y se conserva al volver a abrirla.',
                style: TextStyle(color: AppTheme.muted, height: 1.5),
              ),
              const SizedBox(height: 8),
              RadioListTile<double>(
                value: 1.0,
                groupValue: _textScale,
                activeColor: AppTheme.accent,
                contentPadding: EdgeInsets.zero,
                title: const Text('Normal'),
                subtitle: const Text('Tamaño actual del diseño'),
                onChanged: (value) {
                  if (value != null) _setTextScale(value);
                },
              ),
              RadioListTile<double>(
                value: 1.15,
                groupValue: _textScale,
                activeColor: AppTheme.accent,
                contentPadding: EdgeInsets.zero,
                title: const Text('Grande'),
                subtitle: const Text('Texto un poco más grande'),
                onChanged: (value) {
                  if (value != null) _setTextScale(value);
                },
              ),
              RadioListTile<double>(
                value: 1.3,
                groupValue: _textScale,
                activeColor: AppTheme.accent,
                contentPadding: EdgeInsets.zero,
                title: const Text('Muy grande'),
                subtitle: const Text('Para una lectura más cómoda'),
                onChanged: (value) {
                  if (value != null) _setTextScale(value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: AppTheme.accent, size: 25),
                  SizedBox(width: 10),
                  Text('Guía de uso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Volvé a consultar las instrucciones de TV en Vivo, Deportes, configuración, actualizaciones y seguridad.',
                style: TextStyle(color: AppTheme.muted, height: 1.5),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await showMiltvPlusGuide(
                      context,
                      profileName: _nameController.text.trim(),
                    );
                  },
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: const Text('ABRIR GUÍA PASO A PASO'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.system_update_alt_rounded, color: AppTheme.accent, size: 25),
                  SizedBox(width: 10),
                  Text('Actualización de MILTVPLUS',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Buscá una versión publicada en GitHub. El APK se verifica antes de abrir el instalador de Android.',
                style: TextStyle(color: AppTheme.muted, height: 1.5),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _checkingUpdates ? null : _checkForUpdates,
                  icon: _checkingUpdates
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_alt_rounded),
                  label: Text(_checkingUpdates ? 'BUSCANDO…' : 'Buscar actualizaciones'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.color, required this.title, required this.description});
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: .13),
          boxShadow: [BoxShadow(color: color.withValues(alpha: .20), blurRadius: 12, spreadRadius: 1)],
        ),
        child: Icon(icon, color: color, size: 21),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(description, style: const TextStyle(color: AppTheme.muted, height: 1.4, fontSize: 12)),
      ])),
    ]),
  );
}
