import 'package:flutter_test/flutter_test.dart';
import 'package:miltv_plus/app.dart';

void main() {
  testWidgets('MILTV PLUS intro opens authentication when Supabase is not configured', (tester) async {
    await tester.pumpWidget(const MiltvPlusApp());
    expect(find.text('MILTV PLUS'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    expect(find.text('Acceso bloqueado: configurá SUPABASE_URL y SUPABASE_ANON_KEY (publishable key) en los parámetros de compilación.'), findsOneWidget);
    expect(find.text('TV EN VIVO'), findsNothing);
  });
}
