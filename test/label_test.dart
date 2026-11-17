import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nelko_p21_ask_mobile/core/label_bitmap.dart';
import 'package:nelko_p21_ask_mobile/core/label_renderer.dart';
import 'package:nelko_p21_ask_mobile/core/protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('rotation, MSB packing, polarity and preview inverse preserve corners', () {
    final rgba = Uint8List(labelWidth * labelHeight * 4)..fillRange(0, labelWidth * labelHeight * 4, 255);
    for (final point in [(0,0),(283,0),(0,95),(283,95),(15,11)]) {
      final i = (point.$2 * labelWidth + point.$1) * 4;
      rgba[i] = rgba[i+1] = rgba[i+2] = 0;
    }
    final bitmap = packLandscapeRgba(rgba);
    expect(bitmap, hasLength(3408));
    expect(bitmap[0], 0x7f); expect(bitmap[11], 0xfe);
    expect(bitmap[283*12], 0x7f); expect(bitmap[283*12+11], 0xfe);
    expect(bitmap[15*12+10], 0xf7);
    expect(unpackLandscapeRgba(bitmap), orderedEquals(rgba));
  });
  test('threshold and alpha on white do not invert backgrounds', () {
    final rgba = Uint8List(labelWidth * labelHeight * 4)..fillRange(0, labelWidth * labelHeight * 4, 255);
    rgba.setRange(0,12,[127,127,127,255,128,128,128,255,0,0,0,0]);
    final result = unpackLandscapeRgba(packLandscapeRgba(rgba));
    expect(result.sublist(0,12),[0,0,0,255,255,255,255,255,255,255,255,255]);
    expect(() => packLandscapeRgba(Uint8List(4)), throwsArgumentError);
    expect(() => unpackLandscapeRgba(Uint8List(4)), throwsArgumentError);
  });
  test('custom binary data is framed exactly like the tested reference and copied', () {
    final bitmap = Uint8List(3408)..fillRange(0,3408,255);
    bitmap.setRange(0,5,[0,13,10,27,255]);
    final job = bitmapPrintParts(bitmap);
    final reference = referencePrintParts();
    expect(job.length,9);
    for (final i in [0,1,2,3,4,5,7,8]) { expect(job[i], orderedEquals(reference[i])); }
    expect(job[6], orderedEquals(bitmap));
    bitmap[0]=123; expect(job[6][0],0);
    expect(() => bitmapPrintParts(Uint8List(3407)), throwsArgumentError);
  });
  testWidgets('bundled font renders the requested two-line label and Danish glyphs', (tester) async {
    final label = (await tester.runAsync(() => renderLabel('HP PROXMOX PVE1\n192.168.1.2',20,LabelAlignment.center)))!;
    await tester.runAsync(() async {
      final file=File('work/text-label-preview.png'); await file.parent.create(recursive:true); await file.writeAsBytes(label.previewPng);
    });
    expect(label.printable,true); expect(label.lineCount,2); expect(label.bitmap,hasLength(3408));
    expect(label.bitmap.any((b)=>b!=255),true);
    expect(label.previewPng.take(8), orderedEquals([137,80,78,71,13,10,26,10]));
    for (final letter in ['æ','ø','å','Æ','Ø','Å']) {
      final glyph = (await tester.runAsync(() => renderLabel(letter,24,LabelAlignment.left)))!;
      final question = (await tester.runAsync(() => renderLabel('?',24,LabelAlignment.left)))!;
      expect(glyph.printable,true);
      expect(glyph.bitmap, isNot(orderedEquals(question.bitmap)), reason:'$letter must have its own glyph');
    }
  });
  testWidgets('left center right alignment moves real bitmap ink; larger font grows text', (tester) async {
    final starts=<int>[];
    for (final alignment in LabelAlignment.values) {
      final label = (await tester.runAsync(() => renderLabel('ASK',20,alignment)))!;
      final rgba=unpackLandscapeRgba(label.bitmap);
      var minX=labelWidth;
      for(var y=0;y<labelHeight;y++) { for(var x=0;x<labelWidth;x++) {
        if(rgba[(y*labelWidth+x)*4]==0 && x<minX) minX=x;
      }}
      starts.add(minX);
    }
    expect(starts[0],lessThan(starts[1])); expect(starts[1],lessThan(starts[2]));
    final small=(await tester.runAsync(()=>renderLabel('ASK',12,LabelAlignment.left)))!;
    final big=(await tester.runAsync(()=>renderLabel('ASK',32,LabelAlignment.left)))!;
    expect(big.textHeight,greaterThan(small.textHeight));
  });
  testWidgets('empty text, overflow and invalid inputs cannot produce printable labels', (tester) async {
    final empty=(await tester.runAsync(()=>renderLabel('  \n ',20,LabelAlignment.left)))!;
    expect(empty.printable,false); expect(empty.bitmap.every((b)=>b==255),true);
    final huge=(await tester.runAsync(()=>renderLabel(List.filled(12,'Æble Øl År').join('\n'),32,LabelAlignment.center)))!;
    expect(huge.overflow,true); expect(huge.printable,false);
    final wrapped=(await tester.runAsync(()=>renderLabel(List.filled(15,'WORD').join(' '),20,LabelAlignment.left)))!;
    expect(wrapped.lineCount,greaterThan(1));
    await tester.runAsync(() async {
      await expectLater(renderLabel('ASK',99,LabelAlignment.left),throwsArgumentError);
      await expectLater(renderLabel('x'*501,20,LabelAlignment.left),throwsArgumentError);
    });
  });
}
