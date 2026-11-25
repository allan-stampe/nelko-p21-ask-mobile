**NELKO P21 – ASK iOS Edition v0.0.3**

Renames the app and replaces outdated experimental/unconfirmed-print messages following the owner's successful physical reference print with 0.0.2 on an iPhone 11 Pro / reported iOS 27.2.1 and NELKO P21. The successful BLE transport, paced FF02 writes, printer protocol and bitmap are unchanged. Android and Windows printer code are unchanged. Same bundle ID, so install over the existing iOS app using the same Apple account and Sideloadly settings.

This is an early edition with reference printing, BLE discovery/connection, battery reply, Cancel Pause, Danish/English UI and ASCII/HEX diagnostics/export. Custom label text and a designer are future features. Hardware confirmation applies to the tested combination; each future job's API completion is not an automatic acknowledgement of paper output.

The **unsigned IPA** requires local Apple signing via [Sideloadly](https://sideloadly.io/) on Windows. A free Apple account normally needs seven-day renewal. This is not App Store/TestFlight distribution. Follow [the installation guide](https://github.com/allan-stampe/nelko-p21-ask-mobile/blob/ios-v0.0.3/ios-prototype/README.md).

[Hardware evidence](https://github.com/allan-stampe/nelko-p21-ask-mobile/blob/ios-v0.0.3/ios-prototype/HARDWARE-2026-11-24.md): 181 logged TX packets / 3,513 bytes match Cancel Pause plus the entire Windows golden stream, through final PRINT. The owner confirmed the actual printed label. No private UUID/raw personal log is published.

Offline app use: no cloud, app account, subscriptions, ads or telemetry. Apple installation/signing requires an external account/network tool. MIT, original Tyler C attribution and bundled font licenses retained. App icon unchanged.

Your printer. Your labels. Your data.  
No cloud. No account. Just print.
