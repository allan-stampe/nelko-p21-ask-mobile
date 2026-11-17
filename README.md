# NELKO P21 – ASK Mobile Edition

**v0.0.2 — experimental Android text labels.** The owner confirmed v0.0.1 installed on a physical Samsung Galaxy S22: Bluetooth Classic SPP works and two reference test prints succeeded. Custom text printing in v0.0.2 still needs physical validation.

Your printer. Your labels. Your data.  
No cloud. No account. Just print.

## Install

Download the universal APK from [v0.0.2 releases](https://github.com/allan-stampe/nelko-p21-ask-mobile/releases/tag/v0.0.2), verify SHA256SUMS.txt and install directly (Android 8/API 26+, no Play Store required).

**Upgrade notice:** these experimental CI builds use temporary Android test signing keys. v0.0.2 is not signed with the unavailable private key from the v0.0.1 runner. Uninstall v0.0.1 before installing v0.0.2 if Android rejects the update. Uninstalling deletes saved language/printer/reconnect settings; export any needed logs first and select the printer again. A stable owner-controlled production signing identity remains future work. The public signer fingerprint accompanies each release.

## Print your own text

1. Close other clients including Windows/PowerShell. Enable Bluetooth, grant access, search/select the correct printer and connect in **Printers / Printere**.
2. Open **Label / Etiket** and enter one or more lines, for example:

   ```text
   HP PROXMOX PVE1
   192.168.1.2
   ```

3. Select 12, 16, 20, 24, 28 or 32 printer dots and left/center/right alignment. Automatic wrapping is enabled. The bundled Go Regular font supports Danish æ, ø, å and uppercase variants, without downloading fonts.
4. Inspect the monochrome landscape preview. It is reconstructed from the exact bitmap to be sent. If text overflows, reduce font size or shorten it; printing is disabled rather than silently truncating a label.
5. Use **Print label (one copy) / Udskriv etiket (ét eksemplar)**. It sends one captured bitmap. Wait until the command has settled; failed/interrupted jobs are never replayed automatically.

Reference media remains **14 × 40 mm**, density 15, gap 5 mm; the tested 96×284 bitmap geometry is preserved. Preview is not physical scale on the screen. Small text readability, orientation, margins and Danish glyphs need a real v0.0.2 print test. See [text printing details](docs/TEXT-PRINTING-v0.0.2.md).

The existing **Diagnostics** tab retains battery query, Cancel Pause, original reference test print, and timestamped ASCII/HEX logs with local export. Danish/English UI, paired-device selection, foreground reconnect and local preferences remain. BLE and iOS are future work. There is no advanced designer/library in this version.

## Local and offline

No cloud, account, ads, subscription, telemetry or runtime Internet permission. Settings use private SharedPreferences with cloud/device-transfer backup disabled. Label text stays in memory during the app session (including tab switches); v0.0.2 does not save a label library or restore text after process termination. Logs are bounded in memory until local export and can contain printer identifiers and bitmap data. Review before sharing. Foreground reconnect remembers the chosen device; backgrounding closes transport and cancels work without print replay.

## Build and checks

Flutter **3.38.5**, Java 17, Android SDK. Dependency/tool downloads need Internet during development; normal app use does not.

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

GitHub Actions checks tests/lint, the merged APK permissions, signing, and fresh APK installation/start on Android 12/API 31 and Android 16/API 36 x86_64 emulators before publishing a tag prerelease. Physical Bluetooth/printing cannot be certified by those emulators. Standard Gradle infrastructure is committed; the bootstrap can restore missing generated files.

See [protocol](docs/PROTOCOL.md), [hardware checklist](docs/HARDWARE-TEST.md), [decisions](docs/DECISIONS.md), [roadmap](ROADMAP.md), [changelog](CHANGELOG.md) and [credits](THIRD_PARTY_NOTICES.md). Windows v1.0.1 is read-only and unchanged. Original MIT developer Tyler C's license and bundled font BSD license are retained in source, distribution and app licenses.

The earlier [v0.0.1 installation investigation](docs/INSTALLATION-AUDIT-v0.0.1.md) is historical: the owner now confirms successful installation, but the original generic refusal's cause was never established.
