# Changelog

## Unreleased — installation investigation

- Audit the unchanged public v0.0.1 APK with Android signing, manifest, ZIP/ELF/alignment checks.
- Add reproducible fresh-install/launch CI tests on Android 12/API 31 and Android 16/API 36.
- Record passing emulator evidence and Samsung Galaxy S22/One UI 8 diagnostic instructions.
- No runtime/Bluetooth changes or replacement release; the device-specific refusal remains unexplained pending its installation error code.

## 0.0.1 — experimental

- New standalone Flutter/Dart Android project; no changes to the Windows repository.
- Native Android Bluetooth Classic SPP discovery, pairing handoff, selected-device connection and foreground reconnection.
- Local preferences, Danish/English interface and visible connection state.
- Experimental battery query, raw Cancel Pause and byte-exact Windows-reference test print with matching timing.
- Bounded timestamped ASCII/HEX diagnostics and local file export.
- Android permission/backup privacy checks, protocol/controller/widget tests and CI APK/lint/release workflow.
- MIT license and attribution preserved. BLE and iOS remain future work.

**Physical Android validation is pending.** The owner reports 12 successful labels using Windows v1.0.1; Android is a different, unverified transport.
