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
  testWidgets('text editor previews Danish multiline label and prints the exact bitmap', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400,1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final p=FakePlatform(); final c=PrinterController(p,sleep:(_)async{});
    await tester.pumpWidget(AskMobileApp(controller:c)); await tester.pumpAndSettle();
    c.selectDevice(printerA); await c.connectSelected(); await tester.pumpAndSettle();
    await tester.tap(find.text('Etiket')); await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('print-label'))).onPressed,isNull);
    await tester.runAsync(() async {
      await tester.enterText(find.byKey(const Key('label-text')),'HP PROXMOX PVE1\nÆble øl å');
      await Future<void>.delayed(const Duration(milliseconds:300));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('label-preview')),findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('print-label'))).onPressed,isNotNull);
    await tester.ensureVisible(find.byKey(const Key('print-label')));
    await tester.tap(find.byKey(const Key('print-label'))); await tester.pumpAndSettle();
    expect(p.writes.length,10); expect(p.writes[7].length,3408);
    expect(p.writes[7].any((b)=>b!=255),true);
    await tester.tap(find.text('Printere')); await tester.pumpAndSettle();
    await tester.tap(find.text('Etiket')); await tester.pumpAndSettle();
    expect(find.text('HP PROXMOX PVE1\nÆble øl å'),findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink()); await tester.pumpAndSettle(); await p.close();
  });

}
