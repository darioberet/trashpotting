import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trashpotting_v3/theme/app_icons.dart';
import 'package:trashpotting_v3/widgets/app_text_field.dart';

Future<TextField> _fieldFor(WidgetTester tester, TextInputType type) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppTextField(
          label: 'Campo',
          icon: AppIcons.email,
          keyboardType: type,
        ),
      ),
    ),
  );
  return tester.widget<TextField>(find.byType(TextField));
}

void main() {
  testWidgets('email: niente correzione né suggerimenti', (tester) async {
    final field = await _fieldFor(tester, TextInputType.emailAddress);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
  });

  testWidgets('testo normale: correzione attiva', (tester) async {
    final field = await _fieldFor(tester, TextInputType.text);
    expect(field.autocorrect, isTrue);
    expect(field.enableSuggestions, isTrue);
  });
}
