import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nelko_p21_ask_mobile/main.dart';
import 'package:nelko_p21_ask_mobile/core/printer_controller.dart';
import 'fake_platform.dart';

void main() {
  testWidgets('experimental warning, Danish/English, diagnostics and offline export', (tester) async {
    final p=FakePlatform();
    final c=PrinterController(p,sleep:(_)async{});
    await tester.pumpWidget(AskMobileApp(controller:c)); await tester.pumpAndSettle();
    expect(find.textContaining('IKKE hardwarebekræftet'),findsOneWidget);
    expect(find.text('Printere'),findsOneWidget);
    await c.setLanguage('en'); await tester.pumpAndSettle();
    expect(find.text('Printers'),findsOneWidget);
    expect(find.textContaining('NOT hardware-confirmed'),findsOneWidget);
    await tester.tap(find.text('Diagnostics')); await tester.pumpAndSettle();
    final printButton=tester.widget<FilledButton>(find.widgetWithText(FilledButton,'Test print (one label)'));
    expect(printButton.onPressed,isNull);
    await tester.tap(find.text('Export local log')); await tester.pumpAndSettle();
    expect(p.exported,contains('NOT CONFIRMED'));
    await tester.pumpWidget(const SizedBox.shrink()); await tester.pumpAndSettle(); await p.close();
  });
}
