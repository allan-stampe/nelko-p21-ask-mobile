# Text labels — v0.0.2

## Evidence and scope

Owner-confirmed baseline: v0.0.1 installed on Samsung Galaxy S22, SPP connection works, two test prints succeeded. The observed pattern was three vertical strokes. That confirms the reference transport/print path, not the new text path. No claim is made that v0.0.2 custom text has been physically tested.

This version adds a simple multiline editor, six sizes in **printer dots**, left/center/right alignment, wrapping, a monochrome preview and a one-copy print button. It retains the original diagnostic test, battery query and raw logs. Fixed reference media only; no designer, image import, multiple fonts or saved label library yet. Text remains in session memory, including tab switches, and is not restored after process termination.

## Windows reference reviewed without modification

Read-only Windows v1.0.1, commit `cf5a10edca679193467b37f80e9b14871e883584`:

- `internal/label/render.go`: white 284×96 landscape canvas, clockwise rotation into 96×284 printer raster.
- `internal/label/text.go`: font rasterization, line metrics and wrapping. Desktop uses typographic points at 203 DPI; mobile deliberately exposes printer dots to avoid ambiguous scaling.
- `internal/fonts/fonts.go`: bundled Go font family.
- `internal/imaging/imaging.go` and `cmd/nelko-print/main.go`: luminance threshold and MSB-first packing, with normal-print polarity inversion.
- `internal/tspl/tspl.go` and `diagnostic.go`: exact binary BITMAP framing, mode 1 and reference dimensions.

No Windows source, settings, tests or Bluetooth code is changed. The mobile Kotlin transport is unchanged from the physically confirmed v0.0.1.

## Rendering and protocol

Flutter loads the local, unmodified **Go Regular** TTF from golang.org/x/image v0.15.0. Its Bigelow & Holmes BSD license is bundled and registered in the app license view. There is no font download or dependency on the printer's character encoding.

Text is laid out left-to-right on a white **284×96** landscape raster with 4-dot margins, fixed font sizes 12/16/20/24/28/32, no system text scaling, 1.15 line-height and vertical centering when it fits. CRLF/CR become LF, tabs become four spaces; explicit blank lines are preserved. Text wraps automatically. More than 500 UTF-16 code units, unsupported size, rendering failure, empty content or overflow prevents printing from the UI. Emoji and scripts outside the bundled font's coverage are not guaranteed; fallback glyph behavior can differ. Danish æøåÆØÅ has automated real-font raster tests.

Opaque RGBA is converted to luminance (0.299R+0.587G+0.114B); pixels below 128 become black. Transparency is composited on white. For landscape pixel `(x,y)`, clockwise portrait coordinates are `(95-y,x)`. Printer rows are MSB-first, **0=black, 1=white**. Buffer length stays **3408 bytes**. The PNG preview is reconstructed from these packed bytes by inverse rotation, so it cannot independently reflow or rescale text. Screen preview size is not a physical ruler.

Printing snapshots the buffer before any async operation, then uses the existing serialized transaction guard and write path:

1. Raw `1B 21 6F` (Cancel Pause), 500 ms quiet period.
2. Unchanged SIZE/GAP/DIRECTION/DENSITY/CLS and `BITMAP 0,0,12,284,1,` header.
3. Exactly 3408 binary bytes immediately after the header, then CRLF and `PRINT 1` plus CRLF.
4. Three-second settling period.

No TSPL TEXT command, user-controlled command interpolation or printer text encoding is used. Further edits cannot mutate an in-flight label. Other print/query actions cannot interleave, and loss/background cancellation never replays a job. API completion is not an acknowledgement of physical output. Logs still record accepted TX and raw RX.

## Automated verification

Tests cover known corner/bit positions after rotation, threshold/alpha, inverse preview pixels, exact payload/header framing, byte snapshots, command timing, multiline layout, font size, alignment, Danish glyphs distinct from question marks, empty/overflow states and editor-to-fake-transport printing. The original Go-generated reference fixture remains unchanged. Android builds/lint/signature checks and API 31/36 fresh-install/launch checks supplement Flutter tests. They do not validate thermal output or radio hardware.

## Physical checklist for the owner

Install v0.0.2 (temporary test signing can require uninstalling v0.0.1; saved settings are lost). Select/reconnect the printer and use 14×40 mm stock. Print `HP PROXMOX PVE1` and `192.168.1.2` as two lines at 20 dots; compare orientation, line order, text size, margins and polarity with the preview. Then test left/center/right and `Æble, øl og å / Æ Ø Å`, including a smaller size. Confirm that overflowing text disables printing. Keep the original diagnostics test as a baseline; export logs for failures, reviewing identifiers before sharing. Adjust geometry/polarity only after this controlled test provides evidence.
