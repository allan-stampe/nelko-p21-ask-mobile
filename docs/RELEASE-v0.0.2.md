Experimental Android text-label release, based on the physically confirmed v0.0.1 Bluetooth Classic SPP connection and two test prints on Samsung Galaxy S22.

Adds multiline custom text, six font sizes, left/center/right alignment, automatic wrapping, exact monochrome bitmap preview and a clear one-copy print button. Includes bundled offline Go Regular font with Danish æøåÆØÅ support. The original diagnostics test print, battery query, Cancel Pause, ASCII/HEX logs, export and Danish/English UI remain.

**Custom text printing in v0.0.2 still needs physical printer validation.** Use fixed 14×40 mm reference media. Start with `HP PROXMOX PVE1` and `192.168.1.2` on separate lines at 20 dots, then compare alignment, orientation, margins and Danish glyphs. Overflow disables printing. See docs/TEXT-PRINTING-v0.0.2.md in the repository/ZIP.

**Installation/upgrade:** Android 8+; download APK directly, no Play Store. These CI test keys differ from v0.0.1: uninstall the old app before installing v0.0.2 if the update is rejected. Uninstalling deletes preferences; export needed logs and reconnect/select the printer again. APK-CERTIFICATE.txt identifies this release's public signer; SHA256SUMS.txt verifies the APK. This remains a test signing identity.

No cloud, account, ads, subscription, telemetry or runtime Internet permission. All data stays local. Windows project unchanged; original MIT credits and Go font license retained.

Your printer. Your labels. Your data.
No cloud. No account. Just print.
