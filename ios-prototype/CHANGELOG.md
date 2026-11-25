# ASK iOS Edition changelog

## ios-v0.0.3 — 2026-11-25

- Name: **NELKO P21 – ASK iOS Edition v0.0.3**, including iOS display name, window title and exported diagnostics.
- Replace obsolete experimental/unconfirmed-print warnings with the owner's confirmed 0.0.2 reference-print status. Early edition; no custom text or designer yet.
- Document physical success on iPhone 11 Pro / reported iOS 27.2.1: 181 FF02 TX packets / 3,513 bytes match Cancel Pause + Windows golden fixture, followed by owner-confirmed paper output.
- Preserve all 0.0.2 Bluetooth/FF02 pacing, flow control, cancellation, bitmap, TSPL bytes and timing. Same bundle ID, existing app icon, offline behavior, diagnostics, MIT/upstream credits; Android and Windows printer code untouched.
- Distribute a normal GitHub release with unsigned ARM64 IPA; external Apple signing/renewal still required. Confirmation is for the tested device/printer combination, not every iPhone/firmware or every future job.

## ios-v0.0.2 — 2026-11-24

- Owner confirmed physical iPhone installation/launch; exported log confirms BLE connection and battery response (`BATTERY 99 00` in BCD framing).
- Fix deterministic seven-packet print stall: FF03 reports no longer gate paced FF02 writes or initial readiness. Retain 20-byte cap, >=12ms spacing, CoreBluetooth backpressure, serialized transactions, timeout and no replay.
- Add Swift regression replay of actual FF03 setup without replenishment through the entire Windows golden job and final PRINT; retain Apple-backpressure checks.
- Same reference printer bytes and Android/Windows printer code. Initially pending owner test; later confirmed successful on 2026-11-24 (see hardware evidence).

## ios-v0.0.1 — 2026-11-22

- Separate Flutter/CoreBluetooth BLE hardware-test prototype; Android remains v0.0.3.
- Danish/English diagnostics, scan/select/connect, battery, Cancel Pause and byte-exact reference print.
- Independent paced/credit-aware BLE transport and bounded ASCII/HEX UTC logging/export.
- Mac-hosted CI builds unsigned ARM64 IPA and simulator app; automatic protocol/session/flow tests.
- Installation, BLE and printing on physical iPhone **not confirmed**. No custom-text designer yet.
