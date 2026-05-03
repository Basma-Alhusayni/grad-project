import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class ChatWithUserScreen extends StatefulWidget {
  final String chatId;
  final String expertName;
  final double expertRating;
  final bool isOnline;

  const ChatWithUserScreen({
    super.key,
    required this.chatId,
    required this.expertName,
    required this.expertRating,
    this.isOnline = false,
  });

  @override
  State<ChatWithUserScreen> createState() => _ChatWithUserScreenState();
}

class _ChatWithUserScreenState extends State<ChatWithUserScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _db = FirebaseFirestore.instance;
  final _picker = ImagePicker();

  bool _isApproved = false;
  bool _isCompleted = false;
  bool _hasRated = false;
  bool _ratingDialogShown = false;
  String _specialistId = '';
  int _previousMessageCount = 0;

  // Set up the chat listener when the screen opens
  @override
  void initState() {
    super.initState();
    _listenToChat();
  }

  // Clean up the message input and scroll controllers
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Listens to chat changes in real time — updates approval status, completion, and triggers the rating dialog if needed
  void _listenToChat() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    _db.collection('chats').doc(widget.chatId).snapshots().listen((snap) {
      if (snap.exists && mounted) {
        final data = snap.data() ?? {};

        final bool completed = data['completed'] == true;
        final List ratedBy = data['ratedBy'] ?? [];
        final bool alreadyRated = ratedBy.contains(uid);

        setState(() {
          _isApproved = data['expertApproved'] == true;
          _isCompleted = completed;
          _specialistId = data['specialistId'] ?? '';
          _hasRated = alreadyRated;

          if (alreadyRated) {
            _ratingDialogShown = true;
          }
        });

        final messages = (data['messages'] as List<dynamic>?) ?? [];
        final userSentMessage = messages.any((m) => m['sender'] == 'user');

        if (completed && !alreadyRated && userSentMessage && !_ratingDialogShown) {
          _ratingDialogShown = true;
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_hasRated) {
              _showRatingDialog();
            }
          });
        }
      }
    });
  }

  // Smoothly scrolls the message list to the latest message
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Returns the current time as a formatted string like "09:05"
  String _now() {
    final t = TimeOfDay.now();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  // Opens a full-screen zoomable view of an image (from URL or local file)
  void _showFullImage(String content) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: content.startsWith('http')
                    ? Image.network(content, fit: BoxFit.contain)
                    : File(content).existsSync()
                    ? Image.file(File(content), fit: BoxFit.contain)
                    : const SizedBox(),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sends the typed text message to Firestore and scrolls to the bottom
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final msg = {
      'id': 'msg-${DateTime.now().millisecondsSinceEpoch}',
      'sender': 'user',
      'content': text,
      'time': _now(),
      'type': 'text',
    };

    await _db.collection('chats').doc(widget.chatId).update({
      'messages': FieldValue.arrayUnion([msg]),
      'lastMessage': text,
      'time': _now(),
      'updatedAt': DateTime.now().toIso8601String(),
      'expertUnread': FieldValue.increment(1),
    });

    _scrollToBottom();
  }

  // Lets user pick an image from gallery, uploads it to Cloudinary, then sends it as a message
  Future<void> _sendImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF16A34A))),
    );

    String finalImageUrl = '';
    try {
      final cloudinary =
      CloudinaryPublic('dicojx5rg', 'bioshield_preset', cache: false);
      CloudinaryResponse response =
      await cloudinary.uploadFile(CloudinaryFile.fromFile(picked.path));
      finalImageUrl = response.secureUrl;
    } catch (e) {
      debugPrint('Upload failed: $e');
      Navigator.pop(context);
      return;
    }

    Navigator.pop(context);

    final msg = {
      'id': 'img-${DateTime.now().millisecondsSinceEpoch}',
      'sender': 'user',
      'content': finalImageUrl,
      'time': _now(),
      'type': 'image',
    };

    await _db.collection('chats').doc(widget.chatId).update({
      'messages': FieldValue.arrayUnion([msg]),
      'lastMessage': '📷 صورة',
      'time': _now(),
      'expertUnread': FieldValue.increment(1),
    });

    _scrollToBottom();
  }

  // Shows a dialog telling the user this report was blocked by the admin and cannot be shared
  void _showAdminBlockedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 20),
            SizedBox(width: 8),
            Text(
              'تعذّر المشاركة',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ]),
          content: const Text(
            'عذراً، لاحظ المشرف مشكلة في هذا التقرير لذلك لا يمكن مشاركته مع المجتمع.',
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('حسناً', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the case report card shown at the bottom of the chat after the specialist closes the case
  Widget _buildReportSection(Map<String, dynamic> report) {
    final bool isAdminBlocked = report['adminBlocked'] == true;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAdminBlocked
              ? const Color(0xFFDC2626).withOpacity(0.4)
              : const Color(0xFF16A34A),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment,
                    color: Color(0xFF16A34A), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'تقرير الحالة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ),
              if (isAdminBlocked)
                IconButton(
                  icon: const Icon(Icons.block, color: Colors.grey),
                  onPressed: _showAdminBlockedDialog,
                  tooltip: 'مشاركة مقيّدة',
                )
              else
                IconButton(
                  icon: Icon(
                    report['sharedToDashboard'] == true
                        ? Icons.public_off
                        : Icons.share,
                    color: report['sharedToDashboard'] == true
                        ? const Color(0xFF2D322C)
                        : const Color(0xFF16A34A),
                  ),
                  onPressed: () => report['sharedToDashboard'] == true
                      ? _unshareReportFromDashboard(report)
                      : _shareReportToDashboard(report),
                  tooltip: report['sharedToDashboard'] == true
                      ? 'إلغاء المشاركة'
                      : 'مشاركة التقرير',
                ),
            ],
          ),

          if (isAdminBlocked) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(children: [
                Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'لاحظ المشرف مشكلة في هذا التقرير لذلك لا يمكن مشاركته مع المجتمع',
                    style: TextStyle(
                        color: Color(0xFFDC2626), fontSize: 12, height: 1.4),
                  ),
                ),
              ]),
            ),
          ],

          const Divider(),
          if (report['plantImage'] != null &&
              report['plantImage'].isNotEmpty) ...[
            GestureDetector(
              onTap: () => _showFullImage(report['plantImage']),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  report['plantImage'],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildReportDetailRow(
              '🌿 اسم النبتة:', report['plantName'] ?? 'غير محدد'),
          const SizedBox(height: 8),
          _buildReportDetailRow(
              '🩺 التشخيص:', report['diagnosis'] ?? 'غير محدد'),
          const SizedBox(height: 8),
          _buildReportDetailRow(
              '💊 العلاج:', report['treatment'] ?? 'غير محدد'),
          const SizedBox(height: 8),
          _buildReportDetailRow('📅 التاريخ:', report['date'] ?? 'غير محدد'),
          if (report['sharedToDashboard'] == true)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.public, size: 14, color: Colors.blue),
                  SizedBox(width: 4),
                  Text('تمت المشاركة في لوحة التحكم',
                      style: TextStyle(fontSize: 11, color: Colors.blue)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // A single row showing a label and its value inside the report card
  Widget _buildReportDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

// Shares the specialist report to the community feed and marks it as shared in Firestore
  Future<void> _shareReportToDashboard(Map<String, dynamic> report) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (report['sharedToDashboard'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا التقرير تمت مشاركته بالفعل')),
      );
      return;
    }

    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      final userName = userDoc.data()?['fullName'] ??
          userDoc.data()?['username'] ??
          'مستخدم';

      final currentYear = DateTime.now().year;
      final diagnosis = report['diagnosis'] ?? '';
      final isHealthy = diagnosis.contains('سليم') ||
          diagnosis.contains('healthy') ||
          diagnosis.contains('طازج');
      final finalStatus = report['status'] ?? (isHealthy ? 'سليم' : 'مريض');

      final sharedData = {
        'plantName': report['plantName'],
        'ImageUrl': report['plantImage'],
        'diagnosis': report['diagnosis'],
        'treatment': report['treatment'],
        'status': finalStatus,
        'date': report['date'],
        'createdAt': FieldValue.serverTimestamp(),
        'sharedBy': userName,
        'userId': uid,
        'chatId': widget.chatId,
        'reportId': report['reportId'],
        'specialistName': widget.expertName,
        'isSpecialistReport': true,
        'reportType': 'specialist',
        'copyright':
        '© $currentYear BioShield - تقرير معتمد من الخبير ${widget.expertName}',
      };

      await _db.collection('community_feed').add(sharedData);

      await _db.collection('chats').doc(widget.chatId).update({
        'report.sharedToDashboard': true,
      });

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ تم مشاركة التقرير في لوحة التحكم'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    }
  }

// Removes the report from the community feed and marks it as unshared
  Future<void> _unshareReportFromDashboard(Map<String, dynamic> report) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final communityFeedQuery = await _db
          .collection('community_feed')
          .where('chatId', isEqualTo: widget.chatId)
          .where('userId', isEqualTo: uid)
          .get();

      for (var doc in communityFeedQuery.docs) {
        await doc.reference.delete();
      }

      await _db.collection('chats').doc(widget.chatId).update({
        'report.sharedToDashboard': false,
      });

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ تم إلغاء مشاركة التقرير'),
          backgroundColor: Color(0xFF2D322C),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    }
  }

  // Shows a dialog with 5 stars and an optional comment so the user can rate the specialist
  void _showRatingDialog() {
    int selectedRating = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(20),
            title: const Text(
              'قيّم الخبير',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFFDDF7DD),
                    child: Text(
                      widget.expertName.isNotEmpty
                          ? widget.expertName[0]
                          : 'خ',
                      style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                          fontSize: 24),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(widget.expertName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text(
                    'كيف كانت تجربتك مع هذا الخبير؟',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedRating = star),
                        child: Padding(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            star <= selectedRating
                                ? Icons.star
                                : Icons.star_border,
                            color: star <= selectedRating
                                ? Colors.amber
                                : Colors.grey[400],
                            size: 36,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selectedRating == 0
                        ? 'اضغط لتحديد التقييم'
                        : selectedRating == 1
                        ? 'سيء'
                        : selectedRating == 2
                        ? 'مقبول'
                        : selectedRating == 3
                        ? 'جيد'
                        : selectedRating == 4
                        ? 'جيد جداً'
                        : 'ممتاز!',
                    style: TextStyle(
                      fontSize: 13,
                      color: selectedRating == 0
                          ? Colors.grey
                          : Colors.amber[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'اكتب تعليقك (اختياري)...',
                      hintStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('تخطي'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedRating > 0
                              ? const Color(0xFF16a34a)
                              : Colors.grey[300],
                          foregroundColor: selectedRating > 0
                              ? Colors.white
                              : Colors.grey,
                        ),
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('إرسال التقييم'),
                        onPressed: selectedRating > 0
                            ? () => _submitRating(
                            selectedRating,
                            commentController.text.trim())
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Saves the rating and comment, recalculates the specialist's average rating, and marks the chat as rated
  Future<void> _submitRating(int rating, String comment) async {
    if (_specialistId.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    String realUserName = 'مستخدم';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        realUserName = userDoc.data()?['fullName'] ??
            userDoc.data()?['username'] ??
            'مستخدم';
      }
    } catch (e) {
      debugPrint('Error fetching name for rating: $e');
    }

    final now = DateTime.now();

    await _db
        .collection('specialists')
        .doc(_specialistId)
        .collection('reviews')
        .add({
      'userId': uid,
      'userName': realUserName,
      'rating': rating,
      'comment': comment,
      'chatId': widget.chatId,
      'date': '${now.day}/${now.month}/${now.year}',
      'createdAt': now.toIso8601String(),
    });

    final specDoc =
    await _db.collection('specialists').doc(_specialistId).get();
    final specData = specDoc.data() ?? {};
    final currentRating = ((specData['rating'] ?? 0) as num).toDouble();
    final reviewCount = (specData['reviewCount'] ?? 0) as int;

    final newCount = reviewCount + 1;
    final newRating = ((currentRating * reviewCount) + rating) / newCount;

    await _db.collection('specialists').doc(_specialistId).update({
      'rating': double.parse(newRating.toStringAsFixed(1)),
      'reviewCount': newCount,
    });

    await _db.collection('chats').doc(widget.chatId).update({
      'ratedBy': FieldValue.arrayUnion([uid]),
    });

    if (mounted) {
      Navigator.of(context).pop();
      setState(() => _hasRated = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⭐ شكراً! تم إرسال تقييمك للخبير ${widget.expertName}',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: Colors.green[700],
        ),
      );
    }
  }

  // Builds the full chat screen: header, banners, message list, and input bar
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0FDF4),
        body: Column(
          children: [
            _buildHeader(),
            if (!_isApproved) _buildPendingBanner(),
            if (_isCompleted) _buildCompletedBanner(),
            Expanded(child: _buildMessages()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // A banner shown when the specialist hasn't approved the chat yet
  Widget _buildPendingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFFFFF7ED),
      child: const Row(
        children: [
          Icon(Icons.access_time, color: Colors.orange, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'رسائلك محفوظة — في انتظار موافقة الخبير لعرضها',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  // A banner shown when the case is closed — includes the rate button if the user hasn't rated yet
  Widget _buildCompletedBanner() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('chats').doc(widget.chatId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final messages = (data?['messages'] as List<dynamic>?) ?? [];
        final userSentMessage = messages.any((m) => m['sender'] == 'user');

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: const Color(0xFFF0FDF4),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF16a34a), size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    '✅ تم إغلاق هذه الحالة بنجاح',
                    style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF16a34a),
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (userSentMessage) ...[
                if (!_hasRated) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.star, size: 18),
                      label: const Text('قيّم الخبير',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      onPressed: _showRatingDialog,
                    ),
                  ),
                ] else
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        SizedBox(width: 4),
                        Text('شكراً! تم إرسال تقييمك',
                            style:
                            TextStyle(fontSize: 12, color: Colors.amber)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Builds the top bar with the expert's name, online status, rating, and case status badge
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 48, 8, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_forward, color: Color(0xFF15803d)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFdcfce7),
            child: Text(
              widget.expertName.isNotEmpty ? widget.expertName[0] : 'خ',
              style: const TextStyle(color: Color(0xFF15803d)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.expertName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (_specialistId.isNotEmpty)
                      StreamBuilder<DocumentSnapshot>(
                        stream: _db
                            .collection('specialists')
                            .doc(_specialistId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final data =
                          snapshot.data?.data() as Map<String, dynamic>?;
                          final isOnline = data?['isOnline'] == true;
                          final liveRating =
                          data != null && data['rating'] != null
                              ? (data['rating'] as num).toDouble()
                              : widget.expertRating;

                          return Row(
                            children: [
                              if (isOnline) ...[
                                const Icon(Icons.circle,
                                    color: Color(0xFF16A34A), size: 8),
                                const SizedBox(width: 4),
                                const Text('متصل الآن',
                                    style: TextStyle(
                                        color: Color(0xFF16A34A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                              ],
                              const Icon(Icons.star,
                                  size: 13, color: Colors.amber),
                              const SizedBox(width: 3),
                              Text('$liveRating',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              const SizedBox(width: 8),
                            ],
                          );
                        },
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 13, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text('${widget.expertRating}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: 8),
                        ],
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isCompleted
                            ? const Color(0xFF16a34a)
                            : const Color(0xFF2D322C),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _isCompleted ? 'مكتملة' : 'جارية',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.workspace_premium,
              color: Color(0xFF16a34a), size: 22),
        ],
      ),
    );
  }

  // Listens to messages in real time and builds the scrollable message list, including the report card if the case is closed
  Widget _buildMessages() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('chats').doc(widget.chatId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final rawMessages = data?['messages'] as List<dynamic>? ?? [];
        final report = data?['report'] as Map<String, dynamic>?;

        if (rawMessages.length > _previousMessageCount) {
          _previousMessageCount = rawMessages.length;
          _scrollToBottom();
        }

        if (rawMessages.isEmpty && report == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 60, color: Colors.grey[300]),
                const SizedBox(height: 12),
                const Text('ابدأ المحادثة مع الخبير',
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          );
        }

        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
          children: [
            ...List.generate(rawMessages.length, (index) {
              final msg = Map<String, dynamic>.from(rawMessages[index]);
              return _MessageBubble(
                msg: msg,
                onImageTap: _showFullImage,
              );
            }),
            if (_isCompleted && report != null)
              _buildReportSection(report),
          ],
        );
      },
    );
  }

  // Builds the bottom input bar with image picker and send button — hidden when the case is closed
  Widget _buildInputBar() {
    if (_isCompleted) return const SafeArea(top: false, child: SizedBox(height: 8));
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.image_outlined,
                    color: Color(0xFF16A34A)),
                onPressed: _sendImage,
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  textDirection: TextDirection.rtl,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'اكتب رسالتك...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final void Function(String) onImageTap;

  const _MessageBubble({required this.msg, required this.onImageTap});

  @override
  Widget build(BuildContext context) {
    final isUser = msg['sender'] == 'user';
    final isImage = msg['type'] == 'image';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding: isImage
              ? const EdgeInsets.all(4)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser ? const Color(0xFF16a34a) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isUser
                  ? const Radius.circular(16)
                  : const Radius.circular(4),
              bottomRight: isUser
                  ? const Radius.circular(4)
                  : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ],
          ),
          child: isImage
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  final content = msg['content'] ?? '';
                  if (content.isNotEmpty) onImageTap(content);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: File(msg['content'] ?? '').existsSync()
                      ? Image.file(File(msg['content']),
                      width: 200, height: 200, fit: BoxFit.cover)
                      : (msg['content'] ?? '').startsWith('http')
                      ? Image.network(msg['content'],
                      width: 200, height: 200, fit: BoxFit.cover)
                      : Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image,
                          color: Colors.grey, size: 40)),
                ),
              ),
              Padding(
                padding:
                const EdgeInsets.only(top: 4, right: 4, left: 4),
                child: Text(msg['time'] ?? '',
                    style: TextStyle(
                        fontSize: 10,
                        color: isUser
                            ? Colors.green[100]
                            : Colors.grey[400])),
              ),
            ],
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(msg['content'] ?? '',
                  style: TextStyle(
                      fontSize: 14,
                      color:
                      isUser ? Colors.white : Colors.grey[800])),
              const SizedBox(height: 3),
              Text(msg['time'] ?? '',
                  style: TextStyle(
                      fontSize: 10,
                      color: isUser
                          ? Colors.green[100]
                          : Colors.grey[400])),
            ],
          ),
        ),
      ),
    );
  }
}