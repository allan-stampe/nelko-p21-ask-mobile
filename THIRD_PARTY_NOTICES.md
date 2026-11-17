# Credits and licenses

## Adapted code

The byte-exact reference bitmap and TSPL sequence are adapted from [allan-stampe/nelko-p21-ask-edition v1.0.1](https://github.com/allan-stampe/nelko-p21-ask-edition/tree/v1.0.1), derived from [TylerCode/Fyne-P21-Print](https://github.com/TylerCode/Fyne-P21-Print). Original MIT copyright: **Copyright (c) 2026 Tyler C**. The original full license is preserved in `assets/licenses/Windows-MIT.txt`, registered in the app license screen, alongside the mobile MIT license. The golden test fixture was generated from that Go reference, not from a Python implementation.

## Research only — no source copied or translated

- [merlinschumacher/nelko-p21-print](https://github.com/merlinschumacher/nelko-p21-print): AGPL-3.0. Consulted for independently implemented protocol facts, BCD battery framing, BLE service observations and transport behavior. Its code is not incorporated in this MIT app.
- [julienvincent/nelko-p21-rs](https://github.com/julienvincent/nelko-p21-rs): MIT, Copyright (c) 2026 Julien Vincent. Protocol/transport research; no code incorporated.
- [spelech/NelkoP21WebPrint](https://github.com/spelech/NelkoP21WebPrint): documentation research; no root license assumed, no code incorporated.
- Android platform Bluetooth documentation informs the independently written Kotlin adapter. Flutter SDK supplies framework, localization and standard Android build scaffolding; Flutter is BSD-3-Clause. Framework/transitive dependency licenses are available via the app's About → licenses view.

Pinned research commits and technical evidence are documented in `docs/PROTOCOL.md`. No affiliation with or endorsement by NELKO is implied.

## Bundled Go Regular font

`assets/fonts/Go-Regular.ttf` is the unmodified Go Regular font from `golang.org/x/image` v0.15.0, also used by the Windows reference. Copyright (c) 2016 Bigelow & Holmes Inc. The complete BSD license is preserved in `assets/licenses/Go-Fonts.txt`, the app license registry and release ZIP (`GO-FONTS-LICENSE.txt`).
