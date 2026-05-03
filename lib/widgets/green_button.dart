import 'package:flutter/material.dart';

class GreenButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const GreenButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
  });

  // Builds a full-width green button with an optional icon — shows a spinner when loading and dims when disabled
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          disabledBackgroundColor: const Color(0xFF16A34A).withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        child: isLoading
            ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}