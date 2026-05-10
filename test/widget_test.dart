import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trashpotting_v3/app.dart';

void main() {
  testWidgets('Main shell opens on Mappa tab', (WidgetTester tester) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        const TrashpottingApp(firebaseReady: false, firebaseError: 'test skip'),
      );
      await tester.pump();

      expect(find.text('Mappa'), findsWidgets);
      expect(
        find.textContaining('Google Maps è disponibile'),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });
}
