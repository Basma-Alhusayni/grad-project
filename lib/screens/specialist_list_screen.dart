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
  String _availabilityFilter = 'الكل';
  String _chatFilter = 'all';

  // Set up the tab controller and listen for tab changes
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  // Clean up the search controller and tab controller
  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Creates a new chat document in Firestore and navigates to the chat screen with the selected expert
  Future<void> _openChat(Map<String, dynamic> data, String expertId, bool isAvailable) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';

    String userName = 'مستخدم';
    if (uid.isNotEmpty) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists) {
          userName = userDoc.data()?['fullName'] ?? userDoc.data()?['username'] ?? 'مستخدم';
        }
      } catch (e) {
        debugPrint('Error fetching user name: $e');
      }
    }

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final chatRef = await FirebaseFirestore.instance.collection('chats').add({
      'specialistId': expertId,
      'specialistName': data['fullName'] ?? '',
      'userId': uid,
      'userName': userName,
      'expertRating': data['rating'] ?? 5.0,
      'lastMessage': 'تم بدء المحادثة',
      'time': timeStr,
      'online': isAvailable,
      'userUnread': 0,
      'expertUnread': 0,
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

  // Gets the specialist's certificate images from their profile or from their original join request
  Future<List<String>> _fetchCertificateImages(String docId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('specialists')
          .doc(docId)
          .get();
      final d = doc.data() ?? {};
      List<String> images = [];
      if (d['certificateImages'] is List) {
        images = (d['certificateImages'] as List).map((e) => e.toString()).toList();
      }
      if (images.isEmpty) {
        final reqSnap = await FirebaseFirestore.instance
            .collection('specialist_requests')
            .where('specialistId', isEqualTo: docId)
            .limit(1)
            .get();
        if (reqSnap.docs.isNotEmpty) {
          final reqData = reqSnap.docs.first.data();
          if (reqData['certificateImages'] is List) {
            images = (reqData['certificateImages'] as List).map((e) => e.toString()).toList();
          }
        }
      }
      return images;
    } catch (e) {
      return [];
    }
  }

  // Fetches the latest 10 reviews for a specialist ordered by newest first
  Future<List<Map<String, dynamic>>> _fetchReviews(String docId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('specialists')
          .doc(docId)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      return snap.docs.map((e) => e.data()).toList();
    } catch (e) {
      return [];
    }
  }

  // Fetches the latest 5 reports submitted by a specialist
  Future<List<Map<String, dynamic>>> _fetchReports(String docId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('specialist_reports')
          .where('specialistId', isEqualTo: docId)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
      return snap.docs.map((e) => e.data()).toList();
    } catch (e) {
      return [];
    }
  }

  // Opens a zoomable full-screen preview of a certificate image
  void _showFullCertImage(String url) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('معاينة الشهادة',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF14532D),
                          fontSize: 16)),
                  IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: InteractiveViewer(
                    maxScale: 5.0,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 250,
                          color: const Color(0xFFF3F4F6),
                          child: const Center(
                            child: CircularProgressIndicator(color: Color(0xFF16A34A)),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        width: double.infinity,
                        color: const Color(0xFFFEF2F2),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, color: Colors.red, size: 48),
                            SizedBox(height: 8),
                            Text('تعذر تحميل الصورة',
                                style: TextStyle(color: Colors.red, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Opens a scrollable bottom sheet with the expert's full profile, certificates, reviews, reports, and a contact button
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
      builder: (_) => SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.92,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) => SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                              i < rating.round() ? Icons.star : Icons.star_border,
                              color: const Color(0xFFF4B400),
                              size: 20)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _infoBox(
                              Icons.calendar_today,
                              '$totalCases',
                              'حالة',
                              const Color(0xFFF2FBF4),
                              const Color(0xFF2E8B57))),
                          const SizedBox(width: 12),
                          Expanded(child: _infoBox(
                              Icons.workspace_premium,
                              experience.isNotEmpty ? experience : '-',
                              'خبرة',
                              const Color(0xFFF3F7FF),
                              const Color(0xFF4B7BE5))),
                        ],
                      ),
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
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6B3FA0))),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: specialties.map((s) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: const Color(0xFFD8B4FE)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(s,
                                    style: const TextStyle(
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
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E8B57))),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: availableHours.map((h) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: const Color(0xFF86efac)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(h,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF166534),
                                        fontWeight: FontWeight.w600)),
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    FutureBuilder<List<String>>(
                      future: _fetchCertificateImages(docId),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF16A34A), strokeWidth: 2),
                            ),
                          );
                        }
                        if (!snap.hasData || snap.data!.isEmpty) return const SizedBox();
                        final images = snap.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE8E8E8)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.workspace_premium,
                                          color: Color(0xFF16A34A), size: 18),
                                      const SizedBox(width: 8),
                                      const Text('الشهادات الموثقة',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF14532D))),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text('${images.length} شهادة',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF16A34A),
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 120,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: images.length,
                                      itemBuilder: (_, i) => GestureDetector(
                                        onTap: () => _showFullCertImage(images[i]),
                                        child: Container(
                                          width: 140,
                                          margin: const EdgeInsets.only(left: 10),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFE8E8E8)),
                                          ),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(9),
                                                child: Image.network(
                                                  images[i],
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (context, child, progress) {
                                                    if (progress == null) return child;
                                                    return Container(
                                                      color: const Color(0xFFF0FDF4),
                                                      child: const Center(
                                                        child: CircularProgressIndicator(
                                                            color: Color(0xFF16A34A),
                                                            strokeWidth: 2),
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder: (_, __, ___) => const Center(
                                                    child: Icon(Icons.broken_image,
                                                        color: Colors.grey),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 0,
                                                left: 0,
                                                right: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      vertical: 5, horizontal: 8),
                                                  decoration: BoxDecoration(
                                                    borderRadius: const BorderRadius.vertical(
                                                        bottom: Radius.circular(9)),
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topCenter,
                                                      end: Alignment.bottomCenter,
                                                      colors: [
                                                        Colors.transparent,
                                                        Colors.black.withOpacity(0.55),
                                                      ],
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text('شهادة ${i + 1}',
                                                          style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold)),
                                                      const Icon(Icons.zoom_in,
                                                          color: Colors.white, size: 14),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
                    ),

                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchReviews(docId),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF16A34A), strokeWidth: 2),
                            ),
                          );
                        }
                        if (!snap.hasData || snap.data!.isEmpty) return const SizedBox();
                        final reviews = snap.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          color: Color(0xFFF4B400), size: 18),
                                      const SizedBox(width: 8),
                                      const Text('آراء المستخدمين',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF6B5E1A))),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF9C3),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text('${reviews.length} تقييم',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFFD97706),
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ...reviews.take(5).map((r) {
                                    final rRating = (r['rating'] ?? 5).toInt();
                                    final userName = r['userName'] ?? 'مستخدم';
                                    final comment = r['comment'] ?? '';
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFE8E8E8)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 16,
                                                backgroundColor: const Color(0xFFDCFCE7),
                                                child: Text(
                                                  userName.isNotEmpty ? userName[0] : 'م',
                                                  style: const TextStyle(
                                                      color: Color(0xFF16A34A),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(userName,
                                                        style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 13,
                                                            color: Colors.black87)),
                                                    Row(
                                                      children: List.generate(
                                                          5,
                                                              (i) => Icon(
                                                              i < rRating
                                                                  ? Icons.star
                                                                  : Icons.star_border,
                                                              color: const Color(0xFFF4B400),
                                                              size: 12)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (comment.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(comment,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black54,
                                                    height: 1.4)),
                                          ],
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
                    ),

                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchReports(docId),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF16A34A), strokeWidth: 2),
                            ),
                          );
                        }
                        if (!snap.hasData || snap.data!.isEmpty) return const SizedBox();
                        final reports = snap.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFD5F0DB)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.description_outlined,
                                          color: Color(0xFF16A34A), size: 18),
                                      const SizedBox(width: 8),
                                      const Text('تقارير سابقة',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF14532D))),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text('${reports.length} تقرير',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF16A34A),
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ...reports.take(3).map((r) {
                                    final hasImage =
                                        (r['plantImage'] ?? '').toString().isNotEmpty;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border:
                                        Border.all(color: const Color(0xFFE1F1E4)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.03),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF0FDF4),
                                                    borderRadius:
                                                    BorderRadius.circular(10),
                                                  ),
                                                  child: const Icon(Icons.eco,
                                                      color: Color(0xFF16A34A),
                                                      size: 20),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        r['plantName'] ??
                                                            'نبات غير معروف',
                                                        style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 14,
                                                            color: Color(0xFF14532D)),
                                                      ),
                                                      Text(
                                                        'المستخدم: ${r['userName'] ?? 'مستخدم'}',
                                                        style: const TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Text(r['date'] ?? '',
                                                    style: const TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.grey)),
                                              ],
                                            ),
                                          ),

                                          if (hasImage) ...[
                                            ClipRRect(
                                              borderRadius: BorderRadius.zero,
                                              child: Image.network(
                                                r['plantImage'],
                                                height: 150,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                const SizedBox.shrink(),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                          ],

                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                12, 0, 12, 8),
                                            child: Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF9FAFB),
                                                borderRadius:
                                                BorderRadius.circular(10),
                                                border: Border.all(
                                                    color:
                                                    const Color(0xFFE5E7EB)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                                children: [
                                                  const Text('التشخيص:',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                          FontWeight.bold,
                                                          color:
                                                          Color(0xFF374151))),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    r['diagnosis'] ??
                                                        'لا يوجد تشخيص',
                                                    style: const TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.black87,
                                                        height: 1.4),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                12, 0, 12, 12),
                                            child: Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFFBEB),
                                                borderRadius:
                                                BorderRadius.circular(10),
                                                border: Border.all(
                                                    color:
                                                    const Color(0xFFFDE68A)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                                children: [
                                                  const Text('العلاج المقترح:',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                          FontWeight.bold,
                                                          color:
                                                          Color(0xFFD97706))),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    r['treatment'] ??
                                                        'لا يوجد علاج مقترح',
                                                    style: const TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.black87,
                                                        height: 1.4),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
                    ),

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
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        onPressed: isAvailable
                            ? () {
                          Navigator.of(context).pop();
                          _openChat(data, docId, isAvailable);
                        }
                            : null,
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('تواصل مع الخبير',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Confirms with the user then deletes the chat and all its linked reports and feed posts
  Future<void> _confirmDeleteChat(String chatId, String expertName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('حذف المحادثة',
              style: TextStyle(
                  color: Color(0xFF14532D), fontWeight: FontWeight.bold)),
          content: Text(
              'هل تريد حذف محادثتك مع $expertName؟ سيتم أيضاً حذف أي تقارير مشتركة مرتبطة بها.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style:
              ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 0),
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final db = FirebaseFirestore.instance;
      final feedSnap = await db
          .collection('community_feed')
          .where('chatId', isEqualTo: chatId)
          .get();
      for (var doc in feedSnap.docs) {
        await doc.reference.delete();
      }
      final reportSnap = await db
          .collection('specialist_reports')
          .where('chatId', isEqualTo: chatId)
          .get();
      for (var doc in reportSnap.docs) {
        await doc.reference.delete();
      }
      await db.collection('chats').doc(chatId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ تم حذف المحادثة والتقارير المرتبطة بها'),
            backgroundColor: Color(0xFF2D322C),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // A small colored box showing an icon, a value, and a label — used for case count and experience
  Widget _infoBox(IconData icon, String value, String label, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Builds the main screen with a tab switcher, search bar, and two tabs for experts and chats
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
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _tabBtn('الخبراء', 0)),
                      const SizedBox(width: 10),
                      Expanded(child: _tabBtn('المحادثات', 1)),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                        hintText: 'ابحث عن اسم الخبير...',
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

  // A tab button that highlights with a green border when selected
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

  // Fetches all specialists and their schedules, checks who is available right now, and shows a filtered list
  Widget _buildExpertsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('specialists').snapshots(),
      builder: (context, specialistSnapshot) {
        if (specialistSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF16A34A)));
        }

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('expertSchedules').get(),
          builder: (context, scheduleSnapshot) {
            if (!scheduleSnapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF16A34A)));
            }

            final now = DateTime.now();
            final todayKey = DateFormat('yyyy-MM-dd').format(now);
            final allDocs = specialistSnapshot.data?.docs ?? [];

            final schedules = {
              for (var doc in scheduleSnapshot.data!.docs)
                doc.id: doc.data() as Map<String, dynamic>
            };

            int availableCount = 0;
            final availabilityMap = <String, bool>{};

            for (final doc in allDocs) {
              final expertId = doc.id;
              bool isCurrentlyAvailable = false;
              final expertSchedule = schedules[expertId];

              if (expertSchedule != null &&
                  expertSchedule[todayKey] != null &&
                  expertSchedule[todayKey]['isAvailable'] == true) {
                try {
                  final todayData = expertSchedule[todayKey];
                  final startParts = (todayData['startTime'] ?? '00:00').split(':');
                  final endParts = (todayData['endTime'] ?? '23:59').split(':');
                  final startTime = DateTime(now.year, now.month, now.day,
                      int.parse(startParts[0]), int.parse(startParts[1]));
                  final endTime = DateTime(now.year, now.month, now.day,
                      int.parse(endParts[0]), int.parse(endParts[1]));
                  if (now.isAfter(startTime) && now.isBefore(endTime)) {
                    isCurrentlyAvailable = true;
                  }
                } catch (e) {
                  debugPrint('Error parsing time: $e');
                }
              }
              availabilityMap[expertId] = isCurrentlyAvailable;
              if (isCurrentlyAvailable) availableCount++;
            }

            final unavailableCount = allDocs.length - availableCount;
            final totalCount = allDocs.length;

            final filtered = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final isAvailable = availabilityMap[doc.id] ?? false;
              final q = _searchText.toLowerCase();
              final matchSearch =
              (data['fullName'] ?? '').toString().toLowerCase().contains(q);
              final matchAvail = _availabilityFilter == 'الكل' ||
                  (_availabilityFilter == 'متاح' && isAvailable) ||
                  (_availabilityFilter == 'غير متاح' && !isAvailable);
              return matchSearch && matchAvail;
            }).toList();

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                    child: Row(
                      children: [
                        _availChip(
                          'الكل ($totalCount)',
                          _availabilityFilter == 'الكل',
                              () => setState(() => _availabilityFilter = 'الكل'),
                          activeColor: const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 8),
                        _availChip(
                          'متاح ($availableCount)',
                          _availabilityFilter == 'متاح',
                              () => setState(() => _availabilityFilter = 'متاح'),
                          activeColor: const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 8),
                        _availChip(
                          'غير متاح ($unavailableCount)',
                          _availabilityFilter == 'غير متاح',
                              () => setState(() => _availabilityFilter = 'غير متاح'),
                          activeColor: const Color(0xFF16A34A),
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
                          child: Text('لا توجد نتائج مطابقة',
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
                          final data = doc.data() as Map<String, dynamic>;
                          final isAvailable = availabilityMap[doc.id] ?? false;
                          final name = data['fullName'] ?? 'بدون اسم';
                          final rating = ((data['rating'] ?? 0) as num).toDouble();
                          final firstLetter = name.isNotEmpty ? name[0] : 'خ';

                          return GestureDetector(
                            onTap: () =>
                                _showExpertDetails(data, doc.id, isAvailable),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE1F1E4)),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2))
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
                                          backgroundColor: const Color(0xFFDDF7DD),
                                          child: Text(firstLetter,
                                              style: const TextStyle(
                                                  color: Color(0xFF2E7D32),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(name,
                                                        style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFF2F3A33))),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 10, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: isAvailable
                                                          ? const Color(0xFF22C55E)
                                                          : Colors.grey[300],
                                                      borderRadius:
                                                      BorderRadius.circular(14),
                                                    ),
                                                    child: Text(
                                                      isAvailable ? 'متاح' : 'غير متاح',
                                                      style: TextStyle(
                                                          color: isAvailable
                                                              ? Colors.white
                                                              : Colors.grey[600],
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Text(rating.toStringAsFixed(1),
                                                      style: const TextStyle(
                                                          fontSize: 14,
                                                          color: Color(0xFF666666))),
                                                  const SizedBox(width: 6),
                                                  ...List.generate(
                                                      5,
                                                          (i) => Icon(
                                                          i < rating.round()
                                                              ? Icons.star
                                                              : Icons.star_border,
                                                          color: const Color(0xFFF4B400),
                                                          size: 16)),
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
                                          backgroundColor: isAvailable
                                              ? const Color(0xFF16A34A)
                                              : Colors.grey[200],
                                          foregroundColor: isAvailable
                                              ? Colors.white
                                              : Colors.grey[500],
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 13),
                                          elevation: 0,
                                        ),
                                        onPressed: isAvailable
                                            ? () => _openChat(data, doc.id, isAvailable)
                                            : null,
                                        icon: Icon(
                                            isAvailable
                                                ? Icons.chat_bubble_outline
                                                : Icons.block,
                                            size: 18),
                                        label: Text(
                                          isAvailable
                                              ? 'تواصل مع الخبير'
                                              : 'غير متاح حالياً',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold),
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

  // Listens to the user's chats in real time, sorts them by latest update, and shows a filtered list
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

        final activeCount = allChats
            .where((d) =>
        (d.data() as Map<String, dynamic>)['completed'] != true)
            .length;
        final completedCount = allChats
            .where((d) =>
        (d.data() as Map<String, dynamic>)['completed'] == true)
            .length;

        List<QueryDocumentSnapshot> filtered = allChats.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final matchSearch = (data['specialistName'] ?? '')
              .toString()
              .toLowerCase()
              .contains(_searchText.toLowerCase());
          bool matchFilter = true;
          if (_chatFilter == 'pending') {
            matchFilter = data['completed'] != true;
          } else if (_chatFilter == 'completed') {
            matchFilter = data['completed'] == true;
          }
          return matchSearch && matchFilter;
        }).toList();

        filtered.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;

          DateTime parseTime(dynamic timeVal) {
            if (timeVal is Timestamp) return timeVal.toDate();
            if (timeVal is String && timeVal.isNotEmpty) {
              return DateTime.tryParse(timeVal) ?? DateTime(2000);
            }
            return DateTime(2000);
          }

          final timeA = parseTime(dataA['updatedAt'] ?? dataA['createdAt']);
          final timeB = parseTime(dataB['updatedAt'] ?? dataB['createdAt']);
          return timeB.compareTo(timeA);
        });

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: Row(
                  children: [
                    _availChip(
                      'الكل (${allChats.length})',
                      _chatFilter == 'all',
                          () => setState(() => _chatFilter = 'all'),
                      activeColor: const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 8),
                    _availChip(
                      'جارية ($activeCount)',
                      _chatFilter == 'pending',
                          () => setState(() => _chatFilter = 'pending'),
                      activeColor: const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 8),
                    _availChip(
                      'مكتملة ($completedCount)',
                      _chatFilter == 'completed',
                          () => setState(() => _chatFilter = 'completed'),
                      activeColor: const Color(0xFF16A34A),
                    ),
                  ],
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
                        Icon(Icons.chat_bubble_outline,
                            size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        const Text('لا توجد دردشات بعد',
                            style: TextStyle(color: Colors.grey, fontSize: 15)),
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
                      final data =
                      filtered[index].data() as Map<String, dynamic>;
                      final chatId = filtered[index].id;
                      final expertName = data['specialistName'] ?? '';
                      final lastMsg = data['lastMessage'] ?? '';
                      final time = data['time'] ?? '';
                      final unread = data['userUnread'] ?? 0;
                      final isCompleted = data['completed'] == true;

                      return GestureDetector(
                        onTap: () {
                          FirebaseFirestore.instance
                              .collection('chats')
                              .doc(chatId)
                              .update({'userUnread': 0});
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatWithUserScreen(
                                chatId: chatId,
                                expertName: expertName,
                                expertRating:
                                (data['expertRating'] ?? 0).toDouble(),
                                isOnline: data['online'] == true,
                              ),
                            ),
                          );
                        },
                        onLongPress: () =>
                            _confirmDeleteChat(chatId, expertName),
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
                                  style: const TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
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
                                          child: Text(expertName,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isCompleted
                                                ? const Color(0xFF16A34A)
                                                : Colors.orange,
                                            borderRadius:
                                            BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            isCompleted ? 'مكتملة' : 'جارية',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10),
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
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600]),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(time,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[400])),
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
                                  child: Text('$unread',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 11)),
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

  // A filter chip that highlights when active — used to filter by availability or chat status
  Widget _availChip(String label, bool isActive, VoidCallback onTap,
      {required Color activeColor}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? activeColor : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[700],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // A lighter styled filter chip used for secondary filtering options
  Widget _filterChip(String label, bool isSelected, VoidCallback onTap,
      {Color activeColor = const Color(0xFF16A34A)}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? activeColor : Colors.grey[300]!),
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