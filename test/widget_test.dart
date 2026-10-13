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

  testWidgets('MILTV PLUS intro opens authentication when Supabase is not configured', (tester) async {
    await tester.pumpWidget(const MiltvPlusApp());
    expect(find.text('MILTV PLUS'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    expect(
      find.text('Falta SUPABASE_URL. Configurá la URL del proyecto en los secretos de GitHub Actions.'),
      findsOneWidget,
    );
    expect(find.text('TV EN VIVO'), findsNothing);
  });
}
