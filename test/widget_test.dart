import 'dart:ui' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miltv_plus/app.dart';
import 'package:miltv_plus/features/shell/app_shell.dart';
import 'package:miltv_plus/core/supabase_config.dart';

void main() {
  test('Supabase URL validation accepts only the canonical project URL', () {
    expect(isValidSupabaseUrl('https://project-ref.supabase.co'), isTrue);
    expect(isValidSupabaseUrl('https://project-ref.supabase.co/'), isTrue);
    expect(isValidSupabaseUrl(' https://project-ref.supabase.co/// '), isTrue);

    expect(isValidSupabaseUrl('http://project-ref.supabase.co'), isFalse);
    expect(isValidSupabaseUrl('https://project-ref.supabase.co/rest/v1'), isFalse);
    expect(isValidSupabaseUrl('https://supabase.com/dashboard/project/project-ref'), isFalse);
    expect(isValidSupabaseUrl('https://project-ref.supabase.co?apikey=test'), isFalse);
  });

  testWidgets('guest can enter the catalog after skipping the intro', (tester) async {
    SharedPreferences.setMockInitialValues({
      'miltv_terms_accepted_v1': true,
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MiltvPlusApp());
    expect(find.text('MILTVPLUS'), findsOneWidget);

    // The skip action intentionally appears after three seconds.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('OMITIR INTRO'), findsOneWidget);
    await tester.tap(find.text('OMITIR INTRO'));
    await tester.pumpAndSettle();

    // Guest catalog access must not require production Supabase credentials.
    expect(find.byType(AppShell), findsOneWidget);
  });
}
