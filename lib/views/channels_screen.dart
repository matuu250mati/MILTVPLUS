import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_theme.dart';
import '../features/live/live_player_screen.dart';
import '../models/media_models.dart';
import '../models/tv_channel.dart';

/// Live-channel browser with scrollable category filters and direct playback.
/// The channel list comes only from the published Supabase catalog.
class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  List<ChannelModel> _channels = const [];
  bool _isLoading = true;
  String? _error;
  String _selectedCategory = 'Todos';
  String _query = '';

  @override
  void initState() {
    super.initState();
    fetchChannels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchChannels() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final response = await _supabase.from('channels').select();
      final data = List<Map<String, dynamic>>.from(response);
      final loaded = data
          .map(ChannelModel.fromJson)
          .where((channel) => channel.isPublished)
          .toList()
        ..sort((a, b) {
          final order = a.sortOrder.compareTo(b.sortOrder);
          return order != 0 ? order : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      if (!mounted) return;
      setState(() {
        _channels = loaded;
        _isLoading = false;
        if (!_categories.contains(_selectedCategory)) {
          _selectedCategory = 'Todos';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'No se pudieron cargar los canales. Revisá la conexión e intentá nuevamente.';
      });
    }
  }

  List<String> get _categories {
    final values = _channels
        .map((channel) => channel.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['Todos', ...values];
  }

  List<ChannelModel> get _filteredChannels {
    final query = _query.trim().toLowerCase();
    return _channels.where((channel) {
      final matchesCategory = _selectedCategory == 'Todos' ||
          channel.category.trim() == _selectedCategory;
      final matchesQuery = query.isEmpty ||
          channel.title.toLowerCase().contains(query) ||
          channel.category.toLowerCase().contains(query) ||
          channel.countryCode.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList(growable: false);
  }

  Future<void> _playChannel(ChannelModel channel) async {
    final urls = <String>[];
    for (final raw in [...channel.streamUrls, channel.urlStream]) {
      final value = raw.trim();
      final uri = Uri.tryParse(value);
      if (value.isNotEmpty &&
          uri != null &&
          uri.scheme == 'https' &&
          uri.hasAuthority &&
          !uri.userInfo.isNotEmpty &&
          !urls.contains(value)) {
        urls.add(value);
      }
    }
    if (urls.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${channel.title} todavía no tiene una fuente HTTPS válida publicada.'),
          backgroundColor: AppTheme.panel,
        ),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LivePlayerScreen(
          channels: [
            TvChannel(
              name: channel.title,
              streamUrl: urls.first,
              category: channel.category,
              country: channel.countryCode,
              logoUrl: channel.logo,
              backupStreamUrls: urls.skip(1).toList(growable: false),
            ),
          ],
          initialIndex: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('MILTVPLUS · TV en vivo'),
        actions: [
          IconButton(
            tooltip: 'Actualizar canales',
            onPressed: _isLoading ? null : fetchChannels,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar canal, categoría o país…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final selected = category == _selectedCategory;
                  return ChoiceChip(
                    label: Text(category),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: AppTheme.accent,
                    backgroundColor: AppTheme.panel,
                    side: BorderSide(
                      color: selected ? AppTheme.accent : AppTheme.selectedAccent.withValues(alpha: .35),
                    ),
                    labelStyle: TextStyle(
                      color: selected ? AppTheme.background : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    onSelected: (_) => setState(() => _selectedCategory = category),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildChannelBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelBody() {
    if (_isLoading && _channels.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }
    if (_error != null && _channels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppTheme.muted),
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: fetchChannels,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredChannels;
    if (filtered.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.accent,
        onRefresh: fetchChannels,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 70),
            Icon(
              _channels.isEmpty ? Icons.live_tv_rounded : Icons.search_off_rounded,
              size: 54,
              color: AppTheme.muted,
            ),
            const SizedBox(height: 12),
            Text(
              _channels.isEmpty
                  ? 'Todavía no hay canales publicados.'
                  : 'No hay canales que coincidan con el filtro.',
              textAlign: TextAlign.center,
            ),
            if (_channels.isNotEmpty)
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _query = '';
                    _selectedCategory = 'Todos';
                  });
                },
                child: const Text('Limpiar filtros'),
              ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1350 ? 6 : width >= 1000 ? 5 : width >= 680 ? 4 : width >= 420 ? 3 : 2;
        return RefreshIndicator(
          color: AppTheme.accent,
          onRefresh: fetchChannels,
          child: GridView.builder(
            key: PageStorageKey<String>('channels-$_selectedCategory-$_query'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: width < 420 ? .86 : 1.02,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final channel = filtered[index];
              return Material(
                color: AppTheme.panel,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _playChannel(channel),
                  focusColor: AppTheme.selectedAccent.withValues(alpha: .22),
                  hoverColor: AppTheme.selectedAccent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.selectedAccent.withValues(alpha: .28)),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: channel.logo != null
                                ? Image.network(
                                    channel.logo!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.live_tv_rounded,
                                      size: 42,
                                      color: AppTheme.accent,
                                    ),
                                  )
                                : const Icon(
                                    Icons.live_tv_rounded,
                                    size: 42,
                                    color: AppTheme.accent,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          channel.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          channel.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
