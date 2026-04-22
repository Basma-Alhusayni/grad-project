import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'chat_with_user_screen.dart';

class SpecialistListScreen extends StatefulWidget {
  const SpecialistListScreen({super.key});

  @override
  State<SpecialistListScreen> createState() => _SpecialistListScreenState();
}

class _SpecialistListScreenState extends State<SpecialistListScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String _searchText = '';

  // فلاتر تاب الخبراء
  bool? _filterAvailable; // null=الكل, true=متاح, false=غير متاح

  // فلاتر تاب الدردشات
  String _chatFilter = 'all'; // all, pending, completed, new

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── فتح الشات ──────────────────────────────────────────────
  Future<void> _openChat(Map<String, dynamic> data, String expertId, bool isAvailable) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';

    // 🔥 NEW: Fetch the actual name from the 'users' collection
    String userName = 'مستخدم';
    if (uid.isNotEmpty) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists) {
          // Grabs 'fullName' or 'username' based on your screenshot
          userName = userDoc.data()?['fullName'] ?? userDoc.data()?['username'] ?? 'مستخدم';
        }
      } catch (e) {
        debugPrint('Error fetching user name: $e');
      }
    }

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Just create the chat
    final chatRef = await FirebaseFirestore.instance.collection('chats').add({
      'specialistId': expertId,
      'specialistName': data['fullName'] ?? '',
      'userId': uid,
      'userName': userName, // ✅ Now uses the correct database name!
      'expertRating': data['rating'] ?? 5.0,
      'lastMessage': 'تم بدء المحادثة',
      'time': timeStr,
      'online': isAvailable,
      'userUnread': 0,
      'expertUnread': 1,
      'expertApproved': true,
      'completed': false,
      'plantImage': '',
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'messages': [],
    });

    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatWithUserScreen(
        chatId: chatRef.id,
        expertName: data['fullName'] ?? '',
        expertRating: ((data['rating'] ?? 0) as num).toDouble(),
        isOnline: isAvailable,
      )));
    }
  }

  // ── Bottom Sheet تفاصيل الخبير ─────────────────────────────
  // Added 'bool isAvailable' to the parameters to fix the undefined error
  void _showExpertDetails(Map<String, dynamic> data, String docId, bool isAvailable) {
    final rating = ((data['rating'] ?? 0) as num).toDouble();
    final name = data['fullName'] ?? '';
    final firstLetter = name.isNotEmpty ? name[0] : 'خ';
    final totalCases = data['totalCases'] ?? data['reviewCount'] ?? 0;
    final experience = data['experience'] ?? '';
    final certificates = data['certificates'] ?? '';
    final availableHours = List<String>.from(data['availableHours'] ?? []);
    final reviewCount = data['reviewCount'] ?? 0;
    final specialties = certificates.toString().isNotEmpty
        ? certificates.toString().split(',').map((s) => s.trim()).toList()
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
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
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                                  fontWeight: FontWeight.bold, fontSize: 17)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? const Color(0xFF22C55E)
                                  : Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(14),
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
                    border: Border.all(color: const Color(0xFFF5E7A8)),
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
                      ...List.generate(5, (i) => Icon(
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
                    Expanded(child: _infoBox(Icons.calendar_today,
                        '$totalCases', 'حالة',
                        const Color(0xFFF2FBF4), const Color(0xFF2E8B57))),
                    const SizedBox(width: 12),
                    Expanded(child: _infoBox(Icons.workspace_premium,
                        experience.isNotEmpty ? experience : '-', 'خبرة',
                        const Color(0xFFF3F7FF), const Color(0xFF4B7BE5))),
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
                      border: Border.all(color: const Color(0xFFE7D7FF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('التخصصات:',
                            style: TextStyle(fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6B3FA0))),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: specialties.map((s) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: const Color(0xFFD8B4FE)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(s, style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7E22CE),
                                fontWeight: FontWeight.w600)),
                          )).toList(),
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
                      border: Border.all(color: const Color(0xFFD5F0DB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('الأوقات المتاحة:',
                            style: TextStyle(fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E8B57))),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: availableHours.map((h) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: const Color(0xFF86efac)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(h, style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF166534),
                                fontWeight: FontWeight.w600)),
                          )).toList(),
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
                          ? const Color(0xFF16A34A) : Colors.grey[300],
                      foregroundColor: isAvailable
                          ? Colors.white : Colors.grey[600],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    // Added the missing onPressed function!
                    onPressed: isAvailable
                        ? () {
                      Navigator.of(context).pop();
                      _openChat(data, docId, isAvailable);
                    }
                        : null,
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('تواصل مع الخبير',
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.bold)),
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

  Widget _infoBox(IconData icon, String value, String label, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0FDF4),
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            // ── هيدر ─────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  // ── تابين ────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: _tabBtn('الخبراء', 0)), // Changed to الخبراء since requests are gone
                      const SizedBox(width: 10),
                      Expanded(child: _tabBtn('المحادثات', 1)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // ── بحث ──────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      textDirection: TextDirection.rtl,
                      onChanged: (v) => setState(() => _searchText = v),
                      decoration: const InputDecoration(
                        hintText: 'ابحث عن اسم الخبير...', // ✅ New
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),

            // ── محتوى التابين ────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildExpertsList(),
                  _buildChatsList(uid),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── زر التاب ──────────────────────────────────────────────
  Widget _tabBtn(String label, int index) {
    final selected = _tabController.index == index;
    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF16A34A) : Colors.grey[200]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: selected ? const Color(0xFF16A34A) : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  // ── قائمة الخبراء ─────────────────────────────────────────
  Widget _buildExpertsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('specialists').snapshots(),
      builder: (context, specialistSnapshot) {
        if (specialistSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)));
        }

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('expertSchedules').get(),
          builder: (context, scheduleSnapshot) {
            if (!scheduleSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)));
            }

            final now = DateTime.now();
            final todayKey = DateFormat('yyyy-MM-dd').format(now);
            final allDocs = specialistSnapshot.data?.docs ?? [];

            final schedules = {
              for (var doc in scheduleSnapshot.data!.docs)
                doc.id: doc.data() as Map<String, dynamic>
            };

            int availableCount = 0;

            final filtered = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final expertId = doc.id;

              // 1. Are we currently inside the scheduled time? (Sole source of truth)
              bool isCurrentlyAvailable = false;
              final expertSchedule = schedules[expertId];

              if (expertSchedule != null && expertSchedule[todayKey] != null && expertSchedule[todayKey]['isAvailable'] == true) {
                try {
                  final todayData = expertSchedule[todayKey];
                  final startParts = (todayData['startTime'] ?? '00:00').split(':');
                  final endParts = (todayData['endTime'] ?? '23:59').split(':');

                  final startTime = DateTime(now.year, now.month, now.day, int.parse(startParts[0]), int.parse(startParts[1]));
                  final endTime = DateTime(now.year, now.month, now.day, int.parse(endParts[0]), int.parse(endParts[1]));

                  if (now.isAfter(startTime) && now.isBefore(endTime)) {
                    isCurrentlyAvailable = true;
                  }
                } catch (e) {
                  debugPrint('Error parsing time: $e');
                }
              }

              if (isCurrentlyAvailable) availableCount++;

              final q = _searchText.toLowerCase();
              final matchSearch = (data['fullName'] ?? '').toString().toLowerCase().contains(q);

              final matchAvail = _filterAvailable == null || isCurrentlyAvailable == _filterAvailable;

              return matchSearch && matchAvail;
            }).toList();

            final unavailableCount = allDocs.length - availableCount;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          _filterChip(
                            'متاح ($availableCount)',
                            _filterAvailable == true,
                                () => setState(() => _filterAvailable = _filterAvailable == true ? null : true),
                            activeColor: const Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 8),
                          _filterChip(
                            'غير متاح ($unavailableCount)',
                            _filterAvailable == false,
                                () => setState(() => _filterAvailable = _filterAvailable == false ? null : false),
                            activeColor: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (filtered.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: Text('لا توجد نتائج مطابقة', style: TextStyle(color: Colors.grey))),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(14),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final doc = filtered[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final expertId = doc.id;

                          // Recalculate for the individual UI card
                          bool isAvailable = false;
                          final expertSchedule = schedules[expertId];
                          if (expertSchedule != null && expertSchedule[todayKey] != null && expertSchedule[todayKey]['isAvailable'] == true) {
                            try {
                              final todayData = expertSchedule[todayKey];
                              final startParts = (todayData['startTime'] ?? '00:00').split(':');
                              final endParts = (todayData['endTime'] ?? '23:59').split(':');
                              final startTime = DateTime(now.year, now.month, now.day, int.parse(startParts[0]), int.parse(startParts[1]));
                              final endTime = DateTime(now.year, now.month, now.day, int.parse(endParts[0]), int.parse(endParts[1]));
                              if (now.isAfter(startTime) && now.isBefore(endTime)) isAvailable = true;
                            } catch (_) {}
                          }

                          final name = data['fullName'] ?? 'بدون اسم';
                          final rating = ((data['rating'] ?? 0) as num).toDouble();
                          final firstLetter = name.isNotEmpty ? name[0] : 'خ';

                          return GestureDetector(
                            onTap: () => _showExpertDetails(data, doc.id, isAvailable),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE1F1E4)),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: const Color(0xFFDDF7DD),
                                          child: Text(firstLetter, style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 18)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2F3A33))),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: isAvailable ? const Color(0xFF22C55E) : Colors.grey[300],
                                                      borderRadius: BorderRadius.circular(14),
                                                    ),
                                                    child: Text(
                                                      isAvailable ? 'متاح' : 'غير متاح',
                                                      style: TextStyle(color: isAvailable ? Colors.white : Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 14, color: Color(0xFF666666))),
                                                  const SizedBox(width: 6),
                                                  ...List.generate(5, (i) => Icon(i < rating.round() ? Icons.star : Icons.star_border, color: const Color(0xFFF4B400), size: 16)),
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
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isAvailable ? const Color(0xFF16A34A) : Colors.grey[200],
                                          foregroundColor: isAvailable ? Colors.white : Colors.grey[500],
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 13),
                                          elevation: 0,
                                        ),
                                        onPressed: isAvailable ? () => _openChat(data, doc.id, isAvailable) : null,
                                        icon: Icon(isAvailable ? Icons.chat_bubble_outline : Icons.block, size: 18),
                                        label: Text(
                                          isAvailable ? 'تواصل مع الخبير' : 'غير متاح حالياً',
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
        );
      },
    );
  }

  // ── قائمة الدردشات ────────────────────────────────────────
  Widget _buildChatsList(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allChats = snapshot.data?.docs ?? [];

        // حساب الفلاتر
        final activeCount = allChats
            .where((d) => (d.data() as Map<String, dynamic>)['completed'] != true)
            .length;
        final completedCount = allChats
            .where((d) => (d.data() as Map<String, dynamic>)['completed'] == true)
            .length;

        // فلترة
        List<QueryDocumentSnapshot> filtered = allChats.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final matchSearch = (data['specialistName'] ?? '')
              .toString()
              .toLowerCase()
              .contains(_searchText.toLowerCase());

          bool matchFilter = true;
          if (_chatFilter == 'pending') {
            matchFilter = data['completed'] != true; // Reusing 'pending' keyword to mean active
          } else if (_chatFilter == 'completed') {
            matchFilter = data['completed'] == true;
          }
          return matchSearch && matchFilter;
        }).toList();
        // 🔥 SAFELY PARSED SORTING BLOCK:
        filtered.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;

          // Helper function to safely convert any time format to DateTime
          DateTime parseTime(dynamic timeVal) {
            if (timeVal is Timestamp) {
              return timeVal.toDate();
            } else if (timeVal is String && timeVal.isNotEmpty) {
              return DateTime.tryParse(timeVal) ?? DateTime(2000);
            }
            return DateTime(2000); // Fallback for null or invalid data
          }

          final timeA = parseTime(dataA['updatedAt'] ?? dataA['createdAt']);
          final timeB = parseTime(dataB['updatedAt'] ?? dataB['createdAt']);

          // Compare B to A for descending order (newest first)
          return timeB.compareTo(timeA);
        });
        return CustomScrollView(
          slivers: [
            // ── فلاتر الدردشات ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip(
                        'جارية ($activeCount)',
                        _chatFilter == 'pending',
                            () => setState(() => _chatFilter = _chatFilter == 'pending' ? 'all' : 'pending'),
                        activeColor: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      _filterChip(
                        'مكتملة ($completedCount)',
                        _chatFilter == 'completed',
                            () => setState(() => _chatFilter = _chatFilter == 'completed' ? 'all' : 'completed'),
                        activeColor: const Color(0xFF16A34A),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (filtered.isEmpty)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        const Text('لا توجد دردشات بعد', style: TextStyle(color: Colors.grey, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(14),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final data = filtered[index].data() as Map<String, dynamic>;
                      final chatId = filtered[index].id;
                      final expertName = data['specialistName'] ?? '';
                      final lastMsg = data['lastMessage'] ?? '';
                      final time = data['time'] ?? '';
                      final unread = data['userUnread'] ?? 0;
                      final isCompleted = data['completed'] == true;

                      return GestureDetector(
                        onTap: () {
                          // ✅ Reset ONLY the user's badge when they open the chat
                          FirebaseFirestore.instance.collection('chats').doc(chatId).update({'userUnread': 0});

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatWithUserScreen(
                                chatId: chatId,
                                expertName: expertName,
                                expertRating: (data['expertRating'] ?? 0).toDouble(),
                                isOnline: data['online'] == true,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE1F1E4)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFFDDF7DD),
                                child: Text(
                                  expertName.isNotEmpty ? expertName[0] : 'خ',
                                  style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(expertName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isCompleted ? const Color(0xFF16A34A) : Colors.orange,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            isCompleted ? 'مكتملة' : 'جارية',
                                            style: const TextStyle(color: Colors.white, fontSize: 10),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            lastMsg,
                                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(time, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (unread > 0) ...[
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 11,
                                  backgroundColor: const Color(0xFF16A34A),
                                  child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11)),
                                ),
                              ],
                            ],
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
    );
  }

  Widget _filterChip(
      String label,
      bool isSelected,
      VoidCallback onTap, {
        Color activeColor = const Color(0xFF16A34A),
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? activeColor : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}