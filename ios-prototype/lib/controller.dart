import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nelko_p21_ask_mobile/core/log.dart';
import 'package:nelko_p21_ask_mobile/core/protocol.dart';

abstract class IOSBridge {
  Stream<Map<String,dynamic>> get events;
  Future<T?> invoke<T>(String method,[Object? arguments]);
}
class NativeIOSBridge implements IOSBridge {
  static const _methods=MethodChannel('dk.ask.p21.ios/methods');
  @override
  Stream<Map<String,dynamic>> get events=>const EventChannel('dk.ask.p21.ios/events').receiveBroadcastStream().map((e)=>Map<String,dynamic>.from(e as Map));
  @override
  Future<T?> invoke<T>(String method,[Object? arguments])=>_methods.invokeMethod<T>(method,arguments);
}
class IOSController extends ChangeNotifier {
  IOSController(this.bridge,{Future<void> Function(Duration)? sleep}):_sleep=sleep??Future<void>.delayed;
  final IOSBridge bridge;
  final Future<void> Function(Duration) _sleep;
  final log=DiagnosticLog();
  final Map<String,Map<String,dynamic>> devices={};
  StreamSubscription<Map<String,dynamic>>? _subscription;
  String state='unknown';
  String? selected;
  String? failure;
  bool scanning=false,connecting=false,connected=false,busy=false,foreground=true;
  BatteryReading? battery;
  bool _disposed=false;
  int _generation=0;
  BytesBuilder? _battery;
  void _notify(){if(!_disposed)notifyListeners();}
  void note(String text){log.add('INFO',note:text);_notify();}
  void initialize(){
    _subscription=bridge.events.listen(_event,onError:(Object e){failure='$e';_lost();note('Event stream error: $e');});
    note('ASK iOS BLE Test 0.0.1; FF00/FF02/FF01 candidate profile. iOS installation, BLE and printing NOT physically confirmed.');
  }
  void _lost(){++_generation;connected=false;connecting=false;scanning=false;battery=null;_battery=null;}
  void _event(Map<String,dynamic> e){
    if(_disposed)return;
    switch(e['type']){
      case 'state':state=e['state'] as String? ?? 'unknown';
      case 'device':devices[e['id'] as String]=e;
      case 'scanDone':scanning=false;
      case 'note':note(e['message'] as String);
      case 'closed':failure=e['reason'] as String?;_lost();note('BLE closed: ${e['reason']}; no automatic replay');
      case 'tx':log.add('TX',bytes:(e['bytes'] as List).cast<int>(),note:'${e['characteristic']} session ${e['epoch']}; CoreBluetooth API acceptance only');
      case 'rx':
        final bytes=(e['bytes'] as List).cast<int>();
        log.add('RX',bytes:bytes,note:'${e['characteristic']} session ${e['epoch']}');
        final uuid=e['characteristic'].toString().toUpperCase();
        if(connected && _battery!=null && (uuid=='FF01'||uuid=='0000FF01-0000-1000-8000-00805F9B34FB')){
          final room=4096-_battery!.length;if(room>0)_battery!.add(bytes.take(room).toList());
        }
    }
    _notify();
  }
  Future<void> _simple(String method)async{
    try{await bridge.invoke<void>(method);}catch(e){failure='$e';log.add('ERROR',note:'$method: $e');}_notify();
  }
  Future<void> requestAccess()=>_simple('access');
  Future<void> scan()async{if(connected||connecting||busy||!foreground)return;devices.clear();failure=null;scanning=true;_notify();await _simple('scan');if(failure!=null){scanning=false;_notify();}}
  Future<void> stopScan()async{await _simple('stopScan');scanning=false;_notify();}
  void select(String id){if(!connected&&!connecting&&!busy){selected=id;failure=null;_notify();}}
  Future<void> connect()async{
    if(selected==null||connected||connecting||busy||!foreground||_disposed)return;
    final token=++_generation;connecting=true;failure=null;scanning=false;_notify();
    try{await bridge.invoke<void>('connect',{'id':selected});
      if(token==_generation&&!_disposed&&foreground){connected=true;note('BLE profile ready; NOT proof of printing');}
    }catch(e){if(token==_generation){failure='$e';log.add('ERROR',note:'Connect: $e');}}
    finally{if(token==_generation)connecting=false;_notify();}
  }
  Future<void> disconnect()async{_lost();await _simple('disconnect');}
  Future<void> setForeground(bool value)async{foreground=value;if(!value)await disconnect();_notify();}
  void _active(int token){if(_disposed||!foreground||!connected||token!=_generation)throw StateError('Session cancelled');}
  Future<void> _write(Uint8List bytes,int token)async{
    _active(token);
    final n=await bridge.invoke<int>('write',{'bytes':bytes});
    _active(token);if(n!=bytes.length)throw StateError('Unknown/partial write count $n; never replayed');
  }
  Future<void> _action(String label,Future<void> Function(int) action)async{
    if(!connected||busy||!foreground||_disposed)return;
    busy=true;failure=null;final token=_generation;note('$label started');
    try{await action(token);_active(token);note('$label API complete; physical output NOT confirmed');}
    catch(e){
      log.add('ERROR',note:'$label: $e; no replay');
      if(token==_generation){failure='$e';await disconnect();}
    }finally{busy=false;_battery=null;_notify();}
  }
  Future<void> cancelPause()=>_action('Cancel Pause',(t)async{await _write(cancelPauseBytes,t);log.add('WAIT',note:'500 ms');await _sleep(cancelPauseDelay);});
  Future<void> printReference()=>_action('Reference print',(t)async{
    await _write(cancelPauseBytes,t);log.add('WAIT',note:'500 ms');await _sleep(cancelPauseDelay);
    for(final part in referencePrintParts()){await _write(part,t);}
    log.add('WAIT',note:'3 seconds');await _sleep(printSettleDelay);
  });
  Future<void> testBattery()=>_action('Battery',(t)async{
    final data=BytesBuilder(copy:true);_battery=data;
    await _write(batteryCommand,t);await _sleep(batteryReplyWindow);_active(t);
    battery=parseBattery(data.toBytes());note(battery==null?'Unknown battery reply; inspect FF01 RX':'BCD candidate: ${battery!.percent}%, charging=${battery!.charging}; not hardware-confirmed');
  });
  String exportText()=> 'NELKO P21 – ASK iOS BLE Test 0.0.1\n'
      'Physical iOS installation/BLE/printing NOT CONFIRMED. UTC timestamps.\n'
      'TX = packet accepted by CoreBluetooth, not a printer acknowledgement.\n'
      'FF03/FF05 RX are logged as binary, not battery replies. Identifiers/data may be sensitive.\n'
      'Discarded older records: ${log.discarded}\n\n${log.entries.map((e)=>e.text).join('\n')}';
  Future<void> export()async{
    if(busy)return;
    try{final done=await bridge.invoke<bool>('export',{'text':exportText()});note(done==true?'Log shared/saved by user':'Export cancelled');}
    catch(e){failure='$e';log.add('ERROR',note:'Export: $e');_notify();}
  }
  Future<void> _closeQuietly()async{try{await bridge.invoke<void>('disconnect');}catch(_){/* Best-effort teardown; no replay. */}}
  @override
  void dispose(){_disposed=true;++_generation;unawaited(_subscription?.cancel());unawaited(_closeQuietly());super.dispose();}
}
