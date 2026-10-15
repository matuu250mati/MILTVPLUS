import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miltv_plus/features/onboarding/miltvplus_guide.dart';

void main() {
  testWidgets('guided onboarding advances without a skip action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showMiltvPlusGuide(
                  context,
                  profileName: 'Matias',
                ),
                child: const Text('Abrir guía'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir guía'));
    await tester.pumpAndSettle();

    expect(find.text('¡Bienvenido, Matias!'), findsOneWidget);
    expect(find.text('SIGUIENTE'), findsOneWidget);
    expect(find.text('OMITIR'), findsNothing);

    await tester.tap(find.text('SIGUIENTE'));
    await tester.pumpAndSettle();
    expect(find.text('TV en Vivo y Deportes'), findsOneWidget);
    expect(find.text('ANTERIOR'), findsOneWidget);

    await tester.tap(find.text('ANTERIOR'));
    await tester.pumpAndSettle();
    expect(find.text('¡Bienvenido, Matias!'), findsOneWidget);
  });
}
