import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide accessibility preferences. Defaults preserve the existing design.
abstract final class AppAccessibilitySettings {
  static const _textScaleKey = 'miltvplus_accessibility_text_scale_v1';
  static final ValueNotifier<double> textScale = ValueNotifier<double>(1.0);

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getDouble(_textScaleKey) ?? 1.0;
    textScale.value = _normalize(saved);
  }

  static Future<void> setTextScale(double value) async {
    final normalized = _normalize(value);
    textScale.value = normalized;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_textScaleKey, normalized);
  }

  static double _normalize(double value) {
    if (value < 1.0) return 1.0;
    if (value > 1.35) return 1.35;
    return value;
  }
}
