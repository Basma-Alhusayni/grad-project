import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpertChatScreen extends StatefulWidget {
  final String chatId;
  final String userName;
  final bool isOnline;

  const ExpertChatScreen({
    super.key,
    required this.chatId,
    required this.userName,
    required this.isOnline,
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
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _plantNameController.dispose();
    _diseaseController.dispose();
    _diagnosisController.dispose();
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
    });

    _scrollToBottom();
  }

  Future<void> _submitReport() async {
    final plantName = _plantNameController.text.trim();
    final disease = _diseaseController.text.trim();
    final diagnosis = _diagnosisController.text.trim();
    final treatment = _treatmentController.text.trim();

    if (plantName.isEmpty || disease.isEmpty ||
        diagnosis.isEmpty || treatment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء ملء جميع الحقول',
              textDirection: TextDirection.rtl),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _db.collection('reports').add({
      'chatId': widget.chatId,
      'userName': widget.userName,
      'plantName': plantName,
      'disease': disease,
      'diagnosis': diagnosis,
      'treatment': treatment,
      'date': DateTime.now().toIso8601String(),
      'status': 'solved',
    });

    _plantNameController.clear();
    _diseaseController.clear();
    _diagnosisController.clear();
    _treatmentController.clear();

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم إضافة التقرير',
              textDirection: TextDirection.rtl),
          backgroundColor: Colors.green[700],
        ),
      );
    }
  }

  void _openReportDialog() {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إضافة تقرير العلاج'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _reportField('اسم النبتة', 'مثال: نبات الطماطم',
                    _plantNameController),
                const SizedBox(height: 12),
                _reportField('المرض / الإصابة',
                    'مثال: تبقع الأوراق الفطري', _diseaseController),
                const SizedBox(height: 12),
                _reportField('التشخيص التفصيلي',
                    'اكتب التشخيص...', _diagnosisController,
                    maxLines: 3),
                const SizedBox(height: 12),
                _reportField('العلاج المقترح',
                    'اكتب خطة العلاج...', _treatmentController,
                    maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16a34a)),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('إضافة التقرير'),
              onPressed: _submitReport,
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportField(String label, String hint,
      TextEditingController ctrl,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            Expanded(child: _buildMessages()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 48, 8, 8),
      child: Column(
        children: [
          Row(
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
                  widget.userName.isNotEmpty ? widget.userName[0] : '؟',
                  style: const TextStyle(color: Color(0xFF15803d)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.userName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      widget.isOnline ? 'متصل الآن' : 'غير متصل',
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isOnline
                            ? Colors.green[600]
                            : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16a34a),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('تم العلاج - إضافة إلى التقارير'),
              onPressed: _openReportDialog,
            ),
          ),
        ],
      ),
    );
  }

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
            IconButton(
              icon: const Icon(Icons.attach_file,
                  color: Color(0xFF16a34a)),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.image_outlined,
                  color: Color(0xFF16a34a)),
              onPressed: () {},
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                textDirection: TextDirection.rtl,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالتك...',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                    const BorderSide(color: Color(0xFFbbf7d0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                    const BorderSide(color: Color(0xFFbbf7d0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                        color: Color(0xFF4ade80), width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFF16a34a),
                child: Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── فقاعة الرسالة للخبير ─────────────────────────────────────
class _ExpertMessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  const _ExpertMessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isExpert = msg['sender'] == 'expert';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment:
        isExpert ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isExpert
                ? const Color(0xFF16a34a)
                : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isExpert
                  ? const Radius.circular(4)
                  : const Radius.circular(16),
              bottomRight: isExpert
                  ? const Radius.circular(16)
                  : const Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg['content'] ?? '',
                style: TextStyle(
                    fontSize: 14,
                    color: isExpert ? Colors.white : Colors.grey[800]),
              ),
              const SizedBox(height: 2),
              Text(
                msg['time'] ?? '',
                style: TextStyle(
                    fontSize: 10,
                    color: isExpert
                        ? Colors.green[100]
                        : Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}