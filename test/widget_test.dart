import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trashpotting_v3/app.dart';

void main() {
  testWidgets('Login is the first screen on app startup', (
    WidgetTester tester,
  ) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        const TrashpottingApp(firebaseReady: false, firebaseError: 'test skip'),
      );
      await tester.pump();

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Non hai un account? Registrati'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });
}
