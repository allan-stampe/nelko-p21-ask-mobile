# Changelog

## 0.0.2 — experimental

- Owner confirmed v0.0.1 installation, Bluetooth Classic SPP and two test prints on physical Samsung Galaxy S22; the original installation refusal's cause remains unknown.
- Add custom multiline text, six font sizes, left/center/right alignment and automatic wrapping.
- Rasterize with bundled offline Go Regular font, including Danish glyphs; preview the exact 1-bit bitmap and rotate like Windows ASK Edition.
- Add clear one-copy printing, overflow prevention and immutable in-flight bitmap snapshots.
- Preserve existing Kotlin/SPP transport, reference test print, diagnostics and offline/privacy behavior.
- Add layout/bitmap/protocol/widget tests and gate releases on fresh Android 12/16 emulator installation/start.
- Include the v0.0.1 APK audit and its historical evidence.
- VersionCode 2; temporary CI signer differs from v0.0.1, so upgrades can require uninstalling (saved preferences are lost).

Custom text output still requires physical v0.0.2 validation. Fixed reference media 14×40 mm, session-only text; no advanced designer/library yet.

## 0.0.1 — experimental

- New standalone Flutter/Dart Android project; no changes to the Windows repository.
- Native Android Bluetooth Classic SPP discovery, pairing handoff, selected-device connection and foreground reconnection.
- Local preferences, Danish/English interface and visible connection state.
- Experimental battery query, raw Cancel Pause and byte-exact Windows-reference test print with matching timing.
- Bounded timestamped ASCII/HEX diagnostics and local file export.
- Android permission/backup privacy checks, protocol/controller/widget tests and CI APK/lint/release workflow.
- MIT license and attribution preserved. BLE and iOS remain future work.

**Physical Android validation is pending.** The owner reports 12 successful labels using Windows v1.0.1; Android is a different, unverified transport.
