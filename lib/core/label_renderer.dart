import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'label_bitmap.dart';

Future<void>? _fontReady;
Future<void> loadLabelFont() => _fontReady ??= (() async {
  final loader = FontLoader('ASKGo')..addFont(rootBundle.load('assets/fonts/Go-Regular.ttf'));
  await loader.load();
})();

class LabelRaster {
  LabelRaster({required this.bitmap, required this.previewPng, required this.lineCount,
    required this.textHeight, required this.overflow, required this.empty});
  final Uint8List bitmap;
  final Uint8List previewPng;
  final int lineCount;
  final double textHeight;
  final bool overflow;
  final bool empty;
  bool get printable => !empty && !overflow;
}

Future<LabelRaster> renderLabel(String text, double fontSize, LabelAlignment alignment) async {
  if (text.length > 500 || !labelFontSizes.contains(fontSize)) {
    throw ArgumentError('Unsupported text length or font size');
  }
  await loadLabelFont();
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceAll('\t', '    ');
  final painter = TextPainter(
    text: TextSpan(text: normalized, style: TextStyle(fontFamily: 'ASKGo', fontSize: fontSize,
      color: const ui.Color(0xff000000), height: 1.15)),
    textDirection: ui.TextDirection.ltr,
    textAlign: switch (alignment) { LabelAlignment.left => ui.TextAlign.left,
      LabelAlignment.center => ui.TextAlign.center, LabelAlignment.right => ui.TextAlign.right },
    textScaler: TextScaler.noScaling,
  );
  const availableWidth = labelWidth - 2 * labelMargin;
  const availableHeight = labelHeight - 2 * labelMargin;
  painter.layout(minWidth: availableWidth, maxWidth: availableWidth);
  final lines = painter.computeLineMetrics();
  final height = painter.height;
  final overflow = height > availableHeight || lines.any((l) => l.width > availableWidth + 0.01);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
  canvas.save();
  canvas.clipRect(const ui.Rect.fromLTWH(labelMargin, labelMargin, availableWidth, availableHeight));
  painter.paint(canvas, ui.Offset(labelMargin, height <= availableHeight ? (labelHeight - height) / 2 : labelMargin));
  canvas.restore();
  painter.dispose();
  final picture = recorder.endRecording();
  final image = await picture.toImage(labelWidth, labelHeight);
  picture.dispose();
  final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (raw == null) throw StateError('Could not read rendered pixels');
  final bitmap = packLandscapeRgba(raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes));
  final previewRgba = unpackLandscapeRgba(bitmap);
  final buffer = await ui.ImmutableBuffer.fromUint8List(previewRgba);
  final descriptor = ui.ImageDescriptor.raw(buffer, width: labelWidth, height: labelHeight,
    pixelFormat: ui.PixelFormat.rgba8888);
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  frame.image.dispose(); codec.dispose(); descriptor.dispose(); buffer.dispose();
  if (png == null) throw StateError('Could not encode label preview');
  return LabelRaster(bitmap: bitmap, previewPng: png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
    lineCount: lines.length, textHeight: height, overflow: overflow, empty: normalized.trim().isEmpty);
}
