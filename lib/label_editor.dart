import 'dart:async';
import 'package:flutter/material.dart';
import 'core/label_bitmap.dart';
import 'core/label_renderer.dart';
import 'core/printer_controller.dart';
import 'i18n.dart';

class LabelEditor extends StatefulWidget {
  const LabelEditor({super.key, required this.controller, required this.labels});
  final PrinterController controller;
  final Labels labels;
  @override
  State<LabelEditor> createState() => _LabelEditorState();
}

class _LabelEditorState extends State<LabelEditor> with AutomaticKeepAliveClientMixin {
  final _text = TextEditingController();
  double _fontSize = 20;
  LabelAlignment _alignment = LabelAlignment.center;
  LabelRaster? _raster;
  bool _rendering = false;
  bool _failed = false;
  int _generation = 0;
  @override
  bool get wantKeepAlive => true;
  Future<void> _update() async {
    final token = ++_generation;
    final text = _text.text;
    setState(() { _raster = null; _rendering = text.trim().isNotEmpty; _failed = false; });
    if (text.trim().isEmpty) return;
    try {
      final raster = await renderLabel(text, _fontSize, _alignment);
      if (mounted && token == _generation) setState(() { _raster = raster; _rendering = false; });
    } catch (e) {
      if (mounted && token == _generation) {
        widget.controller.recordLayoutError(e);
        setState(() { _rendering = false; _failed = true; });
      }
    }
  }
  @override
  void dispose() { ++_generation; _text.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = widget.labels;
    final c = widget.controller;
    final raster = _raster;
    final canPrint = c.connected && !c.busy && !_rendering && raster != null && raster.printable;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(l.t('labelHelp')),
      const SizedBox(height: 12),
      TextField(key: const Key('label-text'), controller: _text, minLines: 2, maxLines: 4, maxLength: 500,
        keyboardType: TextInputType.multiline, textInputAction: TextInputAction.newline,
        decoration: InputDecoration(border: const OutlineInputBorder(), labelText: l.t('labelText'),
          hintText: 'HP PROXMOX PVE1\n192.168.1.2'), onChanged: (_) => unawaited(_update())),
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [Text(l.t('fontSize')), const SizedBox(width: 12),
        DropdownButton<double>(key: const Key('label-font-size'), value: _fontSize,
          items: [for (final size in labelFontSizes) DropdownMenuItem(value: size, child: Text('${size.toInt()} dots'))],
          onChanged: (value) { if (value != null) { _fontSize = value; unawaited(_update()); } }),
      ]),
      const SizedBox(height: 8),
      SegmentedButton<LabelAlignment>(key: const Key('label-alignment'), selected: {_alignment},
        segments: [
          ButtonSegment(value: LabelAlignment.left, icon: const Icon(Icons.format_align_left), label: Text(l.t('alignLeft'))),
          ButtonSegment(value: LabelAlignment.center, icon: const Icon(Icons.format_align_center), label: Text(l.t('alignCenter'))),
          ButtonSegment(value: LabelAlignment.right, icon: const Icon(Icons.format_align_right), label: Text(l.t('alignRight'))),
        ], onSelectionChanged: (values) { _alignment = values.single; unawaited(_update()); }),
      const SizedBox(height: 16),
      Text('${l.t('preview')} — 14 × 40 mm', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      DecoratedBox(decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey)),
        child: AspectRatio(aspectRatio: labelWidth / labelHeight, child: raster == null
          ? Center(child: Text(l.t(_rendering ? 'rendering' : 'emptyLabel'), style: const TextStyle(color: Colors.black54)))
          : Semantics(label: '${l.t('preview')}: ${_text.text}', image: true,
              child: Image.memory(raster.previewPng, key: const Key('label-preview'), gaplessPlayback: false,
                filterQuality: FilterQuality.none, fit: BoxFit.fill, excludeFromSemantics: true)))),
      const SizedBox(height: 8),
      if (raster?.overflow == true) Text(l.t('textOverflow'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (_failed) Text(l.t('renderFailed'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (!c.connected) Text(l.t('connectToPrint')),
      const SizedBox(height: 12),
      FilledButton.icon(key: const Key('print-label'), icon: const Icon(Icons.print),
        onPressed: canPrint ? () => c.printLabel(raster.bitmap) : null,
        label: Padding(padding: const EdgeInsets.all(8), child: Text(l.t(c.busy ? 'busy' : 'printLabel')))),
      const SizedBox(height: 8), Text(l.t('textHardwareTest'), style: const TextStyle(fontSize: 12)),
    ]);
  }
}
