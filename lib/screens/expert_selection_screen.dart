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

  // Theme Colors
  static const Color primaryGreen = Color(0xFF16A34A);
  static const Color darkGreen = Color(0xFF14532D);
  static const Color bgGreen = Color(0xFFF0FDF4);

  Future<List<QueryDocumentSnapshot>> _getAvailableExperts() async {
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    try {
      final specialists = await FirebaseFirestore.instance.collection('specialists').get();
      List<QueryDocumentSnapshot> available = [];

      for (var doc in specialists.docs) {
        final sched = await FirebaseFirestore.instance.collection('expertSchedules').doc(doc.id).get();

        if (sched.exists) {
          final scheduleData = sched.data();
          final todayData = scheduleData?[todayKey]; // 🔥 FIX: Properly access today's data

          if (todayData != null && todayData['isAvailable'] == true) {
            try {
              final startParts = (todayData['startTime'] ?? '00:00').split(':');
              final endParts = (todayData['endTime'] ?? '23:59').split(':');

              final startTime = DateTime(now.year, now.month, now.day, int.parse(startParts[0]), int.parse(startParts[1]));
              final endTime = DateTime(now.year, now.month, now.day, int.parse(endParts[0]), int.parse(endParts[1]));

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
          title: const Text('الخبراء المتاحون',
              style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: primaryGreen),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: FutureBuilder<List<QueryDocumentSnapshot>>(
          future: _getAvailableExperts(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primaryGreen));
            }
            if (snap.hasError) {
              return Center(child: Text('حدث خطأ: ${snap.error}'));
            }
            final docs = snap.data ?? [];
            if (docs.isEmpty) {
              return const Center(
                child: Text('لا يوجد خبراء متاحين حالياً ضمن ساعات العمل',
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
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

  Widget _buildExpertCard(BuildContext context, Map<String, dynamic> data, String id) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        onTap: () => _showExpertDetails(context, data, id),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: const Color(0xFFDCFCE7),
          child: Text(data['fullName']?[0] ?? 'خ',
              style: const TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        title: Text(data['fullName'] ?? 'خبير', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
            const SizedBox(width: 4),
            Text('${data['rating'] ?? 5.0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            const Text('متاح الآن', style: TextStyle(color: primaryGreen, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }

  void _showExpertDetails(BuildContext context, Map<String, dynamic> data, String specId) {
    showModalBottomSheet(
      context: context, // Outer screen context
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // 1. Rename the inner context to 'sheetContext'
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.85),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            const CircleAvatar(radius: 40, backgroundColor: bgGreen, child: Icon(Icons.person, size: 50, color: primaryGreen)),
                            const SizedBox(height: 12),
                            Text(data['fullName'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('حول الخبير', style: TextStyle(fontWeight: FontWeight.bold, color: darkGreen, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(data['experience'] ?? 'لا توجد معلومات إضافية', style: const TextStyle(height: 1.5)),
                      const SizedBox(height: 20),
                      const Text('المؤهلات العلمية', style: TextStyle(fontWeight: FontWeight.bold, color: darkGreen, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(data['certificates'] ?? '—'),
                      const SizedBox(height: 20),
                      const Text('الشهادات الموثقة', style: TextStyle(fontWeight: FontWeight.bold, color: darkGreen, fontSize: 16)),
                      const SizedBox(height: 12),
                      _buildCertGrid(data['certificateImages']),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // 2. Pop using the sheetContext
                        Navigator.pop(sheetContext);
                        // 3. Pass the original outer screen 'context' to start the chat
                        _handleStartChat(context, data, specId);
                      },
                      icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
                      label: const Text('بدء استشارة مباشرة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCertGrid(dynamic images) {
    final List certs = images is List ? images : [];
    if (certs.isEmpty) return const Text('لم يتم إرفاق صور شهادات', style: TextStyle(color: Colors.grey, fontSize: 12));
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: certs.length,
      itemBuilder: (ctx, i) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(certs[i], fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: Colors.grey[200])),
      ),
    );
  }

  Future<void> _handleStartChat(BuildContext context, Map<String, dynamic> data, String specId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show loading overlay
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: primaryGreen))
    );

    try {
      // 1. Fetch User Name
      String userName = 'مستخدم';
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        userName = userDoc.data()?['fullName'] ?? userDoc.data()?['username'] ?? 'مستخدم';
      }

      // 2. Upload Image to Cloudinary (If exists)
      String finalImageUrl = '';
      if (failedImage != null && failedImage!.isNotEmpty) {
        final cloudinary = CloudinaryPublic('dicojx5rg', 'bioshield_preset', cache: false);
        CloudinaryResponse response = await cloudinary.uploadFile(CloudinaryFile.fromFile(failedImage!));
        finalImageUrl = response.secureUrl;
      }

      // 3. Create Chat
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
        'messages': finalImageUrl.isNotEmpty ? [{
          'id': 'img-${now.millisecondsSinceEpoch}',
          'sender': 'user',
          'content': finalImageUrl,
          'type': 'image',
          'time': timeStr
        }] : [],
      });

      if (context.mounted) {
        Navigator.pop(context); // remove loading
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatWithUserScreen(
          chatId: chatRef.id,
          expertName: data['fullName'] ?? 'خبير',
          expertRating: ((data['rating'] ?? 5.0) as num).toDouble(),
          isOnline: true,
        )));
      }
    } catch (e) {
      Navigator.pop(context); // remove loading
      debugPrint('❌ Error starting chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل بدء المحادثة: $e')));
    }
  }
}