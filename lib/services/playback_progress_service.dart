import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists VOD playback position without storing source URLs in plaintext keys.
class PlaybackProgressService {
  const PlaybackProgressService();

  static const minimumResumePosition = Duration(seconds: 10);
  static const completionThreshold = Duration(seconds: 30);

  static String keyFor({
    required String title,
    required String streamUrl,
  }) {
    final identity = sha256.convert(utf8.encode('$title\n$streamUrl'));
    return 'miltvplus_vod_progress_${identity.toString()}';
  }

  Future<Duration?> load({
    required String key,
    required Duration duration,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final milliseconds = preferences.getInt(key);
    if (milliseconds == null || duration <= Duration.zero) return null;

    final position = Duration(milliseconds: milliseconds);
    if (position < minimumResumePosition ||
        position >= duration ||
        duration - position <= completionThreshold) {
      await preferences.remove(key);
      return null;
    }
    return position;
  }

  Future<void> save({
    required String key,
    required Duration position,
    required Duration duration,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    if (duration <= Duration.zero ||
        position < minimumResumePosition ||
        position >= duration ||
        duration - position <= completionThreshold) {
      await preferences.remove(key);
      return;
    }
    await preferences.setInt(key, position.inMilliseconds);
  }

  Future<void> clear(String key) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
  }
}
