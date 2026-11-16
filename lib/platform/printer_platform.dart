import 'dart:typed_data';
import 'package:flutter/services.dart';

class PrinterDevice {
  const PrinterDevice({required this.address, this.name = '', this.paired = false, this.type = 0, this.uuids = const []});
  final String address;
  final String name;
  final bool paired;
  final int type;
  final List<String> uuids;
  String get displayName => name.isEmpty ? address : name;
  bool get classicPossible => type != 2;
  Map<String, Object> toMap() => {'address': address, 'name': name, 'paired': paired, 'type': type, 'uuids': uuids};
  factory PrinterDevice.fromMap(Map<dynamic, dynamic> map) => PrinterDevice(
      address: map['address'] as String? ?? '', name: map['name'] as String? ?? '',
      paired: map['paired'] == true, type: (map['type'] as num?)?.toInt() ?? 0,
      uuids: (map['uuids'] as List? ?? []).cast<String>());
}

abstract class PrinterPlatform {
  Stream<Map<String, dynamic>> get events;
  Future<Map<String, dynamic>> loadPreferences();
  Future<void> savePreferences(Map<String, Object?> values);
  Future<Map<String, dynamic>> state();
  Future<bool> requestAccess();
  Future<void> enableBluetooth();
  Future<void> openBluetoothSettings();
  Future<List<PrinterDevice>> bondedDevices();
  Future<void> startDiscovery();
  Future<void> stopDiscovery();
  Future<void> connect(String address, int epoch);
  Future<void> disconnect();
  Future<int> write(Uint8List bytes, int epoch);
  Future<bool> exportLog(String text, String name);
}

class AndroidPrinterPlatform implements PrinterPlatform {
  static const _methods = MethodChannel('dk.ask.nelko_p21_ask_mobile/bluetooth');
  @override
  final events = const EventChannel('dk.ask.nelko_p21_ask_mobile/events')
      .receiveBroadcastStream().map((e) => Map<String, dynamic>.from(e as Map));
  Future<void> _void(String method, [Object? arguments]) => _methods.invokeMethod<void>(method, arguments);
  @override
  Future<Map<String, dynamic>> loadPreferences() async => Map<String, dynamic>.from(await _methods.invokeMapMethod('loadPreferences') ?? {});
  @override
  Future<void> savePreferences(Map<String, Object?> values) => _void('savePreferences', values);
  @override
  Future<Map<String, dynamic>> state() async => Map<String, dynamic>.from(await _methods.invokeMapMethod('state') ?? {});
  @override
  Future<bool> requestAccess() async => await _methods.invokeMethod<bool>('requestAccess') ?? false;
  @override
  Future<void> enableBluetooth() => _void('enableBluetooth');
  @override
  Future<void> openBluetoothSettings() => _void('openBluetoothSettings');
  @override
  Future<List<PrinterDevice>> bondedDevices() async => (await _methods.invokeListMethod('bondedDevices') ?? [])
      .map((e) => PrinterDevice.fromMap(e as Map)).toList();
  @override
  Future<void> startDiscovery() => _void('startDiscovery');
  @override
  Future<void> stopDiscovery() => _void('stopDiscovery');
  @override
  Future<void> connect(String address, int epoch) => _void('connect', {'address': address, 'epoch': epoch});
  @override
  Future<void> disconnect() => _void('disconnect');
  @override
  Future<int> write(Uint8List bytes, int epoch) async => await _methods.invokeMethod<int>('write', {'bytes': bytes, 'epoch': epoch}) ?? 0;
  @override
  Future<bool> exportLog(String text, String name) async => await _methods.invokeMethod<bool>('exportLog', {'text': text, 'name': name}) ?? false;
}
