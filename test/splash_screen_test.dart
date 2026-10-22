import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miltv_plus/features/splash/splash_screen.dart';

void main() {
  testWidgets('splash stays centered and overflow-free on mobile, TV, and wide screens',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const viewports = <Size>[
      Size(320, 568),
      Size(844, 390),
      Size(1280, 720),
      Size(1920, 1080),
      Size(3840, 2160),
    ];

    for (final viewport in viewports) {
      tester.view.physicalSize = viewport;
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('MILTVPLUS'), findsOneWidget, reason: 'viewport: $viewport');
      expect(
        find.text('ENTRETENIMIENTO ARGENTINO'),
        findsOneWidget,
        reason: 'viewport: $viewport',
      );
      expect(tester.takeException(), isNull, reason: 'viewport: $viewport');
    }
  });
}
