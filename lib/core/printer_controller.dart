import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../platform/printer_platform.dart';
import 'log.dart';
import 'protocol.dart';

class _Cancelled implements Exception {}

class PrinterController extends ChangeNotifier {
  PrinterController(this.platform, {Future<void> Function(Duration)? sleep,
    this.reconnectDelay = const Duration(seconds: 5), this.connectTimeout = const Duration(seconds: 20)})
      : _sleep = sleep ?? Future<void>.delayed;
  final PrinterPlatform platform;
  final Future<void> Function(Duration) _sleep;
  final Duration reconnectDelay;
  final Duration connectTimeout;
  final log = DiagnosticLog();
  final Map<String, PrinterDevice> devices = {};
  String language = 'da';
  String status = 'idle';
  String? errorCode;
  PrinterDevice? selected;
  BatteryReading? battery;
  bool autoReconnect = true;
  bool connected = false;
  bool scanning = false;
  bool busy = false;
  bool hasAccess = false;
  bool bluetoothEnabled = false;
  bool available = true;
  bool foreground = true;
  int androidSdk = 0;
  int _epoch = 0;
  int? _openingToken;
  bool _wantConnection = false;
  bool _disposed = false;
  Timer? _retry;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  BytesBuilder? _batteryBytes;

  void _notify() { if (!_disposed) notifyListeners(); }
  void _record(String direction, {List<int> bytes = const [], String note = ''}) {
    log.add(direction, bytes: bytes, note: note); _notify();
  }
  String _code(Object e) => e is PlatformException ? e.code : e is MissingPluginException ? 'unsupported' : e is TimeoutException ? 'timeout' : 'io';
  Future<void> initialize() async {
    try {
      final p = await platform.loadPreferences();
      if (_disposed) return;
      language = p['language'] == 'en' ? 'en' : 'da';
      autoReconnect = p['autoReconnect'] != false;
      if ((p['address'] as String? ?? '').isNotEmpty) {
        selected = PrinterDevice(address: p['address'] as String, name: p['name'] as String? ?? '');
        devices[selected!.address] = selected!;
      }
      _wantConnection = autoReconnect && selected != null;
      _subscription = platform.events.listen(_onEvent, onError: (Object e) {
        _record('ERROR', note: 'Native event stream: $e');
        _lost(_code(e));
      });
      await refreshState();
      _record('INFO', note: 'v0.0.2 experimental; SPP/reference print confirmed by owner on S22; custom text NOT hardware-confirmed; API $androidSdk; SPP $sppUuid');
      if (hasAccess && available && bluetoothEnabled) {
        await loadBonded();
        if (_wantConnection) await connectSelected();
      }
    } catch (e) {
      errorCode = _code(e); status = errorCode == 'unsupported' ? 'unsupported' : 'error';
      _record('ERROR', note: 'Initialize: $e');
    }
    _notify();
  }
  Future<void> _save() => platform.savePreferences({
    'language': language, 'autoReconnect': autoReconnect,
    'address': selected?.address ?? '', 'name': selected?.name ?? '',
  });
  Future<void> setLanguage(String value) async {
    language = value == 'en' ? 'en' : 'da'; _notify();
    try { await _save(); } catch (e) { _record('ERROR', note: 'Save language: $e'); }
  }
  Future<void> setAutoReconnect(bool value) async {
    autoReconnect = value;
    if (!value) { _retry?.cancel(); if (!connected && _openingToken == null) status = 'disconnected'; }
    try { await _save(); } catch (e) { _record('ERROR', note: 'Save reconnect setting: $e'); }
    if (value && !connected && _wantConnection) _scheduleReconnect();
    _notify();
  }
  Future<void> refreshState() async {
    final s = await platform.state();
    if (_disposed) return;
    available = s['available'] == true;
    hasAccess = s['access'] == true;
    bluetoothEnabled = s['enabled'] == true;
    androidSdk = (s['sdk'] as num?)?.toInt() ?? 0;
    if (!available) { status = 'unsupported'; }
    else if (!hasAccess) { status = 'permission'; }
    else if (!bluetoothEnabled) { status = 'bluetoothOff'; }
    else if (!connected && status != 'connecting' && status != 'reconnecting') { status = 'idle'; }
    _notify();
  }
  Future<void> requestAccess() async {
    try {
      hasAccess = await platform.requestAccess();
      await refreshState();
      if (hasAccess && bluetoothEnabled) {
        await loadBonded();
        if (_wantConnection && !connected) _scheduleReconnect();
      }
    } catch (e) { errorCode = _code(e); _record('ERROR', note: 'Permission: $e'); }
  }
  Future<void> enableBluetooth() async {
    try { await platform.enableBluetooth(); } catch (e) { _record('ERROR', note: 'Enable Bluetooth: $e'); }
  }
  Future<void> openSettings() async {
    try { await platform.openBluetoothSettings(); } catch (e) { _record('ERROR', note: 'Bluetooth settings: $e'); }
  }
  Future<void> loadBonded() async {
    final list = await platform.bondedDevices();
    for (final device in list) { devices[device.address] = device; }
    _notify();
  }
  Future<void> scan() async {
    if (busy || connected || status == 'connecting' || status == 'reconnecting') return;
    try {
      await refreshState();
      if (!available || !hasAccess || !bluetoothEnabled) return;
      await loadBonded();
      scanning = true; _notify();
      await platform.startDiscovery();
      _record('INFO', note: 'Classic discovery started; not a BLE GATT scan');
    } catch (e) {
      scanning = false; errorCode = _code(e); _record('ERROR', note: 'Discovery: $e');
    }
  }
  Future<void> stopScan() async {
    try { await platform.stopDiscovery(); } catch (e) { _record('ERROR', note: 'Stop discovery: $e'); }
    scanning = false; _notify();
  }
  void selectDevice(PrinterDevice device) {
    if (connected || busy || status == 'connecting' || status == 'reconnecting') return;
    selected = device; errorCode = null; _notify();
  }
  Future<void> connectSelected({bool retry = false}) async {
    final target = selected;
    if (target == null || _disposed || !foreground) return;
    if (busy || _openingToken != null) { if (retry) _scheduleReconnect(); return; }
    if (!target.classicPossible) { errorCode = 'ble_unsupported'; _notify(); return; }
    _retry?.cancel();
    _wantConnection = true;
    final token = ++_epoch;
    _openingToken = token;
    connected = false; battery = null; errorCode = null;
    status = retry ? 'reconnecting' : 'connecting'; _notify();
    try {
      await _save();
      await platform.stopDiscovery(); scanning = false;
      await platform.disconnect();
      if (token != _epoch || _disposed || !foreground) return;
      _record('INFO', note: 'Open RFCOMM ${target.address}; service UUID $sppUuid; cached UUIDs ${target.uuids}');
      await platform.connect(target.address, token).timeout(connectTimeout);
      if (token != _epoch || _disposed || !foreground) return;
      connected = true; status = 'connected';
      _record('INFO', note: 'Socket open, NOT proof of physical printing: ${target.address}');
    } catch (e) {
      if (token != _epoch || _disposed) return;
      _record('ERROR', note: 'Connect ${target.address}: $e');
      await _lost(_code(e));
    } finally { if (_openingToken == token) _openingToken = null; }
    _notify();
  }
  Future<void> disconnect({bool manual = true}) async {
    if (manual) _wantConnection = false;
    ++_epoch; _openingToken = null; _retry?.cancel(); _batteryBytes = null;
    connected = false; scanning = false; battery = null;
    status = foreground ? 'disconnected' : 'paused'; _notify();
    try { await platform.stopDiscovery(); await platform.disconnect(); }
    catch (e) { _record('ERROR', note: 'Close: $e'); }
    _record('INFO', note: manual ? 'Manual disconnect; no reconnect in this session' : 'Foreground session suspended');
  }
  Future<void> _lost(String code) async {
    ++_epoch; _openingToken = null;
    if (code == 'permission_denied') hasAccess = false;
    if (code == 'ble_unsupported' || code == 'invalid_argument' || code == 'unsupported') _wantConnection = false;
    if (code == 'bluetooth_off') bluetoothEnabled = false;
    connected = false; scanning = false; battery = null; errorCode = code; status = code == 'bluetooth_off' ? 'bluetoothOff' : code == 'permission_denied' ? 'permission' : 'disconnected';
    try { await platform.disconnect(); } catch (e) { _record('ERROR', note: 'Close failed connection: $e'); }
    _scheduleReconnect(); _notify();
  }
  void _scheduleReconnect() {
    _retry?.cancel();
    if (_disposed || connected || _openingToken != null || !foreground || !_wantConnection || !autoReconnect || selected == null || !hasAccess || !bluetoothEnabled) return;
    status = 'reconnecting'; _notify();
    _retry = Timer(reconnectDelay, () { if (!_disposed && foreground) unawaited(connectSelected(retry: true)); });
  }
  Future<void> setForeground(bool value) async {
    if (foreground == value || _disposed) return;
    foreground = value;
    if (!value) { await disconnect(manual: false); }
    else {
      try { await refreshState(); if (_wantConnection && autoReconnect) _scheduleReconnect(); }
      catch (e) { _record('ERROR', note: 'Resume: $e'); }
    }
  }
  void _onEvent(Map<String, dynamic> e) {
    if (_disposed) return;
    switch (e['type']) {
      case 'device':
        final device = PrinterDevice.fromMap(e['device'] as Map);
        if (device.address.isNotEmpty) devices[device.address] = device;
      case 'discoveryFinished': scanning = false;
      case 'adapter':
        bluetoothEnabled = e['enabled'] == true;
        if (!bluetoothEnabled) { unawaited(_lost('bluetooth_off')); }
        else if (_wantConnection && autoReconnect) { _scheduleReconnect(); }
      case 'rx':
        final data = (e['bytes'] as List).cast<int>();
        _record('RX', bytes: data, note: '${e['address']} session ${e['epoch']}');
        if (e['epoch'] == _epoch && _batteryBytes != null) {
          final room = 4096 - _batteryBytes!.length;
          if (room > 0) _batteryBytes!.add(data.take(room).toList());
        }
      case 'disconnected':
        _record('INFO', note: 'Socket closed: ${e['reason']} session ${e['epoch']}');
        if (e['epoch'] == _epoch) unawaited(_lost('connection_lost'));
      case 'error': _record('ERROR', note: '${e['message']}');
    }
    _notify();
  }
  void _ensureActive(int token) {
    if (_disposed || !foreground || !connected || token != _epoch) throw _Cancelled();
  }
  Future<void> _write(Uint8List data, int token) async {
    var offset = 0;
    while (offset < data.length) {
      _ensureActive(token);
      final remaining = Uint8List.sublistView(data, offset);
      final n = await platform.write(remaining, token).timeout(const Duration(seconds: 8));
      if (n <= 0 || n > remaining.length) throw StateError('Invalid write count $n');
      _record('TX', bytes: remaining.sublist(0, n), note: '${selected?.address} session $token');
      offset += n;
    }
  }
  Future<void> _action(String name, Future<void> Function(int) perform) async {
    if (busy || !connected || _disposed || !foreground) return;
    busy = true; final token = _epoch; _notify();
    _record('INFO', note: '$name started');
    try {
      await perform(token); _ensureActive(token);
      _record('INFO', note: '$name completed at API level; hardware output NOT confirmed');
    } on _Cancelled { _record('INFO', note: '$name cancelled; never automatically replayed'); }
    catch (e) {
      _record('ERROR', note: '$name: $e; partial delivery may be unknown; no replay');
      if (token == _epoch) await _lost(_code(e));
    } finally { busy = false; _notify(); }
  }
  Future<void> cancelPause() => _action('Cancel Pause', (token) async {
    await _write(cancelPauseBytes, token);
    _record('WAIT', note: '500 ms after Cancel Pause'); await _sleep(cancelPauseDelay);
  });
  Future<void> testPrint() => _action('Reference print', (token) async {
    await _write(cancelPauseBytes, token);
    _record('WAIT', note: '500 ms after Cancel Pause'); await _sleep(cancelPauseDelay);
    for (final part in referencePrintParts()) { await _write(part, token); }
    _record('WAIT', note: '3 seconds after PRINT'); await _sleep(printSettleDelay);
  });
  void recordLayoutError(Object error) => _record('ERROR', note: 'Text rasterization: $error');
  Future<void> printLabel(Uint8List bitmap) {
    final parts = bitmapPrintParts(bitmap); // Snapshot before any await/UI edit.
    return _action('Text label print', (token) async {
      await _write(cancelPauseBytes, token);
      _record('WAIT', note: '500 ms after Cancel Pause'); await _sleep(cancelPauseDelay);
      for (final part in parts) { await _write(part, token); }
      _record('WAIT', note: '3 seconds after PRINT'); await _sleep(printSettleDelay);
    });
  }
  Future<void> testBattery() => _action('Battery query', (token) async {
    final buffer = BytesBuilder(copy: true); _batteryBytes = buffer;
    try {
      await _write(batteryCommand, token); await _sleep(batteryReplyWindow); _ensureActive(token);
      battery = parseBattery(buffer.toBytes());
      _record('INFO', note: battery == null ? 'Unknown battery reply; inspect raw RX' : 'BCD interpretation: ${battery!.percent}%, charging=${battery!.charging}; not hardware-confirmed');
    } finally { if (identical(_batteryBytes, buffer)) _batteryBytes = null; }
  });
  Future<void> exportLog() async {
    try {
      final name = 'NELKO-P21-ASK-Mobile-v0.0.2-${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.log';
      final saved = await platform.exportLog(log.export(), name);
      _record('INFO', note: saved ? 'Log exported through local-only Android document picker' : 'Log export cancelled');
    } catch (e) { _record('ERROR', note: 'Log export: $e'); }
  }
  @override
  void dispose() {
    _disposed = true; ++_epoch; _retry?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(() async { try { await platform.stopDiscovery(); await platform.disconnect(); } catch (_) {} }());
    super.dispose();
  }
}
