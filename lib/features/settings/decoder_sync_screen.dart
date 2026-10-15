import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tv_channel.dart';
import '../../services/channel_storage_service.dart';
import '../../services/m3u_playlist_service.dart';

class DecoderSyncScreen extends StatefulWidget {
  const DecoderSyncScreen({super.key});

  @override
  State<DecoderSyncScreen> createState() => _DecoderSyncScreenState();
}

class _DecoderSyncScreenState extends State<DecoderSyncScreen> {
  static const _brands = <String>[
    'Satelital genérico', 'Azamerica', 'Tocomsat', 'Freesky', 'GTMedia',
    'Otro equipo compatible',
  ];
  static const _models = <String>[
    'Modelo no especificado', 'S2 / DVB-S2', 'C / DVB-C', 'IPTV / HTTP',
  ];

  final _urlController = TextEditingController();
  final _storage = ChannelStorageService();
  final _playlistService = M3uPlaylistService();
  String _brand = _brands.first;
  String _model = _models.first;
  String _connection = 'Lista M3U/M3U8 HTTPS';
  bool _scanning = false;
  bool _finished = false;
  bool _saving = false;
  double _progress = 0;
  int _currentTp = 0;
  List<TvChannel> _foundChannels = const [];
  String? _error;
  final List<String> _discoveredNames = [];

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    final raw = _urlController.text.trim();
    final uri = Uri.tryParse(raw);
    if (_connection == 'Lista M3U/M3U8 HTTPS' &&
        (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty)) {
      setState(() => _error = 'Ingresá una URL HTTPS válida de una lista M3U/M3U8 autorizada.');
      return;
    }
    if (_connection == 'IP local / HTTP del equipo' &&
        (uri == null || !uri.hasAuthority || (uri.scheme != 'http' && uri.scheme != 'https'))) {
      setState(() => _error = 'Ingresá la URL HTTP/HTTPS publicada por el equipo en tu red local.');
      return;
    }

    setState(() {
      _scanning = true;
      _finished = false;
      _progress = 0;
      _currentTp = 0;
      _error = null;
      _foundChannels = const [];
      _discoveredNames.clear();
    });

    try {
      // This is a UI progress simulation around an actual M3U import, not a DVB tuner scan.
      final imported = await _playlistService.importFromUrl(raw);
      if (imported.isEmpty) {
        throw Exception('La fuente no devolvió canales compatibles.');
      }
      final limit = imported.length < 24 ? imported.length : 24;
      for (var i = 0; i < limit; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 180));
        if (!mounted) return;
        setState(() {
          _currentTp = i + 1;
          _progress = (i + 1) / limit;
          _discoveredNames.add(imported[i].name);
        });
      }
      if (!mounted) return;
      setState(() {
        _foundChannels = imported;
        _scanning = false;
        _finished = true;
        _progress = 1;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _saveAndSync() async {
    if (_foundChannels.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final existing = await _storage.load();
      final merged = <String, TvChannel>{};
      for (final channel in existing) {
        merged.putIfAbsent(_identity(channel.streamUrl), () => channel);
      }
      for (final channel in _foundChannels) {
        merged.putIfAbsent(_identity(channel.streamUrl), () => channel);
      }
      await _storage.save(merged.values.toList(growable: false));

      var remoteMessage = 'Guardado localmente. Iniciá sesión para enviar una solicitud de sincronización.';
      if (isSupabaseConfigured && Supabase.instance.client.auth.currentUser != null) {
        final user = Supabase.instance.client.auth.currentUser!;
        await Supabase.instance.client.from('channel_sync_submissions').insert({
          'user_id': user.id,
          'device_brand': _brand,
          'device_model': _model,
          'connection_type': _connection,
          'source_host': Uri.tryParse(_urlController.text.trim())?.host ?? '',
          'channel_count': _foundChannels.length,
          'channels': _foundChannels.take(5000).map((channel) => {
            'name': channel.name,
            'streamUrl': channel.streamUrl,
            'groupTitle': channel.groupTitle,
            'country': channel.country,
            'language': channel.language,
            'category': channel.category,
            'logoUrl': channel.logoUrl,
            'tvgId': channel.tvgId,
          }).toList(growable: false),
          'status': 'pending_review',
        });
        remoteMessage = 'Guardado localmente y enviado a Supabase para revisión. No se publica automáticamente para otros usuarios.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(remoteMessage)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se guardó la lista localmente, pero no se pudo enviar la solicitud a Supabase. Revisá la sesión y las migraciones.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _identity(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty) return value.trim();
    return uri.replace(scheme: uri.scheme.toLowerCase(), host: uri.host.toLowerCase(), fragment: '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final radioCount = _foundChannels.where((c) =>
      (c.category ?? '').toLowerCase().contains('radio') ||
      (c.groupTitle ?? '').toLowerCase().contains('radio') ||
      c.name.toLowerCase().startsWith('radio ')).length;
    final tvCount = _foundChannels.length - radioCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronización de equipos'),
        backgroundColor: AppTheme.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.satellite_alt_rounded, color: AppTheme.accent, size: 28),
                SizedBox(width: 10),
                Expanded(child: Text('Equipo y fuente de canales', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 8),
              const Text('La aplicación no puede controlar un sintonizador DVB-S2/DVB-C real sin hardware y una API compatibles. Este módulo importa una lista autorizada y muestra un progreso visual simulado.', style: TextStyle(color: AppTheme.muted, height: 1.45)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _brand,
                decoration: const InputDecoration(labelText: 'Marca del equipo'),
                items: _brands.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: _scanning ? null : (v) => setState(() => _brand = v ?? _brands.first),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _model,
                decoration: const InputDecoration(labelText: 'Modelo / estándar'),
                items: _models.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: _scanning ? null : (v) => setState(() => _model = v ?? _models.first),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _connection,
                decoration: const InputDecoration(labelText: 'Tipo de conexión'),
                items: const [
                  DropdownMenuItem(value: 'Lista M3U/M3U8 HTTPS', child: Text('Lista M3U/M3U8 HTTPS')),
                  DropdownMenuItem(value: 'IP local / HTTP del equipo', child: Text('IP local / HTTP del equipo')),
                  DropdownMenuItem(value: 'Archivo exportado', child: Text('Archivo exportado (requiere URL importable)')),
                ],
                onChanged: _scanning ? null : (v) => setState(() => _connection = v ?? 'Lista M3U/M3U8 HTTPS'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _urlController,
                enabled: !_scanning,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL de la lista o endpoint',
                  hintText: 'https://servidor autorizado/lista.m3u',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
              ],
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _scanning ? null : _startScan,
                icon: _scanning
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.radar_rounded),
                label: Text(_scanning ? 'IMPORTANDO Y SIMULANDO ESCANEO…' : 'INICIAR BÚSQUEDA / SINCRONIZACIÓN'),
              )),
            ]),
          ),
          if (_scanning || _finished) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ESTADO DEL ESCANEO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _SignalMeter(label: 'Fuerza S', value: _scanning ? (_progress * 72).round() : 72)),
                  const SizedBox(width: 12),
                  Expanded(child: _SignalMeter(label: 'Calidad Q', value: _scanning ? (_progress * 64).round() : 64)),
                ]),
                const SizedBox(height: 14),
                LinearProgressIndicator(value: _progress, minHeight: 8),
                const SizedBox(height: 8),
                Text(_finished ? 'Importación completada · 100%' : 'Buscando TP $_currentTp/24…', style: const TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _CountTile(label: 'TV', count: tvCount)),
                  const SizedBox(width: 8),
                  Expanded(child: _CountTile(label: 'Radios', count: radioCount)),
                  const SizedBox(width: 8),
                  Expanded(child: _CountTile(label: 'Total', count: _foundChannels.length)),
                ]),
                if (_discoveredNames.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('Señales encontradas', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  for (final name in _discoveredNames.take(24))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.live_tv_rounded, color: AppTheme.accent),
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                if (_finished) ...[
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: FilledButton.icon(
                    onPressed: _saving ? null : _saveAndSync,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(_saving ? 'GUARDANDO…' : 'GUARDAR Y SOLICITAR SINCRONIZACIÓN'),
                  )),
                ],
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _SignalMeter extends StatelessWidget {
  const _SignalMeter({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('$label  $value%', style: const TextStyle(fontWeight: FontWeight.w700)),
    const SizedBox(height: 6),
    LinearProgressIndicator(value: value / 100, minHeight: 7),
  ]);
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: AppTheme.background.withValues(alpha: .65),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(children: [
      Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: AppTheme.muted)),
    ]),
  );
}
