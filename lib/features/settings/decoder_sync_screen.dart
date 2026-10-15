import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';
import '../../core/theme/app_theme.dart';

class DecoderSyncScreen extends StatefulWidget {
  const DecoderSyncScreen({super.key});

  @override
  State<DecoderSyncScreen> createState() => _DecoderSyncScreenState();
}

class _DecoderSyncScreenState extends State<DecoderSyncScreen> {
  static const _brands = <String>[
    'GTMedia',
    'Azamerica',
    'Satelital genérico',
    'Tocomsat',
    'Freesky',
    'Otro equipo compatible',
  ];

  static const _modelsByBrand = <String, List<String>>{
    'GTMedia': ['V8 UHD', 'V8 Nova'],
    'Azamerica': ['S1007', 'Champions'],
    'Satelital genérico': ['Modelo no especificado', 'S2 / DVB-S2', 'C / DVB-C'],
    'Tocomsat': ['Modelo no especificado'],
    'Freesky': ['Modelo no especificado'],
    'Otro equipo compatible': ['Modelo no especificado'],
  };

  static const _demoChannels = <String>[
    'Canal de demostración 01',
    'Canal de demostración 02',
    'Canal de demostración 03',
    'Radio de demostración 01',
    'Canal de demostración 04',
    'Canal de demostración 05',
  ];

  static const _localReportKey = 'miltv_decoder_sync_demo_report_v1';

  String _brand = _brands.first;
  String _model = 'V8 UHD';
  String? _statusMessage;
  Timer? _scanTimer;
  bool _scanning = false;
  bool _saving = false;
  bool _scanFinished = false;
  bool _reportSaved = false;
  int _progress = 0;
  int _signalStrength = 0;
  int _signalQuality = 0;
  final List<String> _visibleChannels = [];

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  void _startScan() {
    _scanTimer?.cancel();
    setState(() {
      _scanning = true;
      _scanFinished = false;
      _reportSaved = false;
      _progress = 0;
      _signalStrength = 0;
      _signalQuality = 0;
      _statusMessage = null;
      _visibleChannels.clear();
    });

    var step = 0;
    _scanTimer = Timer.periodic(const Duration(milliseconds: 450), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      step++;
      setState(() {
        _progress = (step * 100 ~/ 12).clamp(0, 100);
        _signalStrength = (step * 7 + 19) % 101;
        _signalQuality = (step * 11 + 13) % 101;
        final channelsToShow = (step ~/ 2).clamp(0, _demoChannels.length);
        while (_visibleChannels.length < channelsToShow) {
          _visibleChannels.add(_demoChannels[_visibleChannels.length]);
        }
      });
      if (step >= 12) {
        timer.cancel();
        setState(() {
          _scanning = false;
          _scanFinished = true;
          _statusMessage =
              'Demostración finalizada. No se detectó ni se leyó un decodificador físico; los nombres y niveles mostrados son datos de prueba.';
        });
      }
    });
  }

  Future<void> _saveReport() async {
    if (!_scanFinished || _saving) return;
    setState(() {
      _saving = true;
      _statusMessage = null;
    });

    final report = <String, dynamic>{
      'brand': _brand,
      'model': _model,
      'mode': 'demo_only',
      'detected_device': false,
      'real_channel_count': 0,
      'demo_channel_labels': List<String>.from(_visibleChannels),
      'saved_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localReportKey, jsonEncode(report));

      var remoteMessage =
          'Reporte guardado en este dispositivo. Para sincronizarlo con la cuenta, iniciá sesión en Supabase.';
      if (isSupabaseConfigured) {
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;
        if (user != null) {
          await client.from('channel_sync_submissions').insert({
            'user_id': user.id,
            'device_brand': _brand,
            'device_model': _model,
            'connection_type': 'demo_only',
            'source_host': '',
            'channel_count': 0,
            'channels': <Map<String, dynamic>>[],
            'status': 'pending_review',
          });
          remoteMessage =
              'Reporte de demostración guardado localmente y enviado a Supabase. No se subieron canales reales.';
        }
      }

      if (!mounted) return;
      setState(() {
        _saving = false;
        _reportSaved = true;
        _statusMessage = remoteMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _statusMessage =
            'El reporte quedó guardado localmente, pero no se pudo enviar a Supabase. Revisá la conexión y la configuración.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final models = _modelsByBrand[_brand] ?? const ['Modelo no especificado'];
    if (!models.contains(_model)) _model = models.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronización de equipos'),
        backgroundColor: AppTheme.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.satellite_alt_rounded,
                      color: AppTheme.accent, size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Detección y vinculación',
                      style:
                          TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                const Text(
                  'Elegí el equipo y ejecutá la demostración del flujo de búsqueda. No hace falta escribir URLs ni listas.',
                  style: TextStyle(color: AppTheme.muted, height: 1.45),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _brand,
                  decoration: const InputDecoration(labelText: 'Marca'),
                  items: _brands
                      .map((value) => DropdownMenuItem(
                          value: value, child: Text(value)))
                      .toList(),
                  onChanged: _scanning
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _brand = value;
                            _model = (_modelsByBrand[value] ?? _modelsByBrand.values.first).first;
                            _scanFinished = false;
                            _reportSaved = false;
                            _visibleChannels.clear();
                            _statusMessage = null;
                          });
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _model,
                  decoration: const InputDecoration(labelText: 'Modelo'),
                  items: models
                      .map((value) => DropdownMenuItem(
                          value: value, child: Text(value)))
                      .toList(),
                  onChanged: _scanning
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _model = value;
                            _scanFinished = false;
                            _reportSaved = false;
                            _visibleChannels.clear();
                            _statusMessage = null;
                          });
                        },
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Colors.orangeAccent),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Modo demostración: todavía no hay un adaptador real de red/protocolo para estos modelos. Los canales y S/Q de esta pantalla son ficticios y no se incorporan al catálogo.',
                          style: TextStyle(
                              color: AppTheme.muted, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _scanning ? null : _startScan,
                    icon: _scanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.radar_rounded),
                    label: Text(_scanning
                        ? 'BUSCANDO… $_progress%'
                        : 'BUSCAR / ESCANEAR DECODIFICADOR'),
                  ),
                ),
              ],
            ),
          ),
          if (_scanning || _scanFinished) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.panel,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(
                      _scanFinished
                          ? Icons.info_outline_rounded
                          : Icons.radar_rounded,
                      color: _scanFinished
                          ? Colors.orangeAccent
                          : AppTheme.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _scanFinished
                            ? 'Demostración terminada'
                            : 'Escaneo de demostración',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text('$_progress%'),
                  ]),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _progress / 100),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: _SignalMeter(
                        label: 'Fuerza S · DEMO',
                        value: _signalStrength,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SignalMeter(
                        label: 'Calidad Q · DEMO',
                        value: _signalQuality,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Text(
                    'Canales de prueba: ${_visibleChannels.length}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  for (final name in _visibleChannels)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.live_tv_rounded,
                          color: AppTheme.accent),
                      title: Text(name),
                      subtitle: const Text('Muestra ficticia · no disponible para reproducción'),
                    ),
                  if (_scanFinished) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving || _reportSaved ? null : _saveReport,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving
                            ? 'GUARDANDO REPORTE…'
                            : _reportSaved
                                ? 'REPORTE GUARDADO'
                                : 'GUARDAR REPORTE DE PRUEBA'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.panel,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _statusMessage!,
                style: const TextStyle(color: AppTheme.muted, height: 1.45),
              ),
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
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(value: value / 100, minHeight: 8),
          ),
          const SizedBox(height: 4),
          Text('$value%',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      );
}
