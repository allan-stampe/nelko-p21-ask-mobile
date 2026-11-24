# Roadmap

Your printer. Your labels. Your data.  
No cloud. No account. Just print.

## Confirmed baseline and next physical milestone

The owner confirmed v0.0.1 installed on Samsung Galaxy S22, SPP connection works and two reference prints succeeded. v0.0.2 adds simple text labels; physically validate its orientation, margins, typography and Danish glyphs next. Battery parsing and reconnect scenarios also need separate evidence.

## After transport validation

- Stable owner-controlled signing and upgrade policy.
- Label library, persisted text and local templates; then advanced designer (basic text editing is now implemented in v0.0.2).
- Better media controls and printer-specific capability handling.
- BLE transport experiments using documented FF00-family services, independently validated before release.
- More Android device/permission/lifecycle testing and accessibility improvements.

## iOS feasibility — experimental prototype

An isolated [iOS BLE prototype](ios-prototype/README.md) is available for initial installation and hardware tests. Owner confirmed physical iPhone installation/launch; the 2026-11-24 log confirms BLE and a battery reply. Printing remains unconfirmed; iOS 0.0.2 fixes an observed seven-packet software stall. Investigate CoreBluetooth BLE on physical hardware. Android Classic SPP cannot simply be ported to ordinary iOS applications; do not promise compatibility. Keep platform transport separate from shared Dart protocol/UI code.

This mobile repository remains separate from Windows. All future development keeps local Bluetooth, offline operation, local data, open source, no account, no cloud, no subscription, no ads and no telemetry.
