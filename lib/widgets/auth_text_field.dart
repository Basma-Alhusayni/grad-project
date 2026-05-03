import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool enabled;

  const AuthTextField({
    super.key,
    required this.hint,
    required this.icon,
    required this.controller,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.enabled = true,
  });

  // Builds a right-aligned text input field with an icon, green focus border, and optional validation
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      enabled: enabled,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintTextDirection: TextDirection.rtl,
        suffixIcon: Icon(icon, color: Colors.grey[400]),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: Color(0xFF16A34A), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
    );
  }
}