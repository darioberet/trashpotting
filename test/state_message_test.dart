import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trashpotting_v3/theme/app_icons.dart';
import 'package:trashpotting_v3/widgets/state_message.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('senza azione non mostra pulsanti', (tester) async {
    await tester.pumpWidget(
      _host(
        const StateMessage(
          icon: AppIcons.place,
          title: 'Niente da queste parti',
          message: 'Prova ad allargare il raggio.',
        ),
      ),
    );

    expect(find.text('Niente da queste parti'), findsOneWidget);
    expect(find.text('Riprova'), findsNothing);
  });

  testWidgets('il pulsante chiama l\'azione', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      _host(
        StateMessage(
          icon: AppIcons.offline,
          title: 'Classifica non disponibile',
          message: 'Controlla la connessione e riprova.',
          actionLabel: 'Riprova',
          onAction: () => retried++,
        ),
      ),
    );

    await tester.tap(find.text('Riprova'));
    await tester.pumpAndSettle();
    expect(retried, 1);
  });
}
