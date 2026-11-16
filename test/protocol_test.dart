import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nelko_p21_ask_mobile/core/protocol.dart';
import 'package:nelko_p21_ask_mobile/core/log.dart';

void main() {
  test('Dart reference is byte-identical to MIT Windows Go golden fixture', () {
    final parts = referencePrintParts();
    expect(parts, hasLength(9));
    expect(parts[6], hasLength(3408));
    expect(parts.expand((b) => b).toList(), orderedEquals(File('test/fixtures/windows_reference.bin').readAsBytesSync()));
    expect(ascii.decode(parts[5]), 'BITMAP 0,0,12,284,1,');
    expect(parts[6].first, 255);
    expect(parts[6], contains(0));
    expect(cancelPauseBytes, orderedEquals([0x1b,0x21,0x6f]));
    expect(sppUuid, '00001101-0000-1000-8000-00805f9b34fb');
  });
  test('battery uses explicit BCD research profile and complete framing', () {
    for (final n in [0,9,10,13,32,64,73,99]) {
      final frame = [...ascii.encode('BATTERY '), (n ~/ 10) * 16 + n % 10, 1, 13, 10];
      final reading = parseBattery([0,12,13,10,...frame]);
      expect(reading?.percent, n);
      expect(reading?.charging, true);
    }
    expect(parseBattery([...ascii.encode('BATTERY '),0xfa,0,13,10]), isNull);
    expect(parseBattery([...ascii.encode('BATTERY '),0x73,3,13,10]), isNull);
    expect(parseBattery([...ascii.encode('BATTERY '),0x73,0]), isNull);
    expect(parseBattery([...ascii.encode('BATTERY'),32,13,10]), isNull);
    expect(parseBattery(ascii.encode('73%\r\n')), isNull);
  });
  test('ASCII escaping and HEX preserve binary bytes and timestamp', () {
    final log = DiagnosticLog();
    log.add('RX', bytes: [0,13,10,27,255,92,65], at: DateTime.utc(2026,11,16));
    final entry = log.entries.single;
    expect(entry.asciiText, r'\x00\r\n\x1b\xff\\A');
    expect(entry.hexText, contains('00 0D 0A 1B FF 5C 41'));
    expect(log.export(), contains('2026-11-16T00:00:00.000Z'));
    expect(log.export(), contains('NOT CONFIRMED'));
  });
  test('log is bounded and oversized writes remain clearly marked slices', () {
    final log = DiagnosticLog(maxBytes: 2000, maxEntries: 5);
    for (var i=0;i<30;i++) { log.add('TX', bytes: List.filled(100,255)); }
    expect(log.discarded, greaterThan(0));
    expect(log.entries.length, lessThanOrEqualTo(5));
    final large = DiagnosticLog();
    large.add('TX', bytes: List.filled(5000,1));
    expect(large.entries.expand((e) => e.bytes).length, 5000);
    expect(large.entries.first.note, contains('slice'));
  });
}
