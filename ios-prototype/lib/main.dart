import 'dart:async';
import 'package:flutter/material.dart';
import 'controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(IOSTestApp(controller: IOSController(NativeIOSBridge())));
}

class IOSTestApp extends StatefulWidget {
  const IOSTestApp({super.key, required this.controller});
  final IOSController controller;
  @override
  State<IOSTestApp> createState() => _State();
}

class _State extends State<IOSTestApp> with WidgetsBindingObserver {
  bool danish = true;
  IOSController get c => widget.controller;
  String t(String da, String en) => danish ? da : en;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached)
      unawaited(c.setForeground(false));
    if (state == AppLifecycleState.resumed) unawaited(c.setForeground(true));
  }

  String get status => switch (c.state) {
    'poweredOn' => t('Bluetooth er slået til', 'Bluetooth on'),
    'poweredOff' => t(
      'Slå Bluetooth til i Kontrolcenter/Indstillinger',
      'Enable Bluetooth in Control Center/Settings',
    ),
    'unauthorized' => t(
      'Bluetooth-adgang afvist; ret den i Indstillinger',
      'Bluetooth access denied; change it in Settings',
    ),
    'unsupported' => t('BLE er ikke tilgængelig', 'BLE unavailable'),
    'resetting' => t('Bluetooth nulstilles', 'Bluetooth resetting'),
    _ => t(
      'Tryk Giv Bluetooth-adgang for at starte',
      'Tap Allow Bluetooth to begin',
    ),
  };
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ASK P21 iOS Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'ASK P21 iOS Test 0.0.1',
            style: TextStyle(fontSize: 17),
          ),
          actions: [
            TextButton(
              onPressed: () => setState(() => danish = !danish),
              child: Text(danish ? 'English' : 'Dansk'),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                t(
                  'Eksperimentel BLE-test. Installation og udskrivning på iPhone er IKKE fysisk bekræftet.',
                  'Experimental BLE test. iPhone installation and printing are NOT physically confirmed.',
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(status),
              Text(
                c.connected
                    ? t(
                        'BLE-profil klar — udskrift ubekræftet',
                        'BLE profile ready — printing unconfirmed',
                      )
                    : c.connecting
                    ? t(
                        'Forbinder og undersøger GATT-profil…',
                        'Connecting and discovering GATT profile…',
                      )
                    : t('Ikke forbundet', 'Disconnected'),
              ),
              if (c.failure != null)
                SelectableText(
                  c.failure!,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 12),
              Text(
                t(
                  'Luk Android-/Windows-appen og PowerShell først. Printeren annoncerer muligvis ikke BLE, mens SPP er tilsluttet. Genstart printeren ved behov.',
                  'Close Android/Windows/PowerShell clients first. The printer may hide BLE while SPP is connected. Power-cycle the printer if needed.',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: c.requestAccess,
                    child: Text(t('Giv Bluetooth-adgang', 'Allow Bluetooth')),
                  ),
                  OutlinedButton(
                    onPressed: c.connected || c.connecting || c.busy
                        ? null
                        : c.scanning
                        ? c.stopScan
                        : c.scan,
                    child: Text(
                      c.scanning
                          ? t('Stop søgning', 'Stop search')
                          : t('Søg BLE-enheder', 'Search BLE devices'),
                    ),
                  ),
                ],
              ),
              if (c.scanning)
                Text(t('Søger i 10 sekunder…', 'Searching for 10 seconds…')),
              for (final device in c.devices.values)
                Card(
                  child: ListTile(
                    leading: Icon(
                      c.selected == device['id']
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(device['name'] as String),
                    subtitle: Text(
                      '${device['id']}\nRSSI ${device['rssi']} • ${device['services']}',
                    ),
                    onTap: c.connected || c.connecting || c.busy
                        ? null
                        : () => c.select(device['id'] as String),
                  ),
                ),
              FilledButton(
                onPressed: c.connected || c.connecting
                    ? c.disconnect
                    : c.selected != null && !c.busy
                    ? c.connect
                    : null,
                child: Text(
                  c.connected || c.connecting
                      ? t('Afbryd / annullér', 'Disconnect / cancel')
                      : t('Tilslut valgt enhed', 'Connect selected device'),
                ),
              ),
              const Divider(height: 24),
              Text(
                t(
                      'Batteri (ubekræftet BCD-fortolkning):',
                      'Battery (unverified BCD interpretation):',
                    ) +
                    ' ${c.battery?.percent.toString() ?? '?'}%',
              ),
              Text(
                t(
                  'Reference: 14×40 mm, mode 1, 3408 bitmapbytes; 500 ms efter Cancel Pause og 3 s efter PRINT.',
                  'Reference: 14×40 mm, mode 1, 3408 bitmap bytes; 500 ms after Cancel Pause and 3 s after PRINT.',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: c.connected && !c.busy ? c.testBattery : null,
                    child: Text(t('Test batteri', 'Test battery')),
                  ),
                  OutlinedButton(
                    onPressed: c.connected && !c.busy ? c.cancelPause : null,
                    child: const Text('Cancel Pause'),
                  ),
                  FilledButton(
                    onPressed: c.connected && !c.busy ? c.printReference : null,
                    child: Text(
                      t('Testprint (én etiket)', 'Test print (one label)'),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: c.busy ? null : c.export,
                    child: Text(t('Eksportér log', 'Export log')),
                  ),
                ],
              ),
              if (c.busy)
                Text(
                  t(
                    'Kommando kører — sendes aldrig automatisk igen',
                    'Command running — never automatically replayed',
                  ),
                ),
              const Divider(height: 24),
              Text(
                t(
                  'Diagnostik — tryk for ASCII/HEX',
                  'Diagnostics — tap for ASCII/HEX',
                ),
              ),
              for (final entry in c.log.entries.reversed)
                ExpansionTile(
                  key: ValueKey(entry.id),
                  title: Text(
                    '${entry.timestamp} ${entry.direction} ${entry.bytes.length} B',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  subtitle: Text(
                    entry.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  children: [
                    SelectableText(
                      'ASCII: ${entry.asciiText}\nHEX:\n${entry.hexText}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              const Text(
                'Your printer. Your labels. Your data.\nNo cloud. No account. Just print.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
