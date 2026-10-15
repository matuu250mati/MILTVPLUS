
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

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

  String _brand = _brands.first;
  String _model = _models.first;
  String? _scanMessage;

  @override
  void dispose() {
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _scanMessage =
          'La detección automática aún no puede ejecutarse: falta implementar el protocolo de descubrimiento y la API de lectura de canales para un modelo de decodificador compatible. No se simula una conexión ni se inventan niveles de señal.';
    });
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
                onChanged: (v) => setState(() => _brand = v ?? _brands.first),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _model,
                decoration: const InputDecoration(labelText: 'Modelo / estándar'),
                items: _models.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setState(() => _model = v ?? _models.first),
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
              if (_scanMessage != null) ...[
                const SizedBox(height: 12),
                Text(_scanMessage!, style: const TextStyle(color: Colors.orangeAccent, height: 1.4)),
              ],
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.radar_rounded),
                label: const Text('BUSCAR DECODIFICADOR'),
              )),
            ]),
          ),
          if (_scanMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.panel,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.orangeAccent),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Detección directa no disponible',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(_scanMessage!, style: const TextStyle(color: AppTheme.muted, height: 1.45)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

