import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SpecialistListScreen extends StatefulWidget {
  final String? plantImage;
  final String? plantDescription;

  const SpecialistListScreen({
    super.key,
    this.plantImage,
    this.plantDescription,
  });

  @override
  State<SpecialistListScreen> createState() => _SpecialistListScreenState();
}

class _SpecialistListScreenState extends State<SpecialistListScreen> {
  final _db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  final _messageController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // ── إرسال طلب استشارة ──────────────────────────────────────
  Future<void> _sendRequest(Map<String, dynamic> specialist) async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء كتابة رسالة للخبير',
              textDirection: TextDirection.rtl),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    await _db.collection('chats').add({
      'specialistId': specialist['id'],
      'userId': uid,
      'userName': FirebaseAuth.instance.currentUser?.displayName ?? 'مستخدم',
      'lastMessage': msg,
      'time': timeStr,
      'online': false,
      'unread': 1,
      'createdAt': now.toIso8601String(),
      'messages': [
        {
          'id': 'msg-${now.millisecondsSinceEpoch}',
          'sender': 'user',
          'content': msg,
          'time': timeStr,
          'type': 'text',
        },
      ],
    });

    _messageController.clear();
    if (mounted) {
      Navigator.of(context).pop(); // close bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال الطلب إلى ${specialist['name']}',
              textDirection: TextDirection.rtl),
          backgroundColor: Colors.green[700],
        ),
      );
    }
  }

  // ── ديالوج إرسال الرسالة ───────────────────────────────────
  void _openMessageDialog(Map<String, dynamic> specialist) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تواصل مع ${specialist['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('رسالتك للخبير',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _messageController,
                maxLines: 4,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'اشرح المشكلة التي تواجهها مع نبتتك...',
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16a34a)),
              icon: const Icon(Icons.send, size: 16),
              label: const Text('إرسال'),
              onPressed: () => _sendRequest(specialist),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Sheet تفاصيل الخبير ─────────────────────────────
  void _showExpertDetails(Map<String, dynamic> expert) {
    final isAvailable = expert['isAvailable'] == true;
    final rating = (expert['rating'] ?? 0).toDouble();
    final specialties = List<String>.from(expert['specialties'] ?? []);
    final availableHours =
    List<String>.from(expert['availableHours'] ?? []);
    final totalCases = expert['totalCases'] ?? 0;
    final experience = expert['experience'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // ── العنوان ──────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('تفاصيل الخبير',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── معلومات الخبير ────────────────────────
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFFdcfce7),
                      child: Text(
                        (expert['name'] as String? ?? '').isNotEmpty
                            ? expert['name'][0]
                            : '؟',
                        style: const TextStyle(
                            color: Color(0xFF15803d), fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(expert['name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? const Color(0xFF16a34a)
                                  : Colors.grey[400],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isAvailable ? 'متاح' : 'مشغول',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── التقييم ───────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ...List.generate(5, (i) => Icon(
                        Icons.star,
                        size: 22,
                        color: i < rating.round()
                            ? Colors.amber
                            : Colors.grey[300],
                      )),
                      const SizedBox(width: 8),
                      Text(
                        '$rating (${expert['totalReviews'] ?? 0} تقييم)',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── الإحصائيات ────────────────────────────
                Row(
                  children: [
                    _InfoBox(
                      icon: Icons.calendar_today,
                      value: '$totalCases',
                      label: 'حالة',
                      color: Colors.green,
                    ),
                    const SizedBox(width: 10),
                    _InfoBox(
                      icon: Icons.workspace_premium,
                      value: experience.isNotEmpty ? experience : '-',
                      label: 'خبرة',
                      color: Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── التخصصات ─────────────────────────────
                if (specialties.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(12),
                      border:
                      Border.all(color: const Color(0xFFE9D5FF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('التخصصات:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF6B21A8))),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: specialties
                              .map((s) => Container(
                            padding:
                            const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: const Color(
                                      0xFFD8B4FE)),
                              borderRadius:
                              BorderRadius.circular(20),
                            ),
                            child: Text(s,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color:
                                    Color(0xFF7E22CE))),
                          ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),

                // ── الأوقات المتاحة ───────────────────────
                if (availableHours.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFf0fdf4),
                      borderRadius: BorderRadius.circular(12),
                      border:
                      Border.all(color: const Color(0xFF86efac)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('الأوقات المتاحة:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF166534))),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: availableHours
                              .map((h) => Container(
                            padding:
                            const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: const Color(
                                      0xFF86efac)),
                              borderRadius:
                              BorderRadius.circular(20),
                            ),
                            child: Text(h,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color:
                                    Color(0xFF166534))),
                          ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // ── زر التواصل ────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAvailable
                          ? const Color(0xFF16a34a)
                          : Colors.grey[300],
                      foregroundColor: isAvailable
                          ? Colors.white
                          : Colors.grey[600],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 20),
                    label: const Text('تواصل مع الخبير',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    onPressed: isAvailable
                        ? () {
                      Navigator.of(context).pop();
                      _openMessageDialog(expert);
                    }
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0FDF4),
        body: StreamBuilder<QuerySnapshot>(
          stream: _db.collection('experts').snapshots(),
          builder: (context, snapshot) {
            final allDocs = snapshot.data?.docs ?? [];
            final allExperts = allDocs
                .map((d) =>
            {'id': d.id, ...d.data() as Map<String, dynamic>})
                .toList();

            final filtered = allExperts.where((e) {
              final q = _searchQuery.toLowerCase();
              return (e['name'] ?? '').toLowerCase().contains(q) ||
                  ((e['specialties'] as List<dynamic>? ?? [])
                      .any((s) => s.toString().toLowerCase().contains(q)));
            }).toList();

            final totalAvailable = allExperts
                .where((e) => e['isAvailable'] == true)
                .length;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      children: [
                        const Text('الخبراء المتخصصون',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF166534))),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          textDirection: TextDirection.rtl,
                          onChanged: (v) =>
                              setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'ابحث عن خبير أو تخصص...',
                            hintStyle: TextStyle(
                                fontSize: 13, color: Colors.grey[400]),
                            prefixIcon: const Icon(Icons.search,
                                color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFFF0FDF4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _StatBox(
                                value: '$totalAvailable',
                                label: 'متاح الآن',
                                color: Colors.blue),
                            const SizedBox(width: 10),
                            _StatBox(
                                value: '${allExperts.length}',
                                label: 'خبير متاح',
                                color: Colors.green),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (filtered.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                          child: Text('لا يوجد خبراء',
                              style: TextStyle(color: Colors.grey))),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final expert = filtered[index];
                          return _ExpertCard(
                            expert: expert,
                            onTap: () => _showExpertDetails(expert),
                            onContact: () {
                              _showExpertDetails(expert);
                            },
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── إحصائية ─────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final MaterialColor color;

  const _StatBox(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.shade100),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: color.shade600)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 12, color: color.shade500)),
          ],
        ),
      ),
    );
  }
}

// ─── صندوق معلومة ─────────────────────────────────────────────
class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final MaterialColor color;

  const _InfoBox(
      {required this.icon,
        required this.value,
        required this.label,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.shade100),
        ),
        child: Column(
          children: [
            Icon(icon, color: color.shade400, size: 24),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color.shade600)),
            Text(label,
                style: TextStyle(fontSize: 12, color: color.shade400)),
          ],
        ),
      ),
    );
  }
}

// ─── بطاقة الخبير ────────────────────────────────────────────
class _ExpertCard extends StatelessWidget {
  final Map<String, dynamic> expert;
  final VoidCallback onTap;
  final VoidCallback onContact;

  const _ExpertCard(
      {required this.expert,
        required this.onTap,
        required this.onContact});

  @override
  Widget build(BuildContext context) {
    final isAvailable = expert['isAvailable'] == true;
    final rating = (expert['rating'] ?? 0).toDouble();
    final specialties = List<String>.from(expert['specialties'] ?? []);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAvailable
                ? const Color(0xFFbbf7d0)
                : Colors.grey[200]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFFdcfce7),
                        child: Text(
                          (expert['name'] as String? ?? '').isNotEmpty
                              ? expert['name'][0]
                              : '؟',
                          style: const TextStyle(
                              color: Color(0xFF15803d), fontSize: 20),
                        ),
                      ),
                      if (isAvailable)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: Colors.green[500],
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(expert['name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isAvailable
                                    ? const Color(0xFF16a34a)
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isAvailable ? 'متاح' : 'مشغول',
                                style: TextStyle(
                                  color: isAvailable
                                      ? Colors.white
                                      : Colors.grey[600],
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('${expert['rating'] ?? 0}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 4),
                            ...List.generate(5, (i) => Icon(
                              Icons.star,
                              size: 14,
                              color: i < rating.round()
                                  ? Colors.amber
                                  : Colors.grey[300],
                            )),
                          ],
                        ),
                        if (specialties.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: specialties
                                .take(2)
                                .map((s) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F3FF),
                                border: Border.all(
                                    color:
                                    const Color(0xFFD8B4FE)),
                                borderRadius:
                                BorderRadius.circular(20),
                              ),
                              child: Text(s,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF7E22CE))),
                            ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAvailable
                        ? const Color(0xFF16a34a)
                        : Colors.grey[300],
                    foregroundColor: isAvailable
                        ? Colors.white
                        : Colors.grey[600],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  icon: Icon(
                    isAvailable
                        ? Icons.chat_bubble_outline
                        : Icons.block,
                    size: 18,
                  ),
                  label: Text(
                    isAvailable ? 'تواصل مع الخبير' : 'غير متاح حالياً',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: isAvailable ? onTap : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
