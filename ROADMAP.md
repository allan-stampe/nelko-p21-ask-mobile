# Roadmap

Your printer. Your labels. Your data.  
No cloud. No account. Just print.

## First: validate v0.0.1 on Android hardware

Record phone/Android/printer versions, pairing and discovery, SPP connection, battery response bytes, Cancel Pause, exact-reference printing, reconnect and exported diagnostics. Fix transport problems based on evidence. No claim of working Android printing until the owner confirms it.

## After transport validation

- Stable owner-controlled signing and upgrade policy.
- Label library, local templates and basic text editing; then advanced designer.
- Better media controls and printer-specific capability handling.
- BLE transport experiments using documented FF00-family services, independently validated before release.
- More Android device/permission/lifecycle testing and accessibility improvements.

## Later: iOS feasibility

Investigate CoreBluetooth BLE on physical hardware. Android Classic SPP cannot simply be ported to ordinary iOS applications; do not promise compatibility. Keep platform transport separate from shared Dart protocol/UI code.

This mobile repository remains separate from Windows. All future development keeps local Bluetooth, offline operation, local data, open source, no account, no cloud, no subscription, no ads and no telemetry.
