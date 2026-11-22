# iOS BLE protocol and technical decisions

**Candidate profile only; no iOS hardware confirmation.** Windows/Android success is specific to Classic SPP. iOS CoreBluetooth uses BLE GATT; generic SPP is not exposed to ordinary iOS apps.

## Sources and provenance

- Canonical shared MIT implementation: [`../lib/core/protocol.dart`](../lib/core/protocol.dart), Windows ASK v1.0.1 reference, originally Tyler C / Fyne-P21-Print. Source unchanged by this prototype. Golden fixture `../test/fixtures/windows_reference.bin`, SHA256 `6fc19a63c63198e7f7777269c402a7b754a64dec2c950f6294faecccb61a3d3e`.
- [merlinschumacher/nelko-p21-print pinned research](https://github.com/merlinschumacher/nelko-p21-print/tree/92c0786af004ff59cdd1cbc4053709ed4ad2e3ca), especially BLE observations in README. AGPL-3.0: **protocol facts researched only, no implementation copied or translated**. Swift flow control/transport independently authored here.
- [Apple CoreBluetooth data transfer](https://developer.apple.com/documentation/corebluetooth/transferring-data-between-bluetooth-low-energy-devices): characteristic discovery, notification subscription, `maximumWriteValueLength`, `canSendWriteWithoutResponse` and readiness callback.
- [Sideloadly FAQ](https://sideloadly.io/faq) for installation constraints; signing is outside the printer app.

## Candidate GATT mapping

Short UUIDs expand using Bluetooth base `0000xxxx-0000-1000-8000-00805F9B34FB`.

| UUID | Expected role | Prototype behavior |
|---|---|---|
| FF00 | Service | Required after unfiltered BLE discovery |
| FF02 | Commands, write without response | Required; never substitutes unrelated writable UUID |
| FF01 | Printer replies, notify | Required and subscribed before ready |
| FF03 | Flow-control notifications | Subscribe when present; require an initial valid credit frame before ready |
| FF05 | Indications / status | Subscribe when notify/indicate is available; log raw bytes |
| FF04 | Alternate command channel reported upstream | Not used |
| FF10 | Other read/write channel reported upstream | Not used |

Discovery logs all discovered service UUIDs and FF00 characteristic properties. BLE may be unavailable while Classic is connected. Device identity is an iOS peripheral UUID; no MAC/COM assumptions. No automatic pairing settings, reconnect, background mode or command replay.

## Independently implemented flow control

FF03 `01 NN` adds NN **packet** credits; `02 LL LL` advertises payload size (little endian). Reject malformed/unknown frames; preserve them in HEX log. No fabricated initial credits. If FF03 is present but never supplies credits, connection times out after 20 seconds. When FF03 is absent, use paced-only mode. This is a conservative research-based policy, not a validated firmware guarantee.

Writes are capped at the minimum of **20 bytes**, advertised payload, CoreBluetooth maximum and remaining bytes. At least **12 ms** separates write calls, including across command boundaries. CoreBluetooth readiness and FF03 credits must both permit each packet. Never interleave user transactions. A write has a 12-second timeout; disconnect/background/errors abort it without replay, since partial physical delivery is unknowable. Cancellation fences prevent old disconnect callbacks reviving or closing a new session. No acknowledgement is invented: TX means native API accepted a packet.

FF01 replies are accumulated in a bounded 4096-byte window for the battery command. FF03/FF05 data are logged separately and cannot be misread as battery. Existing shared battery parser expects ASCII `BATTERY ` + BCD percent + charging byte 0/1 + CRLF; unsupported replies remain unknown. Binary whitespace is not trimmed. Physical interpretation requires confirmation.

## Byte-exact reference job

1. Raw Cancel Pause `1B 21 6F` (no CRLF).
2. Wait **500 ms**.
3. `SIZE 14.0 mm,40.0 mm` + CRLF.
4. `GAP 5.0 mm,0 mm` + CRLF.
5. `DIRECTION 0,0` + CRLF.
6. `DENSITY 15` + CRLF.
7. `CLS` + CRLF.
8. `BITMAP 0,0,12,284,1,` **immediately followed by 3408 binary bytes**.
9. CRLF, then `PRINT 1` + CRLF.
10. Wait **3 seconds**. Do not automatically resend.

Bitmap width 96 dots / 12 bytes per row, height 284 dots, mode 1. Shared reference generator and golden fixture are reused; transport fragmentation must not insert any extra bytes or line endings. UART baud/8N1/COM4 settings apply to Windows SPP, not iOS BLE.

## Privacy, packaging and platform boundaries

No network API, app account, telemetry, advertising, purchases, cloud entitlement or background BLE mode. iOS has no Android-style Internet permission to remove. Apple signing/renewal needs an external account/network tool; the slogan refers to local printer use. System share sheet may offer cloud targets only on explicit user selection; choose On My iPhone for local export. No private Apple credentials in repository/Actions.

Minimum iOS 15; Xcode 26.2 / Flutter 3.38.5; unsigned ARM64 AOT device IPA, no JIT/paid entitlements. Stock placeholder icon. CI simulator install/start verifies launch only, not physical signing or BLE. Local sideload signing changes the final signature/bundle metadata as required by Apple's provisioning; the published artifact intentionally carries no distribution certificate. Android code and Windows repository are not modified.
