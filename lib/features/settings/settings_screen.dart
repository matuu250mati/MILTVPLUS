import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

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
  String? _providerStatus;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _nameController.text = preferences.getString(_profileKey) ?? 'Usuario MILTV';
      _urlController.text = preferences.getString(_providerUrlKey) ?? '';
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

  void _clearImageCache() {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
    _showMessage('Caché de imágenes en memoria limpiada.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

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
              const Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: AppTheme.accent, size: 25),
                  SizedBox(width: 10),
                  Text('Cuenta MILTV PLUS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                Supabase.instance.client.auth.currentUser?.email ?? 'Sesión no disponible',
                style: const TextStyle(color: AppTheme.muted),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await Supabase.instance.client.auth.signOut();
                    } catch (_) {
                      if (mounted) _showMessage('No se pudo cerrar la sesión. Intentá de nuevo.');
                    }
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('CERRAR SESIÓN'),
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
      ],
    );
  }
}
