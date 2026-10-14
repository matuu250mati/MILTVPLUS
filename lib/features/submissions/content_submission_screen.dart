import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';
import '../../core/theme/app_theme.dart';

class ContentSubmissionScreen extends StatefulWidget {
  const ContentSubmissionScreen({super.key});

  @override
  State<ContentSubmissionScreen> createState() => _ContentSubmissionScreenState();
}

class _ContentSubmissionScreenState extends State<ContentSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _streamUrl = TextEditingController();
  final _posterUrl = TextEditingController();
  final _duration = TextEditingController();
  final _seriesTitle = TextEditingController();
  final _season = TextEditingController();
  final _episode = TextEditingController();
  String _type = 'movie';
  bool _rightsConfirmed = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_title, _description, _streamUrl, _posterUrl, _duration,
      _seriesTitle, _season, _episode]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value, {int max = 160}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Campo obligatorio.';
    return v.length > max ? 'Máximo $max caracteres.' : null;
  }

  String? _url(String? value, {bool optional = false}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty && optional) return null;
    final uri = Uri.tryParse(v);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasFragment) {
      return 'Ingresá una URL HTTPS válida.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    if (!_rightsConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirmá que tenés derechos para compartir este contenido.')),
      );
      return;
    }
    if (!isSupabaseConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(supabaseConfigurationError ?? 'Supabase no está configurado.')),
      );
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iniciá sesión para enviar una propuesta.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final mins = int.tryParse(_duration.text.trim());
      final data = <String, dynamic>{
        'user_id': user.id,
        'media_type': _type,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'stream_url': _streamUrl.text.trim(),
        'poster_url': _posterUrl.text.trim().isEmpty ? null : _posterUrl.text.trim(),
        'duration_seconds': mins == null ? null : mins * 60,
        'series_title': _type == 'episode' ? _seriesTitle.text.trim() : null,
        'season_number': _type == 'episode' ? int.parse(_season.text.trim()) : null,
        'episode_number': _type == 'episode' ? int.parse(_episode.text.trim()) : null,
        'rights_confirmed': true,
        'moderation_status': 'pending',
      };
      await Supabase.instance.client.from('content_submissions').insert(data);
      if (!mounted) return;
      for (final c in [_title, _description, _streamUrl, _posterUrl, _duration,
        _seriesTitle, _season, _episode]) {
        c.clear();
      }
      setState(() {
        _type = 'movie';
        _rightsConfirmed = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Propuesta enviada. Queda pendiente de revisión.')),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar: ${e.message}. Verificá la migración de Supabase.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar. Revisá los datos y la conexión.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = isSupabaseConfigured &&
        Supabase.instance.client.auth.currentUser != null;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('PUBLICAR CONTENIDO',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text(
          'Proponé una película o un episodio para el catálogo compartido. Cada envío se revisa antes de publicarse.',
          style: TextStyle(color: AppTheme.muted, height: 1.45),
        ),
        const SizedBox(height: 18),
        if (!signedIn)
          const Text('Necesitás iniciar sesión para enviar propuestas.',
              style: TextStyle(color: AppTheme.muted)),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'movie', child: Text('Película')),
                  DropdownMenuItem(value: 'episode', child: Text('Episodio de serie')),
                ],
                onChanged: _busy ? null : (v) => setState(() => _type = v ?? 'movie'),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _title, maxLength: 160,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: _required),
              TextFormField(controller: _description, minLines: 3, maxLines: 6,
                maxLength: 3000,
                decoration: const InputDecoration(labelText: 'Descripción'),
                validator: (v) => _required(v, max: 3000)),
              if (_type == 'episode') ...[
                TextFormField(controller: _seriesTitle, maxLength: 160,
                  decoration: const InputDecoration(labelText: 'Título de la serie'),
                  validator: _required),
                Row(children: [
                  Expanded(child: TextFormField(controller: _season,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Temporada'),
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Número desde 1.' : null)),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _episode,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Episodio'),
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Número desde 1.' : null)),
                ]),
              ],
              TextFormField(controller: _duration, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duración en minutos (opcional)'),
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return null;
                  final n = int.tryParse(v!.trim());
                  return n == null || n < 1 || n > 100000 ? 'Duración inválida.' : null;
                }),
              TextFormField(controller: _streamUrl, keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'URL HTTPS del video autorizado'),
                validator: _url),
              TextFormField(controller: _posterUrl, keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'URL HTTPS del póster (opcional)'),
                validator: (v) => _url(v, optional: true)),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _rightsConfirmed,
                onChanged: _busy ? null : (v) => setState(() => _rightsConfirmed = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Confirmo que tengo los derechos o autorización para publicar este contenido.'),
                subtitle: const Text('No se admite contenido ilegal, enlaces pirateados ni material que infrinja las normas de la plataforma.'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy || !signedIn ? null : _submit,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.publish_rounded),
                label: Text(_busy ? 'ENVIANDO…' : 'ENVIAR A REVISIÓN'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
