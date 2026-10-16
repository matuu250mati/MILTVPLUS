import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:miltv_plus/core/accessibility_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('accessibility text scale defaults, persists, and is bounded', () async {
    SharedPreferences.setMockInitialValues({});
    AppAccessibilitySettings.textScale.value = 1.0;

    await AppAccessibilitySettings.load();
    expect(AppAccessibilitySettings.textScale.value, 1.0);

    await AppAccessibilitySettings.setTextScale(1.3);
    expect(AppAccessibilitySettings.textScale.value, 1.2);

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getDouble('miltvplus_accessibility_text_scale_v1'),
      1.2,
    );

    await AppAccessibilitySettings.setTextScale(2.0);
    expect(AppAccessibilitySettings.textScale.value, 1.2);
  });
}
