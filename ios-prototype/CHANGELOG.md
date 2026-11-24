# iOS prototype changelog

## ios-v0.0.2 — 2026-11-24

- Owner confirmed physical iPhone installation/launch; exported log confirms BLE connection and battery response (`BATTERY 99 00` in BCD framing).
- Fix deterministic seven-packet print stall: FF03 reports no longer gate paced FF02 writes or initial readiness. Retain 20-byte cap, >=12ms spacing, CoreBluetooth backpressure, serialized transactions, timeout and no replay.
- Add Swift regression replay of actual FF03 setup without replenishment through the entire Windows golden job and final PRINT; retain Apple-backpressure checks.
- Same reference printer bytes and Android/Windows printer code. Printing on physical iPhone remains unconfirmed pending owner test.

## ios-v0.0.1 — 2026-11-22

- Separate Flutter/CoreBluetooth BLE hardware-test prototype; Android remains v0.0.3.
- Danish/English diagnostics, scan/select/connect, battery, Cancel Pause and byte-exact reference print.
- Independent paced/credit-aware BLE transport and bounded ASCII/HEX UTC logging/export.
- Mac-hosted CI builds unsigned ARM64 IPA and simulator app; automatic protocol/session/flow tests.
- Installation, BLE and printing on physical iPhone **not confirmed**. No custom-text designer yet.
