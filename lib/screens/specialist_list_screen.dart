import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'chat_with_user_screen.dart';

class SpecialistListScreen extends StatefulWidget {
  const SpecialistListScreen({super.key});

  @override
  State<SpecialistListScreen> createState() =>
      _SpecialistListScreenState();
}

class _SpecialistListScreenState extends State<SpecialistListScreen> {
  final TextEditingController _searchController =
  TextEditingController();
  bool _showAvailableOnly = false;
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── فتح الشات مباشرة + إرسال طلب للخبير ───────────────────
  Future<void> _openChat(Map<String, dynamic> data, String expertId) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';
    final userName = user?.displayName ?? 'مستخدم';
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // إنشاء chat بحالة pending (الخبير ما يشوفه إلا بعد الموافقة)
    final chatRef =
    await FirebaseFirestore.instance.collection('chats').add({
      'specialistId': expertId,
      'specialistName': data['fullName'] ?? '',
      'userId': uid,
      'userName': userName,
      'lastMessage': '',
      'time': timeStr,
      'online': false,
      'unread': 0,
      'expertApproved': false, // الخبير ما وافق بعد
      'createdAt': now.toIso8601String(),
      'messages': [],
    });

    // إنشاء طلب في requests
    await FirebaseFirestore.instance.collection('requests').add({
      'specialistId': expertId,
      'specialistName': data['fullName'] ?? '',
      'userId': uid,
      'userName': userName,
      'chatId': chatRef.id,
      'status': 'pending',
      'date': '${now.day}/${now.month}/${now.year}',
      'time': timeStr,
      'createdAt': now.toIso8601String(),
    });

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatWithUserScreen(
            chatId: chatRef.id,
            expertName: data['fullName'] ?? '',
            expertRating:
            ((data['rating'] ?? 0) as num).toDouble(),
            isOnline: data['isAvailable'] == true,
          ),
        ),
      );
    }
  }

  // ── Bottom Sheet تفاصيل الخبير ─────────────────────────────
  void _showExpertDetails(Map<String, dynamic> data, String docId) {
    final isAvailable = data['isAvailable'] == true;
    final rating = ((data['rating'] ?? 0) as num).toDouble();
    final name = data['fullName'] ?? '';
    final firstLetter = name.isNotEmpty ? name[0] : 'خ';
    final totalCases =
        data['totalCases'] ?? data['reviewCount'] ?? 0;
    final experience = data['experience'] ?? '';
    final certificates = data['certificates'] ?? '';
    final availableHours =
    List<String>.from(data['availableHours'] ?? []);
    final reviewCount = data['reviewCount'] ?? 0;
    final specialties = certificates.toString().isNotEmpty
        ? certificates
        .toString()
        .split(',')
        .map((s) => s.trim())
        .toList()
        : <String>[];

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
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text('تفاصيل الخبير',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFFDDF7DD),
                      child: Text(firstLetter,
                          style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                              fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? const Color(0xFF22C55E)
                                  : Colors.grey.shade400,
                              borderRadius:
                              BorderRadius.circular(14),
                            ),
                            child: Text(
                              isAvailable ? 'متاح' : 'غير متاح',
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8DB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFF5E7A8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$rating ($reviewCount تقييم)',
                          style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF6B5E1A),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      ...List.generate(
                          5,
                              (i) => Icon(
                              i < rating.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              color: const Color(0xFFF4B400),
                              size: 20)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _infoBox(
                          Icons.calendar_today,
                          '$totalCases',
                          'حالة',
                          const Color(0xFFF2FBF4),
                          const Color(0xFF2E8B57)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _infoBox(
                          Icons.workspace_premium,
                          experience.isNotEmpty ? experience : '-',
                          'خبرة',
                          const Color(0xFFF3F7FF),
                          const Color(0xFF4B7BE5)),
                    ),
                  ],
                ),
                if (specialties.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F5FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFE7D7FF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('التخصصات:',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6B3FA0))),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: specialties
                              .map((s) => Container(
                            padding: const EdgeInsets
                                .symmetric(
                                horizontal: 10,
                                vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: const Color(
                                      0xFFD8B4FE)),
                              borderRadius:
                              BorderRadius.circular(
                                  20),
                            ),
                            child: Text(s,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color:
                                    Color(0xFF7E22CE),
                                    fontWeight:
                                    FontWeight.w600)),
                          ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
                if (availableHours.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2FBF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFD5F0DB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('الأوقات المتاحة:',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E8B57))),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: availableHours
                              .map((h) => Container(
                            padding: const EdgeInsets
                                .symmetric(
                                horizontal: 10,
                                vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: const Color(
                                      0xFF86efac)),
                              borderRadius:
                              BorderRadius.circular(
                                  20),
                            ),
                            child: Text(h,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color:
                                    Color(0xFF166534),
                                    fontWeight:
                                    FontWeight.w600)),
                          ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAvailable
                          ? const Color(0xFF16A34A)
                          : Colors.grey[300],
                      foregroundColor: isAvailable
                          ? Colors.white
                          : Colors.grey[600],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline,
                        size: 18),
                    label: const Text('تواصل مع الخبير',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    onPressed: isAvailable
                        ? () {
                      Navigator.of(context).pop();
                      _openChat(data, docId);
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

  Widget _infoBox(IconData icon, String value, String label,
      Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: TextStyle(fontSize: 13, color: color)),
        ],
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
          stream: FirebaseFirestore.instance
              .collection('specialists')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF16A34A)));
            }

            final allDocs = snapshot.data?.docs ?? [];
            final filtered = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final q = _searchText.toLowerCase();
              final matchSearch = (data['fullName'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(q) ||
                  (data['certificates'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(q);
              final matchAvail = !_showAvailableOnly ||
                  data['isAvailable'] == true;
              return matchSearch && matchAvail;
            }).toList();

            final totalExperts = allDocs.length;
            final availableNow = allDocs
                .where((d) =>
            (d.data() as Map<String, dynamic>)[
            'isAvailable'] ==
                true)
                .length;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      children: [
<<<<<<< HEAD
                        const Text('الخبراء المتخصصون',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF166534))),
                        const SizedBox(height: 14),
=======
                        //خبراء متخصصون
>>>>>>> 4a3691ecb9c23c0dc6ec33b2b4bd34f1e4151d5f
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _searchController,
                            textDirection: TextDirection.rtl,
                            onChanged: (v) =>
                                setState(() => _searchText = v),
                            decoration: const InputDecoration(
                              hintText: 'ابحث عن خبير أو تخصص...',
                              hintStyle: TextStyle(
                                  color: Colors.grey, fontSize: 13),
                              prefixIcon: Icon(Icons.search,
                                  color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            // متاح الآن
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() =>
                                _showAvailableOnly =
                                !_showAvailableOnly),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 18),
                                  decoration: BoxDecoration(
                                    color: _showAvailableOnly
                                        ? const Color(0xFF6475D8)
                                        : Colors.white,
                                    borderRadius:
                                    BorderRadius.circular(16),
                                    border: Border.all(
                                        color:
                                        const Color(0xFFDADDF8)),
                                  ),
                                  child: Column(
                                    children: [
                                      Text('$availableNow',
                                          style: TextStyle(
                                              fontSize: 28,
                                              fontWeight:
                                              FontWeight.bold,
                                              color: _showAvailableOnly
                                                  ? Colors.white
                                                  : const Color(
                                                  0xFF6475D8))),
                                      const SizedBox(height: 4),
<<<<<<< HEAD
                                      Text('متاح الآن',
=======
                                      Text('خبير متاح',
>>>>>>> 4a3691ecb9c23c0dc6ec33b2b4bd34f1e4151d5f
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: _showAvailableOnly
                                                  ? Colors.white
                                                  : const Color(
                                                  0xFF5F7B6D),
                                              fontWeight:
                                              FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // خبير متاح
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(
                                        () => _showAvailableOnly = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 18),
                                  decoration: BoxDecoration(
                                    color: !_showAvailableOnly
                                        ? const Color(0xFF2E8B57)
                                        : Colors.white,
                                    borderRadius:
                                    BorderRadius.circular(16),
                                    border: Border.all(
                                        color:
                                        const Color(0xFFD6F0DB)),
                                  ),
                                  child: Column(
                                    children: [
                                      Text('$totalExperts',
                                          style: TextStyle(
                                              fontSize: 28,
                                              fontWeight:
                                              FontWeight.bold,
                                              color: !_showAvailableOnly
                                                  ? Colors.white
                                                  : const Color(
                                                  0xFF2E8B57))),
                                      const SizedBox(height: 4),
<<<<<<< HEAD
                                      Text('خبير متاح',
=======
                                      Text('خبير غير متاح',
>>>>>>> 4a3691ecb9c23c0dc6ec33b2b4bd34f1e4151d5f
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: !_showAvailableOnly
                                                  ? Colors.white
                                                  : const Color(
                                                  0xFF5F7B6D),
                                              fontWeight:
                                              FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                          child: Text('ما حصلت نتائج',
                              style: TextStyle(color: Colors.grey))),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(14),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final doc = filtered[index];
                          final data =
                          doc.data() as Map<String, dynamic>;
                          final isAvailable =
                              data['isAvailable'] == true;
                          final name = data['fullName'] ?? 'بدون اسم';
                          final rating =
                          ((data['rating'] ?? 0) as num)
                              .toDouble();
                          final firstLetter =
                          name.isNotEmpty ? name[0] : 'خ';

                          return GestureDetector(
                            onTap: () =>
                                _showExpertDetails(data, doc.id),
                            child: Container(
                              margin:
                              const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                BorderRadius.circular(16),
                                border: Border.all(
                                    color:
                                    const Color(0xFFE1F1E4)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withOpacity(0.03),
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
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor:
                                          const Color(0xFFDDF7DD),
                                          child: Text(firstLetter,
                                              style: const TextStyle(
                                                  color: Color(
                                                      0xFF2E7D32),
                                                  fontWeight:
                                                  FontWeight.bold,
                                                  fontSize: 18)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(name,
                                                        style: const TextStyle(
                                                            fontSize:
                                                            16,
                                                            fontWeight:
                                                            FontWeight
                                                                .bold,
                                                            color: Color(
                                                                0xFF2F3A33))),
                                                  ),
                                                  const SizedBox(
                                                      width: 8),
                                                  if (isAvailable)
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal:
                                                          10,
                                                          vertical: 3),
                                                      decoration:
                                                      BoxDecoration(
                                                        color: const Color(
                                                            0xFF22C55E),
                                                        borderRadius:
                                                        BorderRadius
                                                            .circular(
                                                            14),
                                                      ),
                                                      child: const Text(
                                                          'متاح',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white,
                                                              fontSize:
                                                              11,
                                                              fontWeight:
                                                              FontWeight
                                                                  .bold)),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(
                                                  height: 6),
                                              Row(
                                                children: [
                                                  Text(
                                                      rating
                                                          .toStringAsFixed(
                                                          1),
                                                      style: const TextStyle(
                                                          fontSize: 14,
                                                          color: Color(
                                                              0xFF666666))),
                                                  const SizedBox(
                                                      width: 6),
                                                  ...List.generate(
                                                      5,
                                                          (i) => Icon(
                                                        i <
                                                            rating
                                                                .round()
                                                            ? Icons
                                                            .star
                                                            : Icons
                                                            .star_border,
                                                        color: const Color(
                                                            0xFFF4B400),
                                                        size: 16,
                                                      )),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style:
                                        ElevatedButton.styleFrom(
                                          backgroundColor: isAvailable
                                              ? const Color(0xFF16A34A)
                                              : const Color(
                                              0xFFA7D8B0),
                                          foregroundColor: Colors.white,
                                          shape:
                                          RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius
                                                  .circular(
                                                  12)),
                                          padding: const EdgeInsets
                                              .symmetric(vertical: 13),
                                          elevation: 0,
                                        ),
                                        onPressed: isAvailable
                                            ? () =>
                                            _openChat(data, doc.id)
                                            : null,
                                        icon: const Icon(
                                            Icons.chat_bubble_outline,
                                            size: 18),
                                        label: Text(
                                          isAvailable
                                              ? 'تواصل مع الخبير'
                                              : 'غير متاح حالياً',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight:
                                              FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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