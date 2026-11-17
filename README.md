# NELKO P21 – ASK Mobile Edition

**v0.0.1 — experimental Android hardware-test build. Android Bluetooth and printing have NOT been confirmed on physical hardware.**

Your printer. Your labels. Your data.  
No cloud. No account. Just print.

A separate Flutter/Dart project, Android first. The working [Windows edition](https://github.com/allan-stampe/nelko-p21-ask-edition) remains unchanged. Its v1.0.1 Windows 11 / COM4 test has produced 12 labels according to the owner; that result does not validate this Android transport.

## Install and test

Download the APK from [experimental releases](https://github.com/allan-stampe/nelko-p21-ask-mobile/releases/tag/v0.0.1), check SHA256SUMS.txt, and permit installation from your chosen browser/file manager in Android settings. Android 8.0 (API 26) or newer is required. No Play Store is needed. This is a test-key-signed release APK, not a production signing identity. CI runners generate temporary test keys: later builds can require uninstalling the previous app, which deletes its preferences. Export needed logs first. The release includes the public certificate fingerprint.

1. Close the Windows app/PowerShell connection. A printer may accept only one connection.
2. Enable Bluetooth, grant requested Nearby devices permissions (older Android requires location permission for discovery), search, and select the correct printer. Android handles pairing.
3. Connect. A connected socket is not proof of printer compatibility.
4. Try battery query, Cancel Pause, then one reference test print with suitable 14 × 40 mm media. Do not repeatedly queue prints.
5. Export the diagnostics and follow [the hardware test checklist](docs/HARDWARE-TEST.md).

The interface supports Danish and English. It provides Classic SPP discovery, paired-device selection, foreground reconnect to the selected device, connection status, experimental battery parsing, Cancel Pause, the Windows-reference print, and UTC ASCII/HEX diagnostics export. BLE-only devices are displayed but cannot connect in v0.0.1. There is no advanced label designer yet.

## Privacy and operation

No cloud, account, advertisements, subscription, telemetry, or runtime Internet permission. Normal operation is local and offline. Preferences (language, selected Bluetooth address/name, reconnect setting) use private Android SharedPreferences; backup and device-transfer backup are disabled. Logs are bounded in memory until exported with Android's local-only document picker. Logs can contain printer addresses and payload data: review before sharing. No location is collected; legacy Android requires its permission for Bluetooth discovery. Reconnect runs while the app is foregrounded; backgrounding closes the socket and cancels work. Failed print jobs are never replayed automatically.

## Build and checks

Use Flutter **3.38.5**, Java 17 and Android SDK tools. First setup/build needs Internet access for development dependencies; the installed application does not.

```sh
flutter config --no-analytics
tool/bootstrap_android.sh
flutter pub get
flutter analyze --fatal-infos
flutter test --coverage
python3 tool/check_privacy.py
flutter build apk --release --no-pub
(cd android && ./gradlew lintRelease)
```

Standard Android/Gradle infrastructure is committed. If missing, the bootstrap generates it using the pinned Flutter SDK, preserving the authored manifest and native transport. GitHub Actions performs these checks, inspects the merged APK permissions, verifies signing, and produces an installable universal APK, ZIP and checksum. A successful `v0.0.1` tag build publishes a prerelease. Unit tests use fake transports; they cannot certify Bluetooth hardware.

See [protocol](docs/PROTOCOL.md), [technical decisions](docs/DECISIONS.md), [roadmap](ROADMAP.md), [changelog](CHANGELOG.md) and [credits](THIRD_PARTY_NOTICES.md). MIT licensed; original Windows developer Tyler C's license is preserved in the repository and application's license screen.

## Installation investigation: Galaxy S22

The unchanged v0.0.1 APK passed signature, manifest, ABI/alignment and integrity checks, and fresh installation/launch on Android 12 and Android 16 x86_64 emulators. The reported Samsung One UI 8 installation refusal is **not yet explained**. See the [evidence report](docs/INSTALLATION-AUDIT-v0.0.1.md) and [Windows/ADB diagnostic steps](docs/S22-INSTALL-DIAGNOSTICS.md). No replacement APK has been issued without an identified cause.
