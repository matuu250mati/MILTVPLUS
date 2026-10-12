import 'package:flutter_test/flutter_test.dart';
import 'package:miltv_plus/app.dart';

void main() {
  testWidgets('MILTV PLUS opens with main navigation', (tester) async {
    await tester.pumpWidget(const MiltvPlusApp());
    await tester.pumpAndSettle();
    expect(find.text('TV EN VIVO'), findsWidgets);
    expect(find.text('MILTV\nPLUS'), findsOneWidget);
  });
}
