import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class SpecialistScreen extends StatelessWidget {
  const SpecialistScreen({super.key});

  static const List<Map<String, String>> specialists = [
    {
      'name': 'د. أحمد الزهراني',
      'title': 'متخصص في أمراض النخيل والمحاصيل',
      'location': 'الرياض، المملكة العربية السعودية',
      'phone': '+966501234567',
      'available': 'متاح الآن',
      'rating': '4.9',
      'reviews': '128',
      'icon': '🌴',
    },
    {
      'name': 'د. فاطمة العتيبي',
      'title': 'خبيرة زراعية — خضار وفواكه',
      'location': 'جدة، المملكة العربية السعودية',
      'phone': '+966507654321',
      'available': 'متاح خلال ساعة',
      'rating': '4.8',
      'reviews': '95',
      'icon': '🥬',
    },
    {
      'name': 'م. خالد الدوسري',
      'title': 'مهندس زراعي — نباتات طبية وعطرية',
      'location': 'المدينة المنورة، المملكة العربية السعودية',
      'phone': '+966512345678',
      'available': 'متاح غداً',
      'rating': '4.7',
      'reviews': '63',
      'icon': '🌿',
    },
    {
      'name': 'د. سارة الغامدي',
      'title': 'باحثة في علم أمراض النبات',
      'location': 'الدمام، المملكة العربية السعودية',
      'phone': '+966598765432',
      'available': 'متاح الآن',
      'rating': '5.0',
      'reviews': '47',
      'icon': '🔬',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التواصل مع خبير'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Header banner
          _HeaderBanner(),

          // Specialists list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: specialists.length,
              itemBuilder: (context, index) => _SpecialistCard(
                specialist: specialists[index],
                index: index,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.darkGreen, AppTheme.primaryGreen],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('👨‍🌾', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'خبراء زراعيون معتمدون',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'تواصل مع متخصص للحصول على تشخيص دقيق',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _SpecialistCard extends StatelessWidget {
  final Map<String, String> specialist;
  final int index;

  const _SpecialistCard({required this.specialist, required this.index});

  bool get _isAvailableNow => specialist['available'] == 'متاح الآن';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.bgGreen,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryGreen.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(specialist['icon']!,
                        style: const TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        specialist['name']!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        specialist['title']!,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.grey),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 12, color: AppTheme.grey),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              specialist['location']!,
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Availability badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isAvailableNow
                        ? AppTheme.bgGreen
                        : AppTheme.lightOrange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _isAvailableNow
                              ? AppTheme.primaryGreen
                              : AppTheme.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        specialist['available']!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _isAvailableNow
                              ? AppTheme.primaryGreen
                              : AppTheme.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Rating row
            Row(
              children: [
                const Icon(Icons.star_rounded,
                    color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  specialist['rating']!,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${specialist['reviews']} تقييم)',
                  style: const TextStyle(
                      color: AppTheme.grey, fontSize: 12),
                ),
                const Spacer(),

                // Contact button
                SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showContactDialog(context, specialist),
                    icon: const Icon(Icons.phone_rounded, size: 16),
                    label: const Text('تواصل'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (index * 100).ms)
        .slideY(begin: 0.1);
  }

  void _showContactDialog(
      BuildContext context, Map<String, String> specialist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(specialist['icon']!,
                style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                specialist['name']!,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ContactOption(
              icon: Icons.phone_rounded,
              label: 'اتصال هاتفي',
              value: specialist['phone']!,
              color: AppTheme.primaryGreen,
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'جاري الاتصال بـ ${specialist['name']}...'),
                    backgroundColor: AppTheme.primaryGreen,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ContactOption(
              icon: Icons.message_rounded,
              label: 'رسالة واتساب',
              value: 'WhatsApp',
              color: const Color(0xFF25D366),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'جاري فتح واتساب مع ${specialist['name']}...'),
                    backgroundColor: const Color(0xFF25D366),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ContactOption(
              icon: Icons.email_rounded,
              label: 'بريد إلكتروني',
              value: 'Email',
              color: AppTheme.blue,
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'جاري فتح البريد الإلكتروني لـ ${specialist['name']}...'),
                    backgroundColor: AppTheme.blue,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }
}

class _ContactOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _ContactOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}