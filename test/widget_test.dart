import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:trashpotting_v3/app.dart';

void main() {
  // ThemeController usa SharedPreferencesAsync: nei test serve un backend.
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

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

      expect(find.text('Bentornato'), findsOneWidget);
      expect(find.text('Accedi'), findsOneWidget);
      // Il link è in fondo alla pagina: va portato a schermo.
      await tester.scrollUntilVisible(
        find.text('Registrati'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Registrati'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });
}
