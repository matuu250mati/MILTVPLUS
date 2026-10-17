import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';
import '../../core/theme/app_theme.dart';

/// Temporary startup strip. It reports only states the client can actually verify.
class StartupStatusBanner extends StatefulWidget {
  const StartupStatusBanner({super.key});

  static bool _shownThisProcess = false;

  /// Claims the single startup display for this app process.
  static bool claimForSession() {
    if (_shownThisProcess) return false;
    _shownThisProcess = true;
    return true;
  }

  @override
  State<StartupStatusBanner> createState() => _StartupStatusBannerState();
}

class _StartupStatusBannerState extends State<StartupStatusBanner> {
  Timer? _refreshTimer;
  bool _checking = false;
  bool? _internetAvailable;
  String _profileName = 'Usuario MILTVPLUS';

  User? get _user {
    if (!isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
    unawaited(_checkInternet());
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_checkInternet());
    });
  }

  Future<void> _loadProfile() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString('miltv_profile_name_v1')?.trim();
      final user = _user;
      final metadataName = user?.userMetadata?['name']?.toString().trim();
      final fallback = user?.email?.split('@').first;
      final name = (saved != null && saved.isNotEmpty && saved != 'Usuario MILTVPLUS')
          ? saved
          : (metadataName != null && metadataName.isNotEmpty)
              ? metadataName
              : (fallback != null && fallback.isNotEmpty)
                  ? fallback
                  : 'Usuario MILTVPLUS';
      if (mounted) setState(() => _profileName = name);
    } catch (_) {
      // The banner remains useful with a generic profile name.
    }
  }

  Future<void> _checkInternet() async {
    if (_checking || !mounted) return;
    _checking = true;
    bool available = false;
    try {
      final response = await Dio().get<dynamic>(
        'https://www.google.com/generate_204',
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status == 204,
        ),
      ).timeout(const Duration(seconds: 4));
      available = response.statusCode == 204;
    } catch (_) {
      available = false;
    } finally {
      _checking = false;
    }
    if (mounted && _internetAvailable != available) {
      setState(() => _internetAvailable = available);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final connected = user != null;
    final verified = user?.emailConfirmedAt != null;
    final internetLabel = _internetAvailable == null
        ? 'Comprobando internet…'
        : _internetAvailable!
            ? 'Internet disponible'
            : 'Sin conexión a internet';
    final internetColor = _internetAvailable == true
        ? const Color(0xFF39D98A)
        : _internetAvailable == false
            ? const Color(0xFFFF7373)
            : const Color(0xFFFFC857);

    return Semantics(
      liveRegion: true,
      label: 'Estado de MILTVPLUS. Sesión ${connected ? 'activa' : 'no verificada'}. $internetLabel.',
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xF20B1724),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.accent.withValues(alpha: .42)),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 14, offset: Offset(0, 5)),
            ],
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            spacing: 14,
            children: [
              const Text(
                'LÍNEA / SESIÓN',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8, color: AppTheme.accent),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 9, color: connected ? const Color(0xFF39D98A) : const Color(0xFFFF7373)),
                  const SizedBox(width: 7),
                  Text(
                    _profileName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    verified ? Icons.verified_rounded : Icons.info_outline_rounded,
                    size: 14,
                    color: verified ? const Color(0xFF39D98A) : const Color(0xFFFFC857),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    verified ? 'Cuenta verificada' : 'Cuenta sin verificar',
                    style: TextStyle(fontSize: 11, color: verified ? const Color(0xFF39D98A) : const Color(0xFFFFC857)),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_rounded, size: 16, color: internetColor),
                  const SizedBox(width: 6),
                  Text(internetLabel, style: TextStyle(fontSize: 11, color: internetColor, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
