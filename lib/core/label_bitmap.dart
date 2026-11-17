import 'dart:typed_data';

const labelWidth = 284;
const labelHeight = 96;
const printerWidth = 96;
const printerHeight = 284;
const labelMargin = 4.0;
const labelFontSizes = [12.0, 16.0, 20.0, 24.0, 28.0, 32.0];
enum LabelAlignment { left, center, right }

// Windows ASK Edition's landscape -> clockwise portrait convention, with the
// physically tested reference polarity: 0=black, 1=white; MSB-first rows.
Uint8List packLandscapeRgba(Uint8List rgba) {
  if (rgba.length != labelWidth * labelHeight * 4) {
    throw ArgumentError('Expected opaque 284x96 RGBA pixels');
  }
  final result = Uint8List(12 * printerHeight)..fillRange(0, 12 * printerHeight, 255);
  for (var y = 0; y < labelHeight; y++) {
    for (var x = 0; x < labelWidth; x++) {
      final i = (y * labelWidth + x) * 4;
      // Composite alpha on white before luminance threshold (128).
      final alpha = rgba[i + 3];
      final luminance = (299 * rgba[i] + 587 * rgba[i + 1] + 114 * rgba[i + 2]) / 1000;
      final gray = (luminance * alpha + 255 * (255 - alpha)) / 255;
      if (gray < 128) {
        final px = labelHeight - 1 - y;
        final py = x;
        result[py * 12 + px ~/ 8] &= ~(1 << (7 - px % 8));
      }
    }
  }
  return result;
}

// Preview is reconstructed from the actual packed printer bits, not re-typeset.
Uint8List unpackLandscapeRgba(Uint8List bitmap) {
  if (bitmap.length != 3408) throw ArgumentError('Expected 3408 bitmap bytes');
  final rgba = Uint8List(labelWidth * labelHeight * 4);
  for (var y = 0; y < labelHeight; y++) {
    for (var x = 0; x < labelWidth; x++) {
      final px = labelHeight - 1 - y;
      final value = (bitmap[x * 12 + px ~/ 8] & (1 << (7 - px % 8))) == 0 ? 0 : 255;
      final i = (y * labelWidth + x) * 4;
      rgba[i] = value; rgba[i + 1] = value; rgba[i + 2] = value; rgba[i + 3] = 255;
    }
  }
  return rgba;
}
