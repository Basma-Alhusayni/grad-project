import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../theme/app_theme.dart';
import 'chat_with_user_screen.dart';

class ExpertSelectionScreen extends StatelessWidget {
  final String? failedImage;

  const ExpertSelectionScreen({super.key, this.failedImage});

  /// Logic to filter specialists by checking the 'expertSchedules' collection
  Future<List<QueryDocumentSnapshot>> _getAvailableExperts() async {
    // Note: This date matches your Firestore format "yyyy-MM-dd"
    final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final specialistsSnapshot =
    await FirebaseFirestore.instance.collection('specialists').get();

    List<QueryDocumentSnapshot> availableExperts = [];

    for (var doc in specialistsSnapshot.docs) {
      final scheduleDoc = await FirebaseFirestore.instance
          .collection('expertSchedules')
          .doc(doc.id)
          .get();

      if (scheduleDoc.exists) {
        final scheduleData = scheduleDoc.data() as Map<String, dynamic>;

        if (scheduleData.containsKey(todayDate)) {
          final dayData = scheduleData[todayDate] as Map<String, dynamic>;
          // Show only if isAvailable is true for today
          if (dayData['isAvailable'] == true) {
            availableExperts.add(doc);
          }
        }
      }
    }
    return availableExperts;
  }

  @override
  Widget build(BuildContext context) {
    // Explicitly using the material TextDirection to avoid ambiguous import errors
    const TextDirection rtlDirection = TextDirection.rtl;

    return Directionality(
      textDirection: rtlDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('خبراء متاحون الآن'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.darkGreen,
        ),
        body: FutureBuilder<List<QueryDocumentSnapshot>>(
          future: _getAvailableExperts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              );
            }

            if (snapshot.hasError) {
              return const Center(child: Text('حدث خطأ أثناء تحميل الخبراء'));
            }

            final docs = snapshot.data ?? [];

            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('👨‍🌾', style: TextStyle(fontSize: 60)),
                    const SizedBox(height: 16),
                    const Text(
                      'لا يوجد خبراء متاحون حالياً',
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'يرجى المحاولة مرة أخرى لاحقاً',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final String name = data['fullName'] ?? 'خبير';
                final String certificates = data['certificates'] ?? 'متخصص زراعي';
                final String rating = (data['rating'] ?? 0).toString();
                final String reviewCount = (data['reviewCount'] ?? 0).toString();
                final String specialistId = docs[index].id;

                return Card(
                  key: ValueKey(specialistId),
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('👨‍🌾', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                    title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                            'التخصص: $certificates',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                            Text(' $rating ', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('($reviewCount تقييم)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 18,
                        color: AppTheme.primaryGreen
                    ),
                    onTap: () => _showDetailsPopup(context, data, specialistId),
                  ),
                ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1, curve: Curves.easeOut);
              },
            );
          },
        ),
      ),
    );
  }

  void _showDetailsPopup(BuildContext context, Map<String, dynamic> data, String specialistId) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👨‍🌾', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              Text(
                  data['fullName'] ?? 'خبير',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkGreen)
              ),
              Text(
                  data['certificates'] ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 14)
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(),
              ),
              _detailItem(Icons.history_edu_rounded, 'الخبرة: ${data['experience'] ?? 'غير محدد'}'),
              _detailItem(Icons.email_outlined, data['email'] ?? ''),
              _detailItem(Icons.verified_user_rounded, 'خبير معتمد في التطبيق'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handleStartChat(context, data, specialistId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                      'بدء المحادثة الآن',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryGreen),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: Colors.black87))),
        ],
      ),
    );
  }

  Future<void> _handleStartChat(BuildContext context, Map<String, dynamic> data, String specialistId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String chatId = 'chat_${user.uid}_$specialistId';
    final now = DateTime.now();
    final String timeStr = DateFormat('HH:mm').format(now);

    List<Map<String, dynamic>> initialMessages = [];
    if (failedImage != null && failedImage!.isNotEmpty) {
      initialMessages.add({
        'id': 'msg_auto_${now.millisecondsSinceEpoch}',
        'sender': 'user',
        'content': failedImage,
        'time': timeStr,
        'type': 'image',
      });
    }

    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'userId': user.uid,
      'expertId': specialistId,
      'expertName': data['fullName'] ?? 'خبير',
      'lastMessage': failedImage != null ? '📷 صورة نبات للتشخيص' : 'بدأ المحادثة',
      'time': timeStr,
      'createdAt': FieldValue.serverTimestamp(),
      'messages': FieldValue.arrayUnion(initialMessages),
      'expertApproved': false,
    }, SetOptions(merge: true));

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatWithUserScreen(
            chatId: chatId,
            expertName: data['fullName'] ?? 'خبير',
            expertRating: double.tryParse(data['rating'].toString()) ?? 0.0,
          ),
        ),
      );
    }
  }
}