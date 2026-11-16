import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/printer_controller.dart';
import 'i18n.dart';
import 'platform/printer_platform.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['ASK Mobile Edition'], await rootBundle.loadString('assets/licenses/Mobile-MIT.txt'));
    yield LicenseEntryWithLineBreaks(['Fyne-P21-Print / ASK Windows reference'], await rootBundle.loadString('assets/licenses/Windows-MIT.txt'));
  });
  runApp(AskMobileApp(controller: PrinterController(AndroidPrinterPlatform())));
}

class AskMobileApp extends StatefulWidget {
  const AskMobileApp({super.key, required this.controller});
  final PrinterController controller;
  @override
  State<AskMobileApp> createState() => _AskMobileAppState();
}
class _AskMobileAppState extends State<AskMobileApp> with WidgetsBindingObserver {
  PrinterController get c => widget.controller;
  @override
  void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    unawaited(c.initialize());
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) unawaited(c.setForeground(false));
    if (state == AppLifecycleState.resumed) unawaited(c.setForeground(true));
  }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: c, builder: (context, _) {
    final l = Labels(c.language);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: l.t('title'), locale: Locale(c.language), supportedLocales: const [Locale('da'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff176b70)), useMaterial3: true),
      home: DefaultTabController(length: 2, child: Scaffold(
        appBar: AppBar(title: Text(l.t('title'), style: const TextStyle(fontSize: 18)), actions: [
          DropdownButton<String>(value: c.language, underline: const SizedBox.shrink(),
            items: const [DropdownMenuItem(value: 'da', child: Text('Dansk')), DropdownMenuItem(value: 'en', child: Text('English'))],
            onChanged: (v) { if (v != null) unawaited(c.setLanguage(v)); }),
          Builder(builder: (context) => IconButton(tooltip: l.t('about'), icon: const Icon(Icons.info_outline), onPressed: () {
            showAboutDialog(context: context, applicationName: l.t('title'), applicationVersion: 'v0.0.1 experimental',
              applicationLegalese: 'MIT • ASK Mobile contributors • Tyler C (Windows reference)',
              children: [Text(l.t('experimental')), Text(l.t('credits'))]);
          })),
          const SizedBox(width: 8),
        ], bottom: TabBar(tabs: [Tab(text: l.t('printers')), Tab(text: l.t('diagnostics'))])),
        body: SafeArea(child: Column(children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(12), color: const Color(0xffffedc2),
            child: Text(l.t('experimental'), style: const TextStyle(fontWeight: FontWeight.w600))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: [
            Icon(c.connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled, color: c.connected ? Colors.teal : Colors.grey),
            const SizedBox(width: 8), Expanded(child: Text(l.t(c.status))),
          ])),
          if (c.errorCode != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(l.t(c.errorCode!), style: TextStyle(color: Theme.of(context).colorScheme.error))),
          Expanded(child: TabBarView(children: [_printers(l), _diagnostics(l)])),
        ])),
      )),
    );
  });
  Widget _printers(Labels l) {
    final opening = c.status == 'connecting' || c.status == 'reconnecting';
    final sorted = c.devices.values.toList()..sort((a,b) => a.displayName.compareTo(b.displayName));
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(l.t('slogan'), style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 12),
      Text(l.t('help')), const SizedBox(height: 8), Text(l.t('legacy'), style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton(onPressed: c.requestAccess, child: Text(l.t('access'))),
        OutlinedButton(onPressed: c.available ? c.enableBluetooth : null, child: Text(l.t('enable'))),
        OutlinedButton(onPressed: c.openSettings, child: Text(l.t('settings'))),
        FilledButton.tonal(onPressed: !c.available || c.connected || opening || c.busy ? null : c.scanning ? c.stopScan : c.scan,
          child: Text(l.t(c.scanning ? 'stopScan' : 'scan'))),
      ]),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.t('auto')), value: c.autoReconnect, onChanged: c.setAutoReconnect),
      if (c.scanning) LinearProgressIndicator(semanticsLabel: l.t('scanning')),
      if (c.selected != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('${l.t('selected')}: ${c.selected!.displayName}\n${c.selected!.address}')),
      FilledButton(onPressed: c.connected || opening ? () => c.disconnect() : c.selected != null && !c.busy && c.hasAccess && c.bluetoothEnabled ? c.connectSelected : null,
        child: Text(l.t(c.connected || opening ? 'disconnect' : 'connect'))),
      const SizedBox(height: 12),
      if (sorted.isEmpty) Text(l.t('none')),
      for (final device in sorted) Card(child: InkWell(
        onTap: c.connected || c.busy || opening ? null : () => c.selectDevice(device),
        child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(c.selected?.address == device.address ? Icons.radio_button_checked : Icons.radio_button_off),
            const SizedBox(width: 8), Expanded(child: Text(device.displayName, style: const TextStyle(fontWeight: FontWeight.w600)))]),
          Text(device.address), Text(l.t(device.paired ? 'paired' : 'notPaired')),
          Text(l.t(switch(device.type) {1 => 'classic', 2 => 'ble', 3 => 'dual', _ => 'unknownType'})),
          Text('${l.t('uuids')}: ${device.uuids.isEmpty ? l.t('unknown') : device.uuids.join(', ')}', style: const TextStyle(fontSize: 11)),
        ])),
      )),
    ]);
  }
  Widget _diagnostics(Labels l) {
    final canSend = c.connected && !c.busy;
    final entries = c.log.entries;
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.t('printHelp'), style: const TextStyle(fontSize: 12)),
        Text('${l.t('battery')}: ${c.battery == null ? l.t('unknown') : '${c.battery!.percent}% — ${l.t(c.battery!.charging ? 'charging' : 'notCharging')}'}'),
        Wrap(spacing: 8, children: [
          OutlinedButton(onPressed: canSend ? c.testBattery : null, child: Text(l.t('testBattery'))),
          OutlinedButton(onPressed: canSend ? c.cancelPause : null, child: Text(l.t('cancelPause'))),
          FilledButton(onPressed: canSend ? c.testPrint : null, child: Text(l.t('print'))),
          OutlinedButton.icon(onPressed: c.exportLog, icon: const Icon(Icons.save_alt), label: Text(l.t('export'))),
        ]),
        if (c.busy) LinearProgressIndicator(semanticsLabel: l.t('busy')),
        if (c.log.discarded > 0) Text('${l.t('discarded')}: ${c.log.discarded}'),
      ])),
      const Divider(height: 1),
      Expanded(child: entries.isEmpty ? Center(child: Text(l.t('emptyLog'))) : ListView.builder(itemCount: entries.length, itemBuilder: (context,index) {
        final e = entries[index];
        return ExpansionTile(key: ValueKey(e.id), title: Text('${e.timestamp} ${e.direction} ${e.bytes.length} B', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          subtitle: e.note.isEmpty ? null : Text(e.note, maxLines: 2, overflow: TextOverflow.ellipsis),
          children: [Padding(padding: const EdgeInsets.all(12), child: SelectableText('ASCII: ${e.asciiText}\nHEX:\n${e.hexText}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)))]);
      })),
    ]);
  }
}
