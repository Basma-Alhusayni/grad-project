import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  String _specialistId = '';

  @override
  void initState() {
    super.initState();
    _listenToChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── مراقبة حالة الشات ─────────────────────────────────────
  void _listenToChat() {
    _db.collection('chats').doc(widget.chatId).snapshots().listen(
          (snap) {
        if (snap.exists && mounted) {
          final data = snap.data() ?? {};
          final approved = data['expertApproved'] == true;
          final completed = data['completed'] == true;
          final specId = data['specialistId'] ?? '';
          if (approved != _isApproved ||
              completed != _isCompleted ||
              specId != _specialistId) {
            setState(() {
              _isApproved = approved;
              _isCompleted = completed;
              _specialistId = specId;
            });
          }
        }
      },
    );

    // تحقق إذا اليوزر سبق وقيّم
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _db
        .collection('chats')
        .doc(widget.chatId)
        .get()
        .then((doc) {
      if (doc.exists) {
        final rated = (doc.data()?['ratedBy'] ?? []) as List;
        if (rated.contains(uid) && mounted) {
          setState(() => _hasRated = true);
        }
      }
    });
  }

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

  String _now() {
    final t = TimeOfDay.now();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

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
      'unread': FieldValue.increment(1),
    });

    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final msg = {
      'id': 'img-${DateTime.now().millisecondsSinceEpoch}',
      'sender': 'user',
      'content': picked.path,
      'time': _now(),
      'type': 'image',
    };

    await _db.collection('chats').doc(widget.chatId).update({
      'messages': FieldValue.arrayUnion([msg]),
      'lastMessage': '📷 صورة',
      'time': _now(),
      'unread': FieldValue.increment(1),
    });

    _scrollToBottom();
  }

  // ── ديالوج التقييم ─────────────────────────────────────────
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
            title: const Text(
              'قيّم الخبير',
              textAlign: TextAlign.center,
              style:
              TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // أفاتار الخبير
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
                Text(
                  widget.expertName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                const Text(
                  'كيف كانت تجربتك مع هذا الخبير؟',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // النجوم
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

                // تعليق
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
              ],
            ),
            actions: [
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
                  commentController.text.trim(),
                )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── إرسال التقييم ──────────────────────────────────────────
  Future<void> _submitRating(int rating, String comment) async {
    if (_specialistId.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final userName =
        FirebaseAuth.instance.currentUser?.displayName ?? 'مستخدم';
    final now = DateTime.now();

    // ١ — حفظ التقييم في sub-collection
    await _db
        .collection('specialists')
        .doc(_specialistId)
        .collection('reviews')
        .add({
      'userId': uid,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'chatId': widget.chatId,
      'date': '${now.day}/${now.month}/${now.year}',
      'createdAt': now.toIso8601String(),
    });

    // ٢ — تحديث متوسط التقييم في بروفايل الخبير
    final specDoc = await _db
        .collection('specialists')
        .doc(_specialistId)
        .get();
    final specData = specDoc.data() ?? {};
    final currentRating =
    ((specData['rating'] ?? 0) as num).toDouble();
    final reviewCount = (specData['reviewCount'] ?? 0) as int;

    final newCount = reviewCount + 1;
    final newRating =
        ((currentRating * reviewCount) + rating) / newCount;

    await _db.collection('specialists').doc(_specialistId).update({
      'rating': double.parse(newRating.toStringAsFixed(1)),
      'reviewCount': newCount,
    });

    // ٣ — علامة إن اليوزر قيّم
    await _db.collection('chats').doc(widget.chatId).update({
      'ratedBy': FieldValue.arrayUnion([uid]),
    });

    if (mounted) {
      Navigator.of(context).pop(); // أغلق الديالوج
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

  // ── بانر الانتظار ───────────────────────────────────────────
  Widget _buildPendingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFFFFF7ED),
      child: Row(
        children: [
          const Icon(Icons.access_time, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'رسائلك محفوظة — في انتظار موافقة الخبير لعرضها',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  // ── بانر المكتملة + زر التقييم ─────────────────────────────
  Widget _buildCompletedBanner() {
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
                label: const Text(
                  'قيّم الخبير',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
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
                      style: TextStyle(
                          fontSize: 12, color: Colors.amber)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── هيدر ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 48, 8, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_forward,
                color: Color(0xFF15803d)),
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
                Row(
                  children: [
                    const Icon(Icons.star, size: 13, color: Colors.amber),
                    const SizedBox(width: 3),
                    Text('${widget.expertRating}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isCompleted
                            ? const Color(0xFF16a34a)
                            : _isApproved
                            ? const Color(0xFF16a34a)
                            : Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _isCompleted
                            ? 'مكتملة'
                            : _isApproved
                            ? 'مقبول'
                            : 'قيد المراجعة',
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

  // ── الرسائل ─────────────────────────────────────────────────
  Widget _buildMessages() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('chats').doc(widget.chatId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final rawMessages = data?['messages'] as List<dynamic>? ?? [];

        _scrollToBottom();

        if (rawMessages.isEmpty) {
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

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(14),
          itemCount: rawMessages.length,
          itemBuilder: (context, index) {
            final msg = Map<String, dynamic>.from(rawMessages[index]);
            return _MessageBubble(msg: msg);
          },
        );
      },
    );
  }

  // ── شريط الإدخال ────────────────────────────────────────────
  Widget _buildInputBar() {
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
                  child: const Icon(Icons.send,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── فقاعة الرسالة ───────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg['sender'] == 'user';
    final isImage = msg['type'] == 'image';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment:
        isUser ? Alignment.centerRight : Alignment.centerLeft,
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
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: File(msg['content'] ?? '').existsSync()
                    ? Image.file(File(msg['content']),
                    width: 200, height: 200, fit: BoxFit.cover)
                    : (msg['content'] ?? '').startsWith('http')
                    ? Image.network(msg['content'],
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover)
                    : Container(
                    width: 200,
                    height: 200,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image,
                        color: Colors.grey, size: 40)),
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