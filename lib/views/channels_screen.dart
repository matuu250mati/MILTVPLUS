import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/media_models.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  final _supabase = Supabase.instance.client;
  List<ChannelModel> channels = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchChannels();
  }

  Future<void> fetchChannels() async {
    try {
      // Fetch all published rows in bounded pages; PostgREST may cap a single
      // response at 1,000 rows. Stable ordering prevents rows being skipped
      // between pages when many channels share the same display title.
      const pageSize = 500;
      final data = <Map<String, dynamic>>[];
      for (var offset = 0;; offset += pageSize) {
        final response = await _supabase
            .from('channels')
            .select()
            .eq('is_published', true)
            .order('sort_order', ascending: true)
            .order('title', ascending: true)
            .order('id', ascending: true)
            .range(offset, offset + pageSize - 1);
        final page = List<Map<String, dynamic>>.from(response);
        data.addAll(page);
        if (page.length < pageSize) break;
      }
      if (!mounted) return;
      setState(() {
        channels = data.map((json) => ChannelModel.fromJson(json)).toList();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar canales: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('MILTV PLUS - Canales en Vivo'),
        backgroundColor: Colors.black,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : channels.isEmpty
              ? const Center(
                  child: Text(
                    'No hay canales cargados todavía.',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: channels.length,
                  itemBuilder: (context, index) {
                    final channel = channels[index];
                    return InkWell(
                      onTap: () {
                        // La navegación al reproductor se integra en el módulo TV.
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            channel.logo != null && channel.logo!.isNotEmpty
                                ? Image.network(
                                    channel.logo!,
                                    height: 60,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(
                                      Icons.tv,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.tv,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                channel.title,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
