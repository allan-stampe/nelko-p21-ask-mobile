# Physical Android test — pending

**No Android hardware success is claimed.** Windows v1.0.1's 12 successful labels are reference evidence only.

Record APK SHA256/certificate, phone model, Android version, printer/firmware identification if available, media, locale, date, battery state and each result below. Do not include private addresses in public reports unless intended.

1. Disconnect Windows/PowerShell and other printer apps. Turn on printer and Bluetooth.
2. Install APK, inspect requested permissions. Try permission denial then grant, discovery, paired devices and selecting the correct address. If legacy discovery is empty, check the phone's location-service requirement.
3. Connect/pair. Record exact error or connected state. Do not equate a socket connection with printing success.
4. Query battery; record raw ASCII/HEX frame and whether the displayed BCD percentage/charging state is credible. Unknown is a valid diagnostic outcome.
5. Send Cancel Pause; record any raw reply (possibly 16 bytes without CRLF).
6. Load suitable 14 × 40 mm stock with the reference gap. Request exactly one test print; wait at least three seconds. Record paper motion, output orientation/polarity/cropping and attach a photo separately if useful.
7. Power cycle printer and observe foreground reconnect to the same selection; verify no print replay. Test explicit disconnect, Bluetooth off/on, background/resume and permission revocation.
8. Restart app and confirm saved printer, language and auto-reconnect setting. Switch Danish/English.
9. Export log locally with Bluetooth disconnected; verify timestamps, ASCII and HEX. Review identifiers before sharing.

Report successes and failures independently. If printing fails, do not change several protocol parameters at once. Compare the exact Windows reference, connection transport and raw replies first. The test image is deliberately 284 rows; alternate geometry/BLE experiments belong in a later controlled change.
