import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tv_channel.dart';
import '../../services/channel_storage_service.dart';

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

  final _storage = ChannelStorageService();
  String _brand = _brands.first;
  String _model = _models.first;
  bool _scanning = false;
  bool _finished = false;
  bool _saving = false;
  double _progress = 0;
  int _currentTp = 0;
  List<TvChannel> _foundChannels = const [];
  String? _error;
  String? _scanMessage;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _finished = false;
      _progress = 0;
      _currentTp = 0;
      _error = null;
      _scanMessage = null;
      _foundChannels = const [];
    });

    // Do not report a device as connected or invent signal readings. Generic
    // decoder discovery and channel extraction require a supported device API.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _finished = false;
      _scanMessage =
          'No hay un adaptador de detección compatible configurado. La selección de marca/modelo por sí sola no permite descubrir el equipo ni leer sus canales. Para habilitarlo hace falta integrar el protocolo/API del fabricante o un servicio estándar que el decodificador exponga en la red.';
    });
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
          'connection_type': 'detección de red',
          'source_host': null,
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
              const Text('Buscá un decodificador compatible en la red local. La conexión real y la lectura de canales solo se habilitan cuando existe un protocolo/API compatible con ese fabricante y modelo.', style: TextStyle(color: AppTheme.muted, height: 1.45)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _brand,
                decoration: const InputDecoration(labelText: 'Marca del equipo'),
                items: _brands.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: _scanning ? null : (v) => setState(() => _brand = v ?? _brands.first),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _model,
                decoration: const InputDecoration(labelText: 'Modelo / estándar'),
                items: _models.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: _scanning ? null : (v) => setState(() => _model = v ?? _models.first),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.background.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppTheme.muted),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No se solicitan URLs ni listas manuales. La detección directa del decodificador todavía necesita un adaptador de comunicación específico.',
                        style: TextStyle(color: AppTheme.muted, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
              ],
              if (_scanMessage != null) ...[
                const SizedBox(height: 12),
                Text(_scanMessage!, style: const TextStyle(color: Colors.orangeAccent, height: 1.4)),
              ],
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _scanning ? null : _startScan,
                icon: _scanning
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.radar_rounded),
                label: Text(_scanning ? 'BUSCANDO DISPOSITIVOS…' : 'BUSCAR DECODIFICADOR'),
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
                const Text('La fuerza y calidad reales solo pueden leerse desde el sintonizador mediante una API compatible.', style: TextStyle(color: AppTheme.muted, height: 1.4)),
                const SizedBox(height: 14),
                LinearProgressIndicator(value: _progress, minHeight: 8),
                const SizedBox(height: 8),
                Text(_finished ? 'Sincronización completada' : 'Comprobando compatibilidad…', style: const TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _CountTile(label: 'TV', count: tvCount)),
                  const SizedBox(width: 8),
                  Expanded(child: _CountTile(label: 'Radios', count: radioCount)),
                  const SizedBox(width: 8),
                  Expanded(child: _CountTile(label: 'Total', count: _foundChannels.length)),
                ]),


              ]),
            ),
          ],
        ],
      ),
    );
  }
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
