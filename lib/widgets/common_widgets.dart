import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PlantTypeSelectorWidget extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onTypeSelected;

  const PlantTypeSelectorWidget({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
  });

  static const List<Map<String, String>> plantTypes = [
    {'id': 'vegetables-fruits', 'label': 'خضار وفواكه', 'icon': '🥬'},
    {'id': 'mint',              'label': 'النعناع',      'icon': '🌿'},
    {'id': 'palm',              'label': 'النخيل',       'icon': '🌴'},
  ];

  // Builds a card with a row of plant type buttons for the user to select from
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختر نوع النبات',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGreen,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: plantTypes.map((type) => Expanded(
                child: _TypeButton(
                  type: type,
                  isSelected: selectedType == type['id'],
                  onTap: () => onTypeSelected(type['id']!),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final Map<String, String> type;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  // Builds one plant type button that animates its border and background when selected
  @override
  Widget build(BuildContext context) {
    final isOther     = type['id'] == 'other';
    final activeColor = isOther ? Colors.pink : AppTheme.primaryGreen;
    final activeBg    = isOther ? const Color(0xFFFFF0F9) : AppTheme.bgGreen;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: activeColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Column(
          children: [
            Text(type['icon']!, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              type['label']!,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? activeColor : AppTheme.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String content;
  final Color backgroundColor;
  final Color borderColor;
  final Color titleColor;
  final String? icon;

  const InfoCard({
    super.key,
    required this.title,
    required this.content,
    required this.backgroundColor,
    required this.borderColor,
    required this.titleColor,
    this.icon,
  });

  // Builds a colored card showing a title with an optional icon and a block of text content
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${icon ?? ''} $title',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class ConfidenceBadge extends StatelessWidget {
  final double confidence;
  const ConfidenceBadge({super.key, required this.confidence});

  // Returns green, orange, or red based on how high the confidence score is
  Color get _color {
    if (confidence >= 70) return AppTheme.primaryGreen;
    if (confidence >= 50) return AppTheme.orange;
    return AppTheme.red;
  }

  // Builds a small pill badge showing the diagnosis confidence percentage with a matching color
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Text(
        'دقة التشخيص: ${confidence.toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;

  const GradientButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
  });

  // Builds a full-width green gradient button with an icon — shows a spinner when loading, or an outlined style if isOutlined is true
  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size(double.infinity, 50),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.emerald],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size(double.infinity, 50),
        ),
        icon: isLoading
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2),
        )
            : Icon(icon, size: 20),
        label: Text(
          isLoading ? 'جاري التحليل...' : label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}