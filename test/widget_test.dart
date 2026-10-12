import 'package:flutter_test/flutter_test.dart';
import 'package:miltv_plus/app.dart';

void main() {
  testWidgets('MILTV PLUS intro navigates to main screen', (tester) async {
    await tester.pumpWidget(const MiltvPlusApp());
    expect(find.text('MILTV PLUS'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    expect(find.text('TV EN VIVO'), findsWidgets);
    expect(find.text('MILTV\nPLUS'), findsOneWidget);
  });
}
