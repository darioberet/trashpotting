import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trashpotting_v3/widgets/phone_frame.dart';

Future<Size> _sizeSeenBy(WidgetTester tester, Size screen) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  late Size seen;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => PhoneFrame(child: child!),
      home: Builder(
        builder: (context) {
          seen = MediaQuery.sizeOf(context);
          return const SizedBox.expand();
        },
      ),
    ),
  );
  return seen;
}

void main() {
  testWidgets('sul telefono non cambia niente', (tester) async {
    final seen = await _sizeSeenBy(tester, const Size(400, 800));
    expect(seen.width, 400);
  });

  testWidgets('su schermo largo le schermate vedono una colonna', (
    tester,
  ) async {
    final seen = await _sizeSeenBy(tester, const Size(1400, 900));
    expect(seen.width, PhoneFrame.maxWidth);
    expect(
      tester.getSize(find.byType(SizedBox).last).width,
      PhoneFrame.maxWidth,
    );
  });
}
