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

## ASK iOS Edition — confirmed reference printing

The owner confirmed physical reference printing with iOS 0.0.2 on iPhone 11 Pro / reported iOS 27.2.1 and NELKO P21 on 2026-11-24. Version 0.0.3 updates name/status while preserving that working transport. See the [iOS guide](ios-prototype/README.md) and [hardware evidence](ios-prototype/HARDWARE-2026-11-24.md). Next: custom-text labels and preview, followed by device testing. Confirmation is specific to the tested combination. iOS CoreBluetooth BLE remains separate from Android Classic SPP and shared Dart protocol code.

This mobile repository remains separate from Windows. All future development keeps local Bluetooth, offline operation, local data, open source, no account, no cloud, no subscription, no ads and no telemetry.
