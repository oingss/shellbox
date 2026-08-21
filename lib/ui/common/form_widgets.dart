import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Labeled [TextField] that matches the app's added-server forms.
class ShellTextField extends StatelessWidget {
  const ShellTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.number = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType keyboardType;
  final bool number;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: number ? '范围 1-65535' : null,
      ),
      // Number-only fields shouldn't offer the letters layout.
      inputFormatters: number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))]
          : null,
    );
  }
}

/// Segment toggle implemented with Material 3 [SegmentedButton].
class AuthTypeToggle extends StatelessWidget {
  const AuthTypeToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value; // true = 私钥
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('密码')),
        ButtonSegment(value: true, label: Text('私钥')),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}