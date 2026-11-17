# Printer protocol and evidence

## Evidence boundaries

The owner confirmed Windows v1.0.1 on Windows 11 through COM4, 115200 baud, 8N1, and reports 12 successful labels. The earlier COM5 experiment used the sequence below. Selecting the correct COM port resolved the last desktop issue; no individual command difference has been proven to be the fix. Android uses RFCOMM, not a selectable Windows COM port or UART baud rate. The owner has now confirmed v0.0.1 SPP connection and two reference prints on a physical Samsung Galaxy S22. New v0.0.2 text raster output remains **unconfirmed**; see [text pipeline](TEXT-PRINTING-v0.0.2.md).

## Byte-exact Windows reference

Send raw bytes `1B 21 6F` (historically named Cancel Pause), wait **500 ms**, then send the following parts in order:

```text
SIZE 14.0 mm,40.0 mm\r\n
GAP 5.0 mm,0 mm\r\n
DIRECTION 0,0\r\n
DENSITY 15\r\n
CLS\r\n
BITMAP 0,0,12,284,1,<3408 binary bytes>\r\n
PRINT 1\r\n
```

There is no line ending between the BITMAP header and its binary payload. Width is 12 bytes = 96 dots, height 284 rows, bitmap mode 1. The reference image starts with FF bytes and clears bits for a frame and three bars. After PRINT wait **3 seconds**. Do not change mode, row count, polarity or spacing while establishing the baseline. Transmissions are serialized; failures are not replayed. API write success is not printer acknowledgement.

The Go-generated golden fixture `test/fixtures/windows_reference.bin` tests the entire Dart print stream excluding Cancel Pause (tested separately). SHA256: `6fc19a63c63198e7f7777269c402a7b754a64dec2c950f6294faecccb61a3d3e`. Source: Windows tag v1.0.1, commit `cf5a10edca679193467b37f80e9b14871e883584`, `internal/tspl/diagnostic.go` and `tspl.go` (MIT). Timing is tested separately.

## Transports and UUIDs

Android v0.0.1 implements Bluetooth Classic RFCOMM via the standard Serial Port Profile UUID `00001101-0000-1000-8000-00805f9b34fb`. SDP/OS selects the channel; upstream describes channel 1. Cached advertised UUIDs are shown for diagnostics and can be empty. A vendor AF30 EIR UUID is an upstream observation, not a substitute SPP connection UUID.

Upstream reports BLE service `0000ff00-0000-1000-8000-00805f9b34fb`, FF02 write-without-response and FF01 notification characteristics; FF04 alternate write, FF03 credits, FF05 indications and FF10 read/write are also described. These UUIDs use the same Bluetooth base suffix. Upstream reports BLE visibility depends on no Classic link being active, and describes MTU/pacing/credit constraints. These are research observations, not verified characteristics of the owner's printer. **BLE is not implemented here.**

## Battery and receive data

Send `BATTERY?\r\n`, collect raw incoming chunks for three seconds, retaining ASCII and HEX regardless of interpretation. The experimental parser expects `BATTERY ` + one BCD percentage byte + one charging byte (0 or 1) + CRLF. Thus 0x42 means 42%, not decimal 66; 0x99 means 99%. Invalid BCD, missing framing or unknown replies produce an unknown reading, not a fabricated percentage. Fragmented and coalesced frames are tested. This profile comes from upstream observations and needs hardware confirmation.

Upstream also reports `1B 21 6F` can return a raw 16-byte label/NFC record without CRLF. The application logs it without treating it as an acknowledgement or inventing a line protocol. All receive data is asynchronous; queries must not overwrite the raw diagnostics.

## Sources reviewed

- [ASK Windows v1.0.1](https://github.com/allan-stampe/nelko-p21-ask-edition/tree/v1.0.1) — working hardware baseline, MIT adaptation.
- [nelko-p21-print research snapshot](https://github.com/merlinschumacher/nelko-p21-print/tree/92c0786af004ff59cdd1cbc4053709ed4ad2e3ca) — README/protocol observations, AGPL-3.0; no code copied or translated.
- [nelko-p21-rs research snapshot](https://github.com/julienvincent/nelko-p21-rs/tree/49a619169620287f90195fa85d036af39dc2ae73) — MIT protocol/transport research, no code copied.
- [NelkoP21WebPrint research snapshot](https://github.com/spelech/NelkoP21WebPrint/tree/eb920ab92552c6be1477c1b85f326147a9913c19) — research only; no code copied or assumed license.
- [Android RFCOMM](https://developer.android.com/develop/connectivity/bluetooth/connect-bluetooth-devices), [discovery](https://developer.android.com/develop/connectivity/bluetooth/find-bluetooth-devices), [permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions).
