import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import '../catalog/catalog_player_screen.dart';

class ContentModerationScreen extends StatefulWidget {
  const ContentModerationScreen({super.key});

  @override
  State<ContentModerationScreen> createState() => _ContentModerationScreenState();
}

class _ContentModerationScreenState extends State<ContentModerationScreen> {
  late Future<List<Map<String, dynamic>>> _pendingFuture;
  final Set<String> _busyIds = <String>{};

  bool get _isModerator {
    if (!isSupabaseConfigured) return false;
    final role = Supabase.instance.client.auth.currentUser?.appMetadata['role'];
    return role == 'admin' || role == 'moderator';
  }

  @override
  void initState() {
    super.initState();
    _pendingFuture = _loadPending();
  }

  Future<List<Map<String, dynamic>>> _loadPending() async {
    if (!_isModerator) return const [];
    final rows = await Supabase.instance.client
        .from('content_submissions')
        .select('id, media_type, title, description, stream_url, poster_url, duration_seconds, series_title, season_number, episode_number, created_at')
        .eq('moderation_status', 'pending')
        .order('created_at', ascending: true);
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<void> _preview(Map<String, dynamic> item) async {
    final url = item['stream_url'] as String? ?? '';
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La propuesta no tiene una URL HTTPS válida para probar.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogPlayerScreen(
          title: 'Revisión: ${item['title'] as String? ?? 'Contenido'}',
          streamUrl: url,
        ),
      ),
    );
  }

  Future<void> _setStatus(Map<String, dynamic> item, String status) async {
    final id = item['id'] as String;
    if (_busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      final updatedRows = await Supabase.instance.client
          .from('content_submissions')
          .update({'moderation_status': status})
          .eq('id', id)
          .eq('moderation_status', 'pending')
          .select('id');
      if (updatedRows.isEmpty) {
        throw StateError(
          'La propuesta no cambió de estado. Verificá tu rol de moderador y las políticas RLS.',
        );
      }
      if (!mounted) return;
      setState(() => _pendingFuture = _loadPending());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == 'approved'
            ? 'Contenido aprobado y agregado al catálogo público.'
            : 'Propuesta rechazada.')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message
          : 'No se pudo actualizar la propuesta. Revisá la conexión y los permisos.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.toString())),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isModerator) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Esta sección es exclusiva para moderadores autorizados.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MODERACIÓN DE CONTENIDO',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(
            'Revisá derechos, calidad, seguridad y adecuación antes de publicar. Solo se mostrarán al público las propuestas aprobadas.',
            style: TextStyle(color: AppTheme.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _pendingFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No se pudieron cargar las propuestas pendientes.'),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: () => setState(() => _pendingFuture = _loadPending()),
                          child: const Text('REINTENTAR'),
                        ),
                      ],
                    ),
                  );
                }
                final items = snapshot.data ?? const <Map<String, dynamic>>[];
                if (items.isEmpty) {
                  return const Center(
                    child: Text('No hay propuestas pendientes.',
                        style: TextStyle(color: AppTheme.muted)),
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final id = item['id'] as String;
                    final episode = item['media_type'] == 'episode';
                    final duration = (item['duration_seconds'] as num?)?.toInt();
                    final busy = _busyIds.contains(id);
                    final episodeInfo = episode
                        ? ' · ${item['series_title'] ?? 'Serie'} · T${item['season_number']} E${item['episode_number']}'
                        : '';
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['title'] as String? ?? 'Sin título',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            Text(
                              '${episode ? 'Episodio' : 'Película'}$episodeInfo'
                              '${duration == null ? '' : ' · ${(duration / 60).ceil()} min'}',
                              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Text(item['description'] as String? ?? ''),
                            const SizedBox(height: 8),
                            SelectableText(
                              'URL: ${item['stream_url'] as String? ?? 'No disponible'}',
                              style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: busy ? null : () => _preview(item),
                                  icon: const Icon(Icons.play_circle_outline_rounded),
                                  label: const Text('PROBAR VIDEO'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: busy ? null : () => _setStatus(item, 'rejected'),
                                  icon: const Icon(Icons.close_rounded),
                                  label: const Text('RECHAZAR'),
                                ),
                                FilledButton.icon(
                                  onPressed: busy ? null : () => _setStatus(item, 'approved'),
                                  icon: busy
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.check_rounded),
                                  label: const Text('APROBAR'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
