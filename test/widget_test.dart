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

  testWidgets('MILTV PLUS intro opens browseable home without requiring an account', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MiltvPlusApp());
    expect(find.text('MILTV PLUS'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    expect(find.text('TV EN VIVO'), findsOneWidget);
    expect(find.text('EXPLORÁ POR CATEGORÍA'), findsOneWidget);
    expect(find.text('INICIAR SESIÓN'), findsNothing);
    expect(find.text('Películas'), findsOneWidget);
  });
}
