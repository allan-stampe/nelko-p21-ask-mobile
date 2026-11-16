import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:nelko_p21_ask_mobile/platform/printer_platform.dart';

const printerA = PrinterDevice(address: 'AA:BB:CC:DD:EE:01', name: 'P21 A', paired: true, type: 1);
const printerB = PrinterDevice(address: 'AA:BB:CC:DD:EE:02', name: 'P21 B', paired: true, type: 1);

class FakePlatform implements PrinterPlatform {
  final stream = StreamController<Map<String, dynamic>>.broadcast();
  @override
  Stream<Map<String, dynamic>> get events => stream.stream;
  Map<String, dynamic> preferences = {};
  List<PrinterDevice> bonded = [printerA, printerB];
  final writes = <Uint8List>[];
  final opened = <String>[];
  bool access = true;
  bool enabled = true;
  int discoveryStarts = 0;
  int epoch = 0;
  int failConnects = 0;
  int? failWrite;
  int? maxWrite;
  Completer<void>? connectGate;
  List<int>? batteryReply;
  String? exported;
  @override
  Future<Map<String, dynamic>> loadPreferences() async => Map.from(preferences);
  @override
  Future<void> savePreferences(Map<String, Object?> values) async { preferences = Map.from(values); }
  @override
  Future<Map<String, dynamic>> state() async => {'available': true, 'access': access, 'enabled': enabled, 'sdk': 35};
  @override
  Future<bool> requestAccess() async { access = true; return true; }
  @override
  Future<void> enableBluetooth() async { enabled = true; stream.add({'type': 'adapter', 'enabled': true}); }
  @override
  Future<void> openBluetoothSettings() async {}
  @override
  Future<List<PrinterDevice>> bondedDevices() async => bonded;
  @override
  Future<void> startDiscovery() async { discoveryStarts++; }
  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<void> connect(String address, int token) async {
    opened.add(address); epoch = token;
    if (failConnects > 0) { failConnects--; throw PlatformException(code: 'connect_failed'); }
    if (connectGate != null) await connectGate!.future;
  }
  @override
  Future<void> disconnect() async {}
  @override
  Future<int> write(Uint8List bytes, int token) async {
    if (failWrite == writes.length + 1) throw PlatformException(code: 'io');
    final n = maxWrite != null && maxWrite! < bytes.length ? maxWrite! : bytes.length;
    writes.add(Uint8List.fromList(bytes.take(n).toList()));
    if (batteryReply != null && String.fromCharCodes(bytes) == 'BATTERY?\r\n') {
      final reply = batteryReply!;
      stream.add({'type': 'rx', 'bytes': reply.sublist(0, 4), 'epoch': token, 'address': printerA.address});
      stream.add({'type': 'rx', 'bytes': reply.sublist(4), 'epoch': token, 'address': printerA.address});
    }
    return n;
  }
  @override
  Future<bool> exportLog(String text, String name) async { exported = text; return true; }
  Future<void> close() => stream.close();
}
