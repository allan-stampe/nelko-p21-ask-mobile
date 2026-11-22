import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ask_p21_ios_test/controller.dart';
import 'package:ask_p21_ios_test/main.dart';
import 'package:nelko_p21_ask_mobile/core/protocol.dart';

class FakeBridge implements IOSBridge {
  final stream = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final calls = <String>[];
  final writes = <List<int>>[];
  Completer<void>? gate;
  int? shortCount;
  bool batteryReply = false;
  @override
  Stream<Map<String, dynamic>> get events => stream.stream;
  @override
  Future<T?> invoke<T>(String method, [Object? arguments]) async {
    calls.add(method);
    if (method == 'connect' && gate != null) await gate!.future;
    if (method == 'write') {
      final bytes = ((arguments as Map)['bytes'] as Uint8List).toList();
      writes.add(bytes);
      if (batteryReply) {
        stream.add({
          'type': 'rx',
          'bytes': [1, 7],
          'characteristic': 'FF03',
          'epoch': 1,
        });
        stream.add({
          'type': 'rx',
          'bytes': [66, 65, 84, 84, 69, 82, 89, 32],
          'characteristic': 'FF01',
          'epoch': 1,
        });
        stream.add({
          'type': 'rx',
          'bytes': [0x79, 0, 13, 10],
          'characteristic': 'FF01',
          'epoch': 1,
        });
      }
      return (shortCount ?? bytes.length) as T;
    }
    if (method == 'export') return true as T;
    return null;
  }
}

void main() {
  late FakeBridge b;
  late IOSController c;
  late List<Duration> waits;
  setUp(() {
    b = FakeBridge();
    waits = [];
    c = IOSController(
      b,
      sleep: (d) async {
        waits.add(d);
      },
    );
    c.initialize();
  });
  tearDown(() async {
    c.dispose();
    await b.stream.close();
  });
  Future<void> connect() async {
    c.select('printer');
    await c.connect();
  }

  test('initialization does not request Bluetooth or send data', () {
    expect(b.calls, isEmpty);
    expect(c.connected, isFalse);
  });
  test(
    'reference bytes match Windows fixture exactly, with required waits',
    () async {
      await connect();
      await c.printReference();
      expect(b.writes.first, [0x1b, 0x21, 0x6f]);
      expect(
        b.writes.skip(1).expand((x) => x).toList(),
        File('../test/fixtures/windows_reference.bin').readAsBytesSync(),
      );
      expect(waits, [cancelPauseDelay, printSettleDelay]);
      expect(b.writes.length, 10);
      expect(
        c.log.entries.where((e) => e.direction == 'TX'),
        isEmpty,
      ); // Native packets only.
    },
  );
  test('disconnected actions never write', () async {
    await c.cancelPause();
    await c.printReference();
    await c.testBattery();
    expect(b.writes, isEmpty);
  });
  test('Cancel Pause stays binary without a line ending', () async {
    await connect();
    await c.cancelPause();
    expect(b.writes, [
      [27, 33, 111],
    ]);
    expect(waits, [cancelPauseDelay]);
  });
  test('fragmented battery only uses FF01, not FF03', () async {
    await connect();
    b.batteryReply = true;
    await c.testBattery();
    expect(c.battery?.percent, 79);
    expect(c.battery?.charging, false);
    expect(waits, [batteryReplyWindow]);
  });
  test('unknown partial write disconnects without retry', () async {
    await connect();
    b.shortCount = 1;
    await c.printReference();
    expect(b.writes.length, 1);
    expect(c.connected, false);
    expect(b.calls.where((s) => s == 'disconnect').length, 1);
  });
  test('late connect completion cannot revive closed session', () async {
    b.gate = Completer();
    c.select('printer');
    final f = c.connect();
    await c.disconnect();
    b.gate!.complete();
    await f;
    expect(c.connected, false);
  });
  test(
    'background during pause cancels rest of print and no replay on resume',
    () async {
      c.dispose();
      final pause = Completer<void>();
      c = IOSController(b, sleep: (_) => pause.future);
      c.initialize();
      await connect();
      final f = c.printReference();
      await Future<void>.delayed(Duration.zero);
      await c.setForeground(false);
      pause.complete();
      await f;
      await c.setForeground(true);
      expect(b.writes.length, 1);
      expect(c.connected, false);
    },
  );
  test('transactions exclude concurrent print/cancel', () async {
    c.dispose();
    final pause = Completer<void>();
    c = IOSController(b, sleep: (_) => pause.future);
    c.initialize();
    await connect();
    final f = c.cancelPause();
    await c.printReference();
    await c.testBattery();
    pause.complete();
    await f;
    expect(b.writes.length, 1);
  });
  test('native TX packet is exported with timestamp ASCII and HEX', () async {
    b.stream.add({
      'type': 'tx',
      'bytes': [27, 33, 111, 13, 10],
      'characteristic': 'FF02',
      'epoch': 1,
    });
    expect(c.exportText(), contains(r'\x1b!o\r\n'));
    expect(c.exportText(), contains('1B 21 6F 0D 0A'));
    expect(c.exportText(), contains('FF02'));
    await c.export();
    expect(b.calls, ['export']);
  });
  testWidgets(
    'Danish/English diagnostic screen starts without Bluetooth access',
    (tester) async {
      // This app owns and disposes this separate controller.
      final bridge = FakeBridge();
      final controller = IOSController(bridge);
      await tester.pumpWidget(IOSTestApp(controller: controller));
      expect(find.text('Giv Bluetooth-adgang'), findsOneWidget);
      expect(bridge.calls, isEmpty);
      await tester.tap(find.text('English'));
      await tester.pump();
      expect(find.text('Allow Bluetooth'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await bridge.stream.close();
    },
  );
}
