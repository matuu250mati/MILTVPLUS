import 'dart:ui' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:miltv_plus/app.dart';
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

  testWidgets('MILTVPLUS requires Supabase configuration and authentication before opening the catalog', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MiltvPlusApp());
    expect(find.text('MILTVPLUS'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    // Tests run without production --dart-define values, so the auth gate must
    // show a clear configuration error rather than exposing the catalog shell.
    expect(find.textContaining('Falta SUPABASE_URL'), findsOneWidget);
    expect(find.text('TV EN VIVO'), findsNothing);
    expect(find.text('PELÍCULAS'), findsNothing);
  });
}
