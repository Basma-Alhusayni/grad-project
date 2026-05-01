import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cloudinary_public/cloudinary_public.dart';
import 'chat_with_user_screen.dart';

class ExpertSelectionScreen extends StatelessWidget {
  final String? failedImage;

  const ExpertSelectionScreen({super.key, this.failedImage});

  static const Color primaryGreen = Color(0xFF16A34A);
  static const Color darkGreen = Color(0xFF14532D);
  static const Color bgGreen = Color(0xFFF0FDF4);

  Future<List<QueryDocumentSnapshot>> _getAvailableExperts() async {
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    try {
      final specialists = await FirebaseFirestore.instance
          .collection('specialists')
          .get();
      List<QueryDocumentSnapshot> available = [];

      for (var doc in specialists.docs) {
        final sched = await FirebaseFirestore.instance
            .collection('expertSchedules')
            .doc(doc.id)
            .get();

        if (sched.exists) {
          final scheduleData = sched.data();
          final todayData = scheduleData?[todayKey];

          if (todayData != null && todayData['isAvailable'] == true) {
            try {
              final startParts = (todayData['startTime'] ?? '00:00').split(':');
              final endParts = (todayData['endTime'] ?? '23:59').split(':');

              final startTime = DateTime(
                now.year,
                now.month,
                now.day,
                int.parse(startParts[0]),
                int.parse(startParts[1]),
              );
              final endTime = DateTime(
                now.year,
                now.month,
                now.day,
                int.parse(endParts[0]),
                int.parse(endParts[1]),
              );

              if (now.isAfter(startTime) && now.isBefore(endTime)) {
                available.add(doc);
              }
            } catch (e) {
              debugPrint('⚠️ Error parsing time for expert ${doc.id}: $e');
            }
          }
        }
      }
      return available;
    } catch (e) {
      debugPrint('❌ Firestore Error: $e');
      return [];
    }
  }

  // ── Fetch certificate images ─────────────────────────────────
  Future<List<String>> _fetchCertificateImages(String docId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('specialists')
          .doc(docId)
          .get();
      final d = doc.data() ?? {};
      List<String> images = [];
      if (d['certificateImages'] is List) {
        images = (d['certificateImages'] as List)
            .map((e) => e.toString())
            .toList();
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
            images = (reqData['certificateImages'] as List)
                .map((e) => e.toString())
                .toList();
          }
        }
      }
      return images;
    } catch (e) {
      return [];
    }
  }

  // ── Fetch reviews ────────────────────────────────────────────
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

  // ── Fetch reports ────────────────────────────────────────────
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

  // ── Show full certificate image ──────────────────────────────
  void _showFullCertImage(BuildContext context, String url) {
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
                  const Text(
                    'معاينة الشهادة',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: darkGreen,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
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
                            child: CircularProgressIndicator(
                              color: primaryGreen,
                            ),
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
                            Icon(
                              Icons.broken_image,
                              color: Colors.red,
                              size: 48,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'تعذر تحميل الصورة',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgGreen,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          title: const Text(
            'الخبراء المتاحون',
            style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: primaryGreen),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: FutureBuilder<List<QueryDocumentSnapshot>>(
          future: _getAvailableExperts(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: primaryGreen),
              );
            }
            if (snap.hasError) {
              return Center(child: Text('حدث خطأ: ${snap.error}'));
            }
            final docs = snap.data ?? [];
            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'لا يوجد خبراء متاحين حالياً ضمن ساعات العمل',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                return _buildExpertCard(context, data, docs[i].id);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildExpertCard(
    BuildContext context,
    Map<String, dynamic> data,
    String id,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: () => _showExpertDetails(context, data, id),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: const Color(0xFFDCFCE7),
          child: Text(
            data['fullName']?[0] ?? 'خ',
            style: const TextStyle(
              color: primaryGreen,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        title: Text(
          data['fullName'] ?? 'خبير',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
            const SizedBox(width: 4),
            Text(
              '${data['rating'] ?? 5.0}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10),
            const Text(
              'متاح الآن',
              style: TextStyle(
                color: primaryGreen,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.grey,
        ),
      ),
    );
  }

  void _showExpertDetails(
    BuildContext context,
    Map<String, dynamic> data,
    String specId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.92,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),

                // ── Drag handle ──────────────────────────────────
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // ── Scrollable content ───────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Avatar + Name + Rating ───────────────
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: bgGreen,
                                child: Text(
                                  (data['fullName'] ?? 'خ')[0],
                                  style: const TextStyle(
                                    color: primaryGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                data['fullName'] ?? '',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // ── Stars + review count ─────────
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ...List.generate(
                                    5,
                                    (i) => Icon(
                                      i < ((data['rating'] ?? 0) as num).round()
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: const Color(0xFFF4B400),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${((data['rating'] ?? 0) as num).toStringAsFixed(1)} (${data['reviewCount'] ?? 0} تقييم)',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── About ────────────────────────────────
                        const Text(
                          'حول الخبير',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: darkGreen,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['experience'] ?? 'لا توجد معلومات إضافية',
                          style: const TextStyle(height: 1.5),
                        ),
                        const SizedBox(height: 20),

                        // ── Qualifications ───────────────────────
                        const Text(
                          'المؤهلات العلمية',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: darkGreen,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(data['certificates'] ?? '—'),
                        const SizedBox(height: 20),

                        // ── Certificate Images ───────────────────
                        const Text(
                          'الشهادات الموثقة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: darkGreen,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<List<String>>(
                          future: _fetchCertificateImages(specId),
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: primaryGreen,
                                  strokeWidth: 2,
                                ),
                              );
                            }
                            if (!snap.hasData || snap.data!.isEmpty) {
                              return const Text(
                                'لم يتم إرفاق صور شهادات',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              );
                            }
                            final images = snap.data!;
                            return SizedBox(
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: images.length,
                                itemBuilder: (_, i) => GestureDetector(
                                  onTap: () =>
                                      _showFullCertImage(context, images[i]),
                                  child: Container(
                                    width: 140,
                                    margin: const EdgeInsets.only(left: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            9,
                                          ),
                                          child: Image.network(
                                            images[i],
                                            fit: BoxFit.cover,
                                            loadingBuilder: (_, child, progress) {
                                              if (progress == null)
                                                return child;
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      color: primaryGreen,
                                                      strokeWidth: 2,
                                                    ),
                                              );
                                            },
                                            errorBuilder: (_, __, ___) =>
                                                const Center(
                                                  child: Icon(
                                                    Icons.broken_image,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                              horizontal: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                    bottom: Radius.circular(9),
                                                  ),
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black.withOpacity(0.5),
                                                ],
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'شهادة ${i + 1}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.zoom_in,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // ── Reviews ──────────────────────────────
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _fetchReviews(specId),
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: primaryGreen,
                                  strokeWidth: 2,
                                ),
                              );
                            }
                            if (!snap.hasData || snap.data!.isEmpty) {
                              return const SizedBox();
                            }
                            final reviews = snap.data!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'آراء المستخدمين',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: darkGreen,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${reviews.length} تقييم',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // ── fix: .toList() on the map ────
                                ...reviews.take(5).map((r) {
                                  final rRating = (r['rating'] ?? 5).toInt();
                                  final userName = r['userName'] ?? 'مستخدم';
                                  final comment = r['comment'] ?? '';
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: bgGreen,
                                              child: Text(
                                                userName.isNotEmpty
                                                    ? userName[0]
                                                    : 'م',
                                                style: const TextStyle(
                                                  color: primaryGreen,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    userName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  Row(
                                                    children: List.generate(
                                                      5,
                                                      (i) => Icon(
                                                        i < rRating
                                                            ? Icons.star
                                                            : Icons.star_border,
                                                        color: const Color(
                                                          0xFFF4B400,
                                                        ),
                                                        size: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (comment.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            comment,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(), // ← fix applied here
                                const SizedBox(height: 8),
                              ],
                            );
                          },
                        ),

                        // ── Recent Reports ────────────────────────
                        // ── Recent Reports ────────────────────────────────────────
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _fetchReports(specId),
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: primaryGreen,
                                  strokeWidth: 2,
                                ),
                              );
                            }
                            if (!snap.hasData || snap.data!.isEmpty) {
                              return const SizedBox();
                            }
                            final reports = snap.data!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'تقارير سابقة',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: darkGreen,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${reports.length} تقرير',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ...reports.take(3).map((r) {
                                  final hasImage = (r['plantImage'] ?? '')
                                      .toString()
                                      .isNotEmpty;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // ── Header ──────────────────────────────
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFF0FDF4,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Icon(
                                                  Icons.eco,
                                                  color: primaryGreen,
                                                  size: 20,
                                                ),
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
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                        color: darkGreen,
                                                      ),
                                                    ),
                                                    Text(
                                                      'المستخدم: ${r['userName'] ?? 'مستخدم'}',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                r['date'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // ── Plant Image ──────────────────────────
                                        if (hasImage) ...[
                                          ClipRRect(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.zero,
                                                ),
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

                                        // ── Diagnosis ────────────────────────────
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            0,
                                            12,
                                            8,
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0xFFE5E7EB),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'التشخيص:',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF374151),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  r['diagnosis'] ??
                                                      'لا يوجد تشخيص',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.black87,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // ── Treatment ────────────────────────────
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            0,
                                            12,
                                            12,
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFFBEB),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0xFFFDE68A),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'العلاج المقترح:',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFFD97706),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  r['treatment'] ??
                                                      'لا يوجد علاج مقترح',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.black87,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                const SizedBox(height: 8),
                              ],
                            );
                          },
                        ),

                        // ── Start Chat Button ────────────────────────────
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  _handleStartChat(context, data, specId);
                                },
                                icon: const Icon(
                                  Icons.chat_bubble_rounded,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'بدء استشارة مباشرة',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleStartChat(
    BuildContext context,
    Map<String, dynamic> data,
    String specId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: primaryGreen)),
    );

    try {
      String userName = 'مستخدم';
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        userName =
            userDoc.data()?['fullName'] ??
            userDoc.data()?['username'] ??
            'مستخدم';
      }

      String finalImageUrl = '';
      if (failedImage != null && failedImage!.isNotEmpty) {
        final cloudinary = CloudinaryPublic(
          'dicojx5rg',
          'bioshield_preset',
          cache: false,
        );
        CloudinaryResponse response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(failedImage!),
        );
        finalImageUrl = response.secureUrl;
      }

      final chatRef = FirebaseFirestore.instance.collection('chats').doc();
      final now = DateTime.now();
      final timeStr = DateFormat('HH:mm').format(now);

      await chatRef.set({
        'userId': user.uid,
        'userName': userName,
        'specialistId': specId,
        'specialistName': data['fullName'],
        'expertName': data['fullName'],
        'expertRating': data['rating'] ?? 5.0,
        'expertApproved': true,
        'completed': false,
        'plantImage': finalImageUrl,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'time': timeStr,
        'userUnread': 0,
        'expertUnread': 1,
        'lastMessage': finalImageUrl.isNotEmpty ? '📷 صورة' : 'محادثة جديدة',
        'messages': finalImageUrl.isNotEmpty
            ? [
                {
                  'id': 'img-${now.millisecondsSinceEpoch}',
                  'sender': 'user',
                  'content': finalImageUrl,
                  'type': 'image',
                  'time': timeStr,
                },
              ]
            : [],
      });

      if (context.mounted) {
        Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatWithUserScreen(
              chatId: chatRef.id,
              expertName: data['fullName'] ?? 'خبير',
              expertRating: ((data['rating'] ?? 5.0) as num).toDouble(),
              isOnline: true,
            ),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      debugPrint('❌ Error starting chat: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل بدء المحادثة: $e')));
    }
  }
}
