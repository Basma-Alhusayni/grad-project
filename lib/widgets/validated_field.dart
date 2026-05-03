import 'package:flutter/material.dart';

class ValidatedField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final String? errorText;
  final TextInputType keyboardType;
  final bool enabled;

  const ValidatedField({
    super.key,
    required this.hint,
    required this.icon,
    required this.controller,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
  });

  // Builds a right-aligned text input field that turns red and shows an error message when errorText is set
  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: hint,
            hintTextDirection: TextDirection.rtl,
            suffixIcon: Icon(icon, color: Colors.grey[400]),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: hasError
                      ? Colors.red
                      : const Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: hasError
                      ? Colors.red
                      : const Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: hasError
                      ? Colors.red
                      : const Color(0xFF16A34A),
                  width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Text(errorText!,
                style: const TextStyle(
                    color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }
}

class PasswordField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final bool visible;
  final String? errorText;
  final VoidCallback onToggle;
  final bool enabled;

  const PasswordField({
    super.key,
    required this.hint,
    required this.controller,
    required this.visible,
    required this.onToggle,
    this.errorText,
    this.enabled = true,
  });

  // Builds a password input field with a show/hide toggle that turns red and shows an error message when errorText is set
  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: controller,
          obscureText: !visible,
          enabled: enabled,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: IconButton(
              icon: Icon(
                visible
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: Colors.grey[400],
                size: 20,
              ),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: hasError
                      ? Colors.red
                      : const Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: hasError
                      ? Colors.red
                      : const Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: hasError
                      ? Colors.red
                      : const Color(0xFF16A34A),
                  width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Text(errorText!,
                style: const TextStyle(
                    color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }
}