import 'dart:convert';
import 'dart:typed_data';

class LogEntry {
  LogEntry(this.id, this.time, this.direction, List<int> bytes, this.note)
      : bytes = Uint8List.fromList(bytes);
  final int id;
  final DateTime time;
  final String direction;
  final Uint8List bytes;
  final String note;
  String get timestamp => time.toUtc().toIso8601String();
  String get asciiText {
    final s = StringBuffer();
    for (final b in bytes) {
      if (b == 13) { s.write(r'\r'); }
      else if (b == 10) { s.write(r'\n'); }
      else if (b == 92) { s.write(r'\\'); }
      else if (b >= 32 && b <= 126) { s.writeCharCode(b); }
      else { s.write('\\x${b.toRadixString(16).padLeft(2, '0')}'); }
    }
    return s.toString();
  }
  String get hexText {
    final s = StringBuffer();
    for (var i = 0; i < bytes.length; i += 16) {
      s.write('${i.toRadixString(16).padLeft(4, '0')}: ');
      for (var j = i; j < i + 16 && j < bytes.length; j++) {
        s.write('${bytes[j].toRadixString(16).padLeft(2, '0').toUpperCase()} ');
      }
      s.writeln();
    }
    return s.toString();
  }
  String get text => '$timestamp $direction ${bytes.length} bytes $note\nASCII: $asciiText\nHEX:\n$hexText';
}

class DiagnosticLog {
  DiagnosticLog({this.maxBytes = 256 * 1024, this.maxEntries = 500});
  final int maxBytes;
  final int maxEntries;
  final List<LogEntry> _entries = [];
  int _bytes = 0;
  int _sequence = 0;
  int discarded = 0;
  List<LogEntry> get entries => List.unmodifiable(_entries);
  void add(String direction, {List<int> bytes = const [], String note = '', DateTime? at}) {
    // Bound individual records and clearly identify parts of one large API write.
    if (bytes.length > 4096) {
      for (var i = 0; i < bytes.length; i += 4096) {
        final end = i + 4096 < bytes.length ? i + 4096 : bytes.length;
        add(direction, bytes: bytes.sublist(i, end), note: '$note [slice $i..$end of ${bytes.length} bytes]', at: at);
      }
      return;
    }
    final entry = LogEntry(++_sequence, at ?? DateTime.now(), direction, bytes, note.length > 2048 ? note.substring(0, 2048) : note);
    _entries.add(entry);
    _bytes += utf8.encode(entry.text).length;
    while (_entries.isNotEmpty && (_bytes > maxBytes || _entries.length > maxEntries)) {
      _bytes -= utf8.encode(_entries.removeAt(0).text).length;
      discarded++;
    }
  }
  String export() => 'NELKO P21 – ASK Mobile Edition v0.0.2 (EXPERIMENTAL)\n'
      'Owner confirmed v0.0.1 SPP and two test prints on Samsung S22. v0.0.2 custom text hardware output NOT CONFIRMED.\n'
      'UTC timestamps. TX = bytes accepted by Android API, not printer acknowledgement.\n'
      'RX = bytes read from the socket. Includes Bluetooth identifiers; exported only by user.\n'
      'Older records discarded: $discarded\n\n${_entries.map((e) => e.text).join('\n')}';
}
