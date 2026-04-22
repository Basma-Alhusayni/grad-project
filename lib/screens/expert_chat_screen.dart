import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpertChatScreen extends StatefulWidget {
  final String chatId;
  final String userName;
  final String userId;

  const ExpertChatScreen({
    super.key,
    required this.chatId,
    required this.userName,
    required this.userId,
  });

  @override
  State<ExpertChatScreen> createState() => _ExpertChatScreenState();
}
class _ExpertChatScreenState extends State<ExpertChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _db = FirebaseFirestore.instance;

  final _plantNameController = TextEditingController();
  final _diseaseController = TextEditingController();
  final _treatmentController = TextEditingController();

  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _db.collection('chats').doc(widget.chatId).snapshots().listen((doc) {
      if (doc.exists && mounted) {
        setState(() {
          _isCompleted = doc.data()?['completed'] == true;
        });
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _plantNameController.dispose();
    _diseaseController.dispose();
    _treatmentController.dispose();
    super.dispose();
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
      'sender': 'expert',
      'content': text,
      'time': _now(),
      'type': 'text',
    };

    await _db.collection('chats').doc(widget.chatId).update({
      'messages': FieldValue.arrayUnion([msg]),
      'lastMessage': text,
      'time': _now(),
      'updatedAt': DateTime.now().toIso8601String(),
      'userUnread': FieldValue.increment(1), // ✅ Alerts the User
    });

    _scrollToBottom();
  }

  // --- End Chat & Report Logic ---
  // --- End Chat & Report Logic ---
  Future<void> _showEndChatDialog() async {
    // Fetch all messages from the chat to find images
    final chatDoc = await _db.collection('chats').doc(widget.chatId).get();
    final messages = (chatDoc.data()?['messages'] as List<dynamic>?) ?? [];

    // Extract only the images sent in the chat
    final List<String> chatImages = messages
        .where((m) => m['type'] == 'image')
        .map((m) => m['content'] as String)
        .toList();

    // If there was a plantImage attached to the chat creation, add it too
    final initialImage = chatDoc.data()?['plantImage'] as String?;
    if (initialImage != null && initialImage.isNotEmpty && !chatImages.contains(initialImage)) {
      chatImages.insert(0, initialImage);
    }

    String selectedImageUrl = chatImages.isNotEmpty ? chatImages.first : '';

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('إنهاء المحادثة وكتابة التقرير', style: TextStyle(color: Color(0xFF16A34A), fontSize: 16, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (chatImages.isNotEmpty) ...[
                    const Text('اختر الصورة المرفقة بالتقرير:',
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    // 🔥 FIX: Wrap this Container with a width to stop the crash
                    SizedBox(
                      width: 300, // Give it a fixed width so the Dialog knows how big to be
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: chatImages.length,
                        itemBuilder: (context, index) {
                          final imgUrl = chatImages[index];
                          final isSelected = selectedImageUrl == imgUrl;
                          return GestureDetector(
                            onTap: () => setDialogState(() => selectedImageUrl = imgUrl),
                            child: Container(
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: isSelected ? const Color(0xFF16A34A) : Colors.transparent,
                                    width: 3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(imgUrl, width: 70, height: 70, fit: BoxFit.cover),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _reportField('اسم النبتة', 'مثال: نبات الطماطم', _plantNameController),
                  const SizedBox(height: 12),
                  _reportField('التشخيص / المرض', 'اكتب التشخيص هنا...', _diseaseController, maxLines: 2),
                  const SizedBox(height: 12),
                  _reportField('العلاج المقترح', 'اكتب خطة العلاج...', _treatmentController, maxLines: 3),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16a34a)),
                icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                label: const Text('حفظ وإنهاء', style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  await _submitReport(selectedImageUrl);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReport(String imageUrl) async {
    final plantName = _plantNameController.text.trim();
    final diagnosis = _diseaseController.text.trim();
    final treatment = _treatmentController.text.trim();

    if (plantName.isEmpty || diagnosis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تعبئة اسم النبتة والتشخيص')));
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;

    // 1. Mark Chat as Complete (Locks chat for user and triggers rating)
    await _db.collection('chats').doc(widget.chatId).update({'completed': true});

    // 2. Save report to the new 'specialist_reports' collection
    if (uid != null) {
      await _db.collection('specialist_reports').add({
        'specialistId': uid,
        'chatId': widget.chatId,
        'userName': widget.userName,
        'plantName': plantName,
        'diagnosis': diagnosis,
        'treatment': treatment,
        'plantImage': imageUrl,
        'date': '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update the total cases handled by the expert in their profile
      await _db.collection('specialists').doc(uid).update({
        'totalCases': FieldValue.increment(1)
      });
    }

    if (mounted) {
      Navigator.pop(context); // Close dialog
      Navigator.pop(context); // Leave chat screen
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنهاء المحادثة وحفظ التقرير بنجاح'), backgroundColor: Colors.green));
    }
  }

  Widget _reportField(String label, String hint, TextEditingController ctrl, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
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
            if (_isCompleted)
              Container(
                width: double.infinity,
                color: Colors.grey[200],
                padding: const EdgeInsets.all(8),
                child: const Text('تم إنهاء هذه المحادثة', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ),
            Expanded(child: _buildMessages()),
            if (!_isCompleted) _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 48, 8, 8),
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
              widget.userName.isNotEmpty ? widget.userName[0] : '؟',
              style: const TextStyle(color: Color(0xFF15803d)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    // 🔥 NEW: Real-time Online Stream using widget.userId
                    if (widget.userId.isNotEmpty)
                      StreamBuilder<DocumentSnapshot>(
                        stream: _db.collection('users').doc(widget.userId).snapshots(),
                        builder: (context, snapshot) {
                          final isOnline = snapshot.data?.data() != null
                              ? (snapshot.data!.data() as Map<String, dynamic>)['isOnline'] == true
                              : false;

                          if (isOnline) {
                            return const Row(
                              children: [
                                Icon(Icons.circle, color: Color(0xFF16A34A), size: 8),
                                SizedBox(width: 4),
                                Text('متصل الآن', style: TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.bold)),
                                SizedBox(width: 8),
                              ],
                            );
                          }
                          return const SizedBox.shrink(); // Empty space if offline
                        },
                      ),

                    // Chat Status
                    Text(
                      _isCompleted ? 'مكتملة' : 'محادثة جارية',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isCompleted ? Colors.grey : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // --- THE 3 DOT MENU ---
          if (!_isCompleted)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Color(0xFF15803d)),
              onSelected: (value) {
                if (value == 'complete') {
                  _showEndChatDialog();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'complete',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
                      SizedBox(width: 8),
                      Text('إنهاء المحادثة'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // _buildMessages() and _ExpertMessageBubble remain exactly the same...
  Widget _buildMessages() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('chats').doc(widget.chatId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final rawMessages = data?['messages'] as List<dynamic>? ?? [];
        _scrollToBottom();
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: rawMessages.length,
          itemBuilder: (context, index) {
            final msg = Map<String, dynamic>.from(rawMessages[index]);
            return _ExpertMessageBubble(msg: msg);
          },
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textDirection: TextDirection.rtl,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالتك...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFbbf7d0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFbbf7d0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFF4ade80), width: 1.5)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: const CircleAvatar(radius: 22, backgroundColor: Color(0xFF16a34a), child: Icon(Icons.send, color: Colors.white, size: 20)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpertMessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  const _ExpertMessageBubble({required this.msg});
  @override
  Widget build(BuildContext context) {
    final isExpert = msg['sender'] == 'expert';
    final isImage = msg['type'] == 'image'; // Check if it's an image

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isExpert ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding: isImage ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isExpert ? const Color(0xFF16a34a) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: isImage
              ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(msg['content'], height: 200, width: 200, fit: BoxFit.cover),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(msg['content'] ?? '', style: TextStyle(fontSize: 14, color: isExpert ? Colors.white : Colors.grey[800])),
              const SizedBox(height: 2),
              Text(msg['time'] ?? '', style: TextStyle(fontSize: 10, color: isExpert ? Colors.green[100] : Colors.grey[400])),
            ],
          ),
        ),
      ),
    );
  }
}