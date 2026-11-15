import 'package:flutter/material.dart';

import '../domain/format.dart';

/// Asks for an exact value for a day. Returns null when cancelled; a result
/// with a null value means "clear the day".
Future<({num? value})?> askValue(
  BuildContext context, {
  required String title,
  String unit = '',
  num? current,
}) => showDialog<({num? value})>(
  context: context,
  builder: (_) => _ValueDialog(title: title, unit: unit, current: current),
);

class _ValueDialog extends StatefulWidget {
  const _ValueDialog({required this.title, required this.unit, this.current});
  final String title;
  final String unit;
  final num? current;

  @override
  State<_ValueDialog> createState() => _ValueDialogState();
}

class _ValueDialogState extends State<_ValueDialog> {
  late final _c = TextEditingController(
    text: widget.current == null ? '' : formatNum(widget.current!),
  );
  bool _error = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final v = num.tryParse(_c.text.trim().replaceAll(',', '.'));
    if (v == null || v < 0 || !v.isFinite) {
      setState(() => _error = true);
      return;
    }
    Navigator.pop(context, (value: v));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      key: const Key('value-field'),
      controller: _c,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        suffixText: widget.unit.isEmpty ? null : widget.unit,
        errorText: _error ? 'Enter a number, 0 or more.' : null,
      ),
      onChanged: (_) {
        if (_error) setState(() => _error = false);
      },
      onSubmitted: (_) => _save(),
    ),
    actions: [
      if (widget.current != null)
        TextButton(
          key: const Key('value-clear'),
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          onPressed: () => Navigator.pop(context, (value: null)),
          child: const Text('Clear'),
        ),
      TextButton(
        key: const Key('value-cancel'),
        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('value-save'),
        style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
        onPressed: _save,
        child: const Text('Save'),
      ),
    ],
  );
}
