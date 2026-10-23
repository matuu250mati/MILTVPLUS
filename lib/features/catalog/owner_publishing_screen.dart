import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';

/// Owner-only publisher. RLS and Storage policies enforce authorization server-side.
class OwnerPublishingScreen extends StatefulWidget {
  const OwnerPublishingScreen({super.key});

  @override
  State<OwnerPublishingScreen> createState() => _OwnerPublishingScreenState();
}

class _OwnerPublishingScreenState extends State<OwnerPublishingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _synopsis = TextEditingController();
  final _category = TextEditingController(text: 'Drama');
  final _genres = TextEditingController();
  final _posterUrl = TextEditingController();
  final _streamUrl = TextEditingController();
  final _year = TextEditingController(text: DateTime.now().year.toString());
  final _season = TextEditingController(text: '1');
  final _episode = TextEditingController(text: '1');

  String _type = 'movie';
  String? _seriesId;
  List<Map<String, dynamic>> _seriesOptions = const [];
  PlatformFile? _video;
  bool _publishing = false;
  String? _status;

  bool get _isOwner {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.appMetadata['role'] == 'owner';
  }

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  @override
  void dispose() {
    _title.dispose();
    _synopsis.dispose();
    _category.dispose();
    _genres.dispose();
    _posterUrl.dispose();
    _streamUrl.dispose();
    _year.dispose();
    _season.dispose();
    _episode.dispose();
    super.dispose();
  }

  Future<void> _loadSeries() async {
    if (!_isOwner) return;
    try {
      final rows = await Supabase.instance.client
          .from('series')
          .select('id,title')
          .order('title');
      if (!mounted) return;
      setState(() {
        _seriesOptions = (rows as List<dynamic>)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
        if (_seriesId != null &&
            !_seriesOptions.any((row) => row['id'] == _seriesId)) {
          _seriesId = null;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _status =
            'No se pudieron leer las series. Verificá que la migración owner-only esté aplicada y volvé a iniciar sesión.');
      }
    }
  }

  Future<void> _pickVideo() async {
    final selected = await FilePicker.pickFile(type: FileType.video);
    if (!mounted || selected == null) return;
    setState(() {
      _video = selected;
      _streamUrl.clear();
      _status = null;
    });
  }

  String _safeFileName(String value) {
    final name = value.split(RegExp(r'[/\\]')).last;
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  String _mimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    return 'video/mp4';
  }

  Future<String> _resolveStreamUrl() async {
    final typedUrl = _streamUrl.text.trim();
    if (typedUrl.isNotEmpty) {
      final uri = Uri.tryParse(typedUrl);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException('La URL del video debe ser HTTPS válida.');
      }
      return typedUrl;
    }
    final selected = _video;
    if (selected == null || selected.path == null) {
      throw const FormatException('Seleccioná un archivo de video o pegá una URL HTTPS autorizada.');
    }
    final path = selected.path!;
    final storagePath =
        'catalog/${DateTime.now().toUtc().millisecondsSinceEpoch}_${_safeFileName(selected.name)}';
    await Supabase.instance.client.storage.from('owner-media').upload(
          storagePath,
          File(path),
          fileOptions: FileOptions(
            contentType: _mimeType(path),
            upsert: false,
          ),
        );
    return Supabase.instance.client.storage
        .from('owner-media')
        .getPublicUrl(storagePath);
  }

  Future<void> _publish() async {
    if (!_isOwner) {
      setState(() => _status = 'Acceso denegado. Esta función pertenece al propietario.');
      return;
    }
    if (_publishing || !_formKey.currentState!.validate()) return;
    if (_type == 'episode' && _seriesId == null) {
      setState(() => _status = 'Elegí la serie a la que pertenece este episodio.');
      return;
    }
    setState(() {
      _publishing = true;
      _status = 'Preparando contenido y verificando permisos…';
    });
    try {
      final client = Supabase.instance.client;
      final title = _title.text.trim();
      final synopsis = _synopsis.text.trim();
      final genres = _genres.text
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      final poster = _posterUrl.text.trim().isEmpty
          ? null
          : _posterUrl.text.trim();
      final year = int.tryParse(_year.text.trim());
      if (_type != 'series') {
        final streamUrl = await _resolveStreamUrl();
        if (_type == 'movie') {
          await client.from('movies').insert({
            'title': title,
            'synopsis': synopsis,
            'category': _category.text.trim().isEmpty ? 'Películas' : _category.text.trim(),
            'genres': genres,
            'logo': poster,
            'url_stream': streamUrl,
            'release_year': year,
            'country_code': 'AR',
            'is_published': true,
          });
        } else {
          await client.from('episodes').insert({
            'series_id': _seriesId,
            'title': title,
            'synopsis': synopsis,
            'season_number': int.parse(_season.text.trim()),
            'episode_number': int.parse(_episode.text.trim()),
            'logo': poster,
            'url_stream': streamUrl,
            'is_published': true,
          });
        }
      } else {
        await client.from('series').insert({
          'title': title,
          'synopsis': synopsis,
          'category': _category.text.trim().isEmpty ? 'Series' : _category.text.trim(),
          'genres': genres,
          'logo': poster,
          'release_year': year,
          'country_code': 'AR',
          'is_published': true,
        });
        await _loadSeries();
      }
      if (!mounted) return;
      setState(() {
        _status = 'Contenido publicado. El catálogo lo mostrará a los usuarios autorizados.';
        _title.clear();
        _synopsis.clear();
        _streamUrl.clear();
        _video = null;
      });
    } on StorageException catch (error) {
      if (mounted) {
        setState(() => _status =
            'No se pudo subir el archivo: ${error.message}. Revisá el límite de almacenamiento del proyecto y los permisos owner-media.');
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _status =
            'Supabase rechazó la publicación (${error.code ?? 'sin código'}): ${error.message}. Confirmá que tu usuario tenga app_metadata.role = owner y que la migración esté aplicada.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = error is FormatException
            ? error.message
            : 'No se pudo publicar el contenido. Revisá la conexión, la URL/archivo y la configuración de Supabase.');
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOwner) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 54, color: AppTheme.accent),
              SizedBox(height: 14),
              Text('Panel privado del propietario',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text(
                'Esta función solo está disponible para la cuenta a la que el servidor haya asignado el rol owner.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    return ListView(
      padding: EdgeInsets.fromLTRB(width < 600 ? 16 : 28, 18, width < 600 ? 16 : 28, 30),
      children: [
        const Text('PUBLICAR CONTENIDO',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text(
          'Panel privado del propietario. Lo que publiques aparece en el catálogo para usuarios autenticados autorizados.',
          style: TextStyle(color: AppTheme.muted, height: 1.45),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(_type),
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Qué vas a publicar'),
                    items: const [
                      DropdownMenuItem(value: 'movie', child: Text('Película')),
                      DropdownMenuItem(value: 'series', child: Text('Serie / catálogo')),
                      DropdownMenuItem(value: 'episode', child: Text('Episodio de una serie')),
                    ],
                    onChanged: _publishing ? null : (value) {
                      if (value == null) return;
                      setState(() {
                        _type = value;
                        _status = null;
                        _video = null;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  if (_type == 'episode') ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey(_seriesId),
                      initialValue: _seriesId,
                      decoration: const InputDecoration(labelText: 'Serie de destino'),
                      items: _seriesOptions.map((row) => DropdownMenuItem<String>(
                        value: row['id'] as String,
                        child: Text(row['title'] as String, overflow: TextOverflow.ellipsis),
                      )).toList(growable: false),
                      onChanged: _publishing ? null : (value) => setState(() => _seriesId = value),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: TextFormField(
                        controller: _season,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Temporada'),
                        validator: (v) => (int.tryParse((v ?? '').trim()) ?? 0) > 0 ? null : 'Usá un número mayor que cero.',
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(
                        controller: _episode,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Episodio'),
                        validator: (v) => (int.tryParse((v ?? '').trim()) ?? 0) > 0 ? null : 'Usá un número mayor que cero.',
                      )),
                    ]),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Título'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'El título es obligatorio.' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _synopsis,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Descripción / sinopsis'),
                  ),
                  if (_type != 'episode') ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _category,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _genres,
                      decoration: const InputDecoration(labelText: 'Géneros separados por coma'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _year,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Año de estreno'),
                      validator: (v) {
                        final value = int.tryParse((v ?? '').trim());
                        return value != null && value >= 1888 && value <= DateTime.now().year + 10
                            ? null : 'Ingresá un año válido.';
                      },
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _posterUrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(labelText: 'URL HTTPS del póster (opcional)'),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return null;
                      final uri = Uri.tryParse(value);
                      return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
                          ? null : 'El póster debe usar HTTPS.';
                    },
                  ),
                  if (_type != 'series') ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _publishing ? null : _pickVideo,
                      icon: const Icon(Icons.video_file_outlined),
                      label: Text(_video?.name ?? 'Seleccionar archivo de video'),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('O usá una URL HTTPS de contenido que tengas derecho a publicar.',
                          style: TextStyle(color: AppTheme.muted, fontSize: 12)),
                    ),
                    TextFormField(
                      controller: _streamUrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(labelText: 'URL HTTPS del video (opcional si seleccionaste archivo)'),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty || _video != null) return null;
                        final uri = Uri.tryParse(value);
                        return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
                            ? null : 'Ingresá una URL HTTPS válida.';
                      },
                    ),
                  ],
                  const SizedBox(height: 14),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _publishing ? null : _publish,
                    icon: _publishing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.publish_rounded),
                    label: Text(_publishing ? 'PUBLICANDO…' : 'GUARDAR Y PUBLICAR'),
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 14),
                    SelectableText(_status!, style: const TextStyle(height: 1.4)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
