import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nelko_p21_ask_mobile/core/printer_controller.dart';
import 'package:nelko_p21_ask_mobile/core/protocol.dart';
import 'package:nelko_p21_ask_mobile/platform/printer_platform.dart';
import 'fake_platform.dart';

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition() && DateTime.now().isBefore(deadline)) { await Future<void>.delayed(const Duration(milliseconds: 2)); }
  expect(condition(), true, reason: 'async controller event timed out');
}
void main() {
  late FakePlatform p;
  late PrinterController c;
  setUp(() { p=FakePlatform(); c=PrinterController(p, sleep: (_) async {}, reconnectDelay: const Duration(milliseconds: 10)); });
  tearDown(() async { c.dispose(); await p.close(); });
  Future<void> connect() async { await c.initialize(); c.selectDevice(printerA); await c.connectSelected(); expect(c.connected, true); }

  test('search combines bonded and discovered devices after permission', () async {
    p.access=false; await c.initialize(); await c.scan();
    expect(c.status,'permission'); expect(p.discoveryStarts,0);
    await c.requestAccess(); await c.scan(); expect(p.discoveryStarts,1);
    const found=PrinterDevice(address:'AA:BB:CC:DD:EE:03',name:'P21 C',type:1);
    p.stream.add({'type':'device','device':found.toMap()});
    p.stream.add({'type':'discoveryFinished'});
    await until(() => c.devices.length==3 && !c.scanning);
    expect(c.devices[printerA.address]?.paired,true);
  });
  test('no unsolicited battery or print data on connect', () async {
    await connect(); expect(p.opened,[printerA.address]); expect(p.writes,isEmpty);
  });
  test('reference writes exactly match desktop golden with both quiet periods', () async {
    final waits=<Duration>[]; final counts=<int>[];
    c.dispose(); c=PrinterController(p,sleep:(d)async{waits.add(d);counts.add(p.writes.length);});
    await connect(); await c.testPrint();
    expect(waits,[cancelPauseDelay,printSettleDelay]); expect(counts,[1,10]);
    expect(p.writes.expand((b)=>b).toList(),orderedEquals([...cancelPauseBytes,...File('test/fixtures/windows_reference.bin').readAsBytesSync()]));
    expect(c.log.export(),contains('hardware output NOT confirmed'));
  });
  test('custom text bitmap is snapshotted, serialized and sent with reference timing', () async {
    final entered=Completer<void>(); final release=Completer<void>(); final waits=<Duration>[];
    c.dispose(); c=PrinterController(p,sleep:(d)async{waits.add(d);if(d==cancelPauseDelay){entered.complete();await release.future;}});
    await connect();
    final bitmap=Uint8List(3408)..fillRange(0,3408,255); bitmap[0]=0x7f;
    final printing=c.printLabel(bitmap); await entered.future;
    bitmap.fillRange(0,3408,0);
    await c.testPrint(); expect(p.writes.length,1);
    release.complete(); await printing;
    expect(waits,[cancelPauseDelay,printSettleDelay]); expect(p.writes.length,10);
    expect(p.writes[7][0],0x7f); expect(p.writes[7][1],255);
    expect(String.fromCharCodes(p.writes[6]),'BITMAP 0,0,12,284,1,');
    expect(String.fromCharCodes(p.writes[9]),'PRINT 1\r\n');
  });
  test('Cancel Pause alone sends no CRLF and waits 500 ms', () async {
    final waits=<Duration>[]; c.dispose(); c=PrinterController(p,sleep:(d)async{waits.add(d);});
    await connect(); await c.cancelPause();
    expect(p.writes.single,orderedEquals(cancelPauseBytes)); expect(waits,[cancelPauseDelay]);
  });
  test('battery handles fragmented replies without trimming binary whitespace', () async {
    await connect(); p.batteryReply=[...ascii.encode('BATTERY '),0x09,1,13,10];
    await c.testBattery(); expect(c.battery?.percent,9); expect(c.battery?.charging,true);
    expect(c.log.entries.where((e)=>e.direction=='RX').length,2);
    expect(String.fromCharCodes(p.writes.single),'BATTERY?\r\n');
  });
  test('unknown battery does not close the printer or fabricate zero percent', () async {
    await connect(); await c.testBattery(); expect(c.battery,isNull); expect(c.connected,true);
    expect(c.log.export(),contains('Unknown battery reply'));
  });
  test('short writes complete the complete reference stream once', () async {
    await connect(); p.maxWrite=5; await c.testPrint();
    expect(p.writes.expand((e)=>e).toList(),orderedEquals([...cancelPauseBytes,...File('test/fixtures/windows_reference.bin').readAsBytesSync()]));
  });
  test('battery cannot interleave with print quiet periods', () async {
    final entered=Completer<void>(); final release=Completer<void>();
    c.dispose(); c=PrinterController(p,sleep:(d)async{if(d==cancelPauseDelay){entered.complete();await release.future;}});
    await connect(); final printing=c.testPrint(); await entered.future;
    await c.testBattery(); expect(p.writes.length,1);
    release.complete(); await printing; expect(p.writes.length,10);
    expect(p.writes.any((e)=>String.fromCharCodes(e)=='BATTERY?\r\n'),false);
  });
  test('late connect completion cannot revive a manual disconnect', () async {
    await c.initialize(); c.selectDevice(printerA); p.connectGate=Completer<void>();
    final connecting=c.connectSelected(); await until(()=>p.opened.isNotEmpty);
    await c.disconnect(); p.connectGate!.complete(); await connecting;
    expect(c.connected,false); expect(c.status,'disconnected');
  });
  test('connection failure reconnects to same device and never replays print', () async {
    p.failConnects=1; await c.initialize(); c.selectDevice(printerA); await c.connectSelected();
    await until(()=>c.connected); expect(p.opened,[printerA.address,printerA.address]);
    expect(p.writes,isEmpty);
    p.failWrite=2; await c.testPrint();
    await until(()=>c.connected); expect(p.writes.length,1); // Only Cancel Pause succeeded.
    expect(c.log.export(),contains('no replay'));
    await c.disconnect(); final count=p.opened.length;
    await Future<void>.delayed(const Duration(milliseconds:40)); expect(p.opened.length,count);
  });
  test('background cancels print before headers and reconnects only on resume', () async {
    final entered=Completer<void>(); final release=Completer<void>();
    c.dispose(); c=PrinterController(p,reconnectDelay:const Duration(milliseconds:10),sleep:(d)async{if(d==cancelPauseDelay){entered.complete();await release.future;}});
    await connect(); final printing=c.testPrint(); await entered.future;
    await c.setForeground(false); release.complete(); await printing;
    expect(c.status,'paused'); expect(p.writes.length,1);
    await Future<void>.delayed(const Duration(milliseconds:30)); expect(p.opened.length,1);
    await c.setForeground(true); await until(()=>c.connected);
    expect(p.opened.length,2); expect(p.writes.length,1);
  });
  test('language, selected device and reconnect preference survive fresh controller', () async {
    await connect(); await c.setLanguage('en'); await c.disconnect();
    final other=FakePlatform()..preferences=Map.from(p.preferences);
    final restarted=PrinterController(other,sleep:(_)async{});
    await restarted.initialize(); expect(restarted.language,'en'); expect(restarted.connected,true);
    expect(other.opened,[printerA.address]); expect(other.writes,isEmpty);
    await restarted.setAutoReconnect(false); restarted.dispose();
    final manual=FakePlatform()..preferences=Map.from(other.preferences);
    final fresh=PrinterController(manual); await fresh.initialize();
    expect(manual.opened,isEmpty); expect(fresh.selected?.address,printerA.address);
    fresh.dispose(); await other.close(); await manual.close();
  });
  test('BLE-only devices are not misrepresented as SPP connections', () async {
    await c.initialize(); c.selectDevice(const PrinterDevice(address:'AA:BB:CC:DD:EE:04',type:2));
    await c.connectSelected(); expect(c.errorCode,'ble_unsupported'); expect(p.opened,isEmpty);
  });
  test('log export is available without a Bluetooth connection', () async {
    await c.initialize(); await c.exportLog();
    expect(p.exported,contains('v0.0.2')); expect(p.exported,contains('NOT CONFIRMED'));
    expect(c.connected,false);
  });
}
