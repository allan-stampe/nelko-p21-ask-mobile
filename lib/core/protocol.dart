// Reference print adapted from NELKO P21 ASK Edition (MIT, Tyler C).
import 'dart:convert';
import 'dart:typed_data';

const sppUuid = '00001101-0000-1000-8000-00805f9b34fb';
const cancelPauseDelay = Duration(milliseconds: 500);
const printSettleDelay = Duration(seconds: 3);
const batteryReplyWindow = Duration(seconds: 3);
Uint8List get cancelPauseBytes => Uint8List.fromList([0x1b, 0x21, 0x6f]);
Uint8List get batteryCommand => Uint8List.fromList(ascii.encode('BATTERY?\r\n'));

List<Uint8List> referencePrintParts() {
  final bitmap = Uint8List(12 * 284)..fillRange(0, 12 * 284, 0xff);
  for (var y = 0; y < 284; y++) {
    for (var x = 0; x < 96; x++) {
      final border = (x >= 4 && x < 92 && ((y >= 4 && y < 7) || (y >= 277 && y < 280))) ||
          (y >= 4 && y < 280 && ((x >= 4 && x < 7) || (x >= 89 && x < 92)));
      final bar = x >= 20 && x < 76 && ((y >= 60 && y < 66) || (y >= 120 && y < 126) || (y >= 180 && y < 186));
      if (border || bar) bitmap[y * 12 + x ~/ 8] &= ~(1 << (7 - x % 8));
    }
  }
  Uint8List line(String s) => Uint8List.fromList(ascii.encode(s));
  return [
    line('SIZE 14.0 mm,40.0 mm\r\n'),
    line('GAP 5.0 mm,0 mm\r\n'),
    line('DIRECTION 0,0\r\n'),
    line('DENSITY 15\r\n'),
    line('CLS\r\n'),
    line('BITMAP 0,0,12,284,1,'),
    bitmap,
    line('\r\n'),
    line('PRINT 1\r\n'),
  ];
}

class BatteryReading {
  const BatteryReading(this.percent, this.charging);
  final int percent;
  final bool charging;
}

// Research profile: ASCII "BATTERY " + BCD percentage + charging byte + CRLF.
// Do not trim binary whitespace or guess the old desktop's ambiguous byte offset.
BatteryReading? parseBattery(List<int> data) {
  final prefix = ascii.encode('BATTERY ');
  for (var start = 0; start + prefix.length + 4 <= data.length; start++) {
    var match = true;
    for (var i = 0; i < prefix.length; i++) {
      if (data[start + i] != prefix[i]) { match = false; break; }
    }
    if (!match) continue;
    final p = start + prefix.length;
    final raw = data[p];
    final high = raw >> 4;
    final low = raw & 15;
    if (high > 9 || low > 9 || data[p + 1] > 1 || data[p + 2] != 13 || data[p + 3] != 10) continue;
    return BatteryReading(high * 10 + low, data[p + 1] == 1);
  }
  return null;
}
