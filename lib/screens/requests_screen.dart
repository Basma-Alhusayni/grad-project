import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_with_user_screen.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  late TabController _tabController;

  bool _isAvailable = true;
  Map<String, dynamic>? _selectedRequest;
  Map<String, dynamic>? _requestToReject;
  final _rejectReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rejectReasonController.dispose();
    super.dispose();
  }

  // ── قبول الطلب ─────────────────────────────────────────────
  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    await _db.collection('requests').doc(request['id']).update({
      'status': 'accepted',
    });

    // إنشاء محادثة جديدة
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    await _db.collection('chats').add({
      'userId': request['userId'] ?? '',
      'userName': request['userName'] ?? '',
      'lastMessage': 'تم قبول طلبك',
      'time': timeStr,
      'online': false,
      'unread': 1,
      'requestId': request['id'],
      'createdAt': now.toIso8601String(),
      'messages': [
        {
          'id': 'msg-${now.millisecondsSinceEpoch}',
          'sender': 'expert',
          'content': 'مرحباً، تم قبول طلبك. كيف يمكنني مساعدتك؟',
          'time': timeStr,
          'type': 'text',
        },
        {
          'id': 'plant-${now.millisecondsSinceEpoch}',
          'sender': 'user',
          'content': '',
          'time': timeStr,
          'type': 'plant-info',
          'plantData': {
            'image': request['plantImage'] ?? '',
            'description': request['description'] ?? '',
            'aiDiagnosis': request['aiDiagnosis'] ?? '',
            'aiConfidence': request['aiConfidence'] ?? 0,
          },
        },
      ],
    });

    if (mounted) {
      setState(() => _selectedRequest = null);
      _showSnack('تم قبول الطلب وإنشاء محادثة مع المستخدم');
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatWithUserScreen(
              chatId: request['id'],
              userName: request['userName'] ?? '',
              isOnline: false,
            ),
          ),
        );
      }
    }
  }

  // ── رفض الطلب ──────────────────────────────────────────────
  Future<void> _rejectRequest(String requestId) async {
    final reason = _rejectReasonController.text.trim();
    await _db.collection('requests').doc(requestId).update({
      'status': 'rejected',
      'rejectionReason': reason,
    });

    _rejectReasonController.clear();
    if (mounted) {
      Navigator.of(context).pop(); // close reject dialog
      setState(() {
        _selectedRequest = null;
        _requestToReject = null;
      });
      _showSnack('تم رفض الطلب', isInfo: true);
    }
  }

  void _showSnack(String msg, {bool isInfo = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, textDirection: TextDirection.rtl),
      backgroundColor:
      isInfo ? Colors.blueGrey[600] : Colors.green[700],
    ));
  }

  // ── ديالوج تفاصيل الطلب ────────────────────────────────────
  void _showRequestDetails(Map<String, dynamic> request) {
    setState(() => _selectedRequest = request);
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تفاصيل الطلب'),
          contentPadding: const EdgeInsets.all(16),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // معلومات المستخدم
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFdcfce7),
                      child: Text(
                        (request['userName'] as String? ?? '').isNotEmpty
                            ? request['userName'][0]
                            : '؟',
                        style: const TextStyle(
                            color: Color(0xFF15803d), fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(request['userName'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Text(request['date'] ?? '',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // صورة النبات
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: (request['plantImage'] ?? '').isNotEmpty
                      ? Image.network(request['plantImage'],
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _imgPlaceholder(180))
                      : _imgPlaceholder(180),
                ),
                const SizedBox(height: 12),

                // الوصف
                const Text('الوصف:',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(request['description'] ?? '',
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 12),

                // تحليل AI
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    border:
                    Border.all(color: const Color(0xFFFDE68A)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تحليل الذكاء الاصطناعي:',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                          'التشخيص: ${request['aiDiagnosis'] ?? ''}',
                          style: const TextStyle(fontSize: 13)),
                      Text(
                          'مستوى الثقة: ${request['aiConfidence'] ?? 0}%',
                          style: const TextStyle(fontSize: 13)),
                      if ((request['aiConfidence'] ?? 0) < 60)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                              '⚠️ دقة منخفضة - يحتاج مراجعة خبير',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange)),
                        ),
                    ],
                  ),
                ),

                // سبب الرفض إن وجد
                if (request['status'] == 'rejected' &&
                    (request['rejectionReason'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      border: Border.all(
                          color: const Color(0xFFFCA5A5)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('سبب الرفض:',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                        const SizedBox(height: 4),
                        Text(request['rejectionReason'],
                            style: const TextStyle(
                                fontSize: 13, color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: request['status'] == 'pending'
              ? [
            TextButton.icon(
              style: TextButton.styleFrom(
                  foregroundColor: Colors.red),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('رفض الطلب'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _requestToReject = request);
                _showRejectDialog(request);
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16a34a)),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('قبول الطلب'),
              onPressed: () {
                Navigator.of(context).pop();
                _acceptRequest(request);
              },
            ),
          ]
              : [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  // ── ديالوج الرفض ───────────────────────────────────────────
  void _showRejectDialog(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رفض الطلب'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFdcfce7),
                      child: Text(
                        (request['userName'] as String? ?? '').isNotEmpty
                            ? request['userName'][0]
                            : '؟',
                        style: const TextStyle(
                            color: Color(0xFF15803d), fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(request['userName'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        Text(request['date'] ?? '',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500])),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: (request['plantImage'] ?? '').isNotEmpty
                      ? Image.network(request['plantImage'],
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _imgPlaceholder(150))
                      : _imgPlaceholder(150),
                ),
                const SizedBox(height: 10),
                Text(request['description'] ?? '',
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    border:
                    Border.all(color: const Color(0xFFFDE68A)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تحليل الذكاء الاصطناعي:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                      Text(
                          'التشخيص: ${request['aiDiagnosis'] ?? ''}',
                          style: const TextStyle(fontSize: 12)),
                      Text(
                          'مستوى الثقة: ${request['aiConfidence'] ?? 0}%',
                          style: const TextStyle(fontSize: 12)),
                      if ((request['aiConfidence'] ?? 0) < 60)
                        const Text(
                            '⚠️ دقة منخفضة - يحتاج مراجعة خبير',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('سبب الرفض:',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _rejectReasonController,
                  maxLines: 3,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'أدخل سبب رفض الطلب هنا...',
                    hintStyle: const TextStyle(fontSize: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              style:
              TextButton.styleFrom(foregroundColor: Colors.red),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('إلغاء'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16a34a)),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('رفض الطلب'),
              onPressed: () => _rejectRequest(request['id']),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0FDF4),
        body: StreamBuilder<QuerySnapshot>(
          stream: _db.collection('requests').snapshots(),
          builder: (context, snapshot) {
            final allRequests = snapshot.data?.docs
                .map((d) => {
              'id': d.id,
              ...d.data() as Map<String, dynamic>
            })
                .toList() ??
                [];

            final pending = allRequests
                .where((r) => r['status'] == 'pending')
                .toList();
            final accepted = allRequests
                .where((r) => r['status'] == 'accepted')
                .toList();
            final rejected = allRequests
                .where((r) => r['status'] == 'rejected')
                .toList();

            return Column(
              children: [
                // ── التوفر والإحصائيات ──────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    children: [
                      // سويتش التوفر
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.circle,
                                    size: 12,
                                    color: _isAvailable
                                        ? Colors.green
                                        : Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  _isAvailable
                                      ? 'متاح لاستقبال الطلبات'
                                      : 'غير متاح حالياً',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            Switch(
                              value: _isAvailable,
                              activeColor: const Color(0xFF16a34a),
                              onChanged: (v) =>
                                  setState(() => _isAvailable = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // إحصائيات
                      Row(
                        children: [
                          _StatCard(
                              '${pending.length}',
                              'قيد المراجعة',
                              Colors.orange),
                          const SizedBox(width: 8),
                          _StatCard('${accepted.length}', 'مقبولة',
                              Colors.green),
                          const SizedBox(width: 8),
                          _StatCard('${rejected.length}', 'مرفوضة',
                              Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // عنوان + badge
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('طلبات الاستشارة',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF166534))),
                          if (pending.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius:
                                BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${pending.length} جديد',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // تابز
                      TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF16a34a),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFF16a34a),
                        labelStyle: const TextStyle(fontSize: 12),
                        tabs: const [
                          Tab(text: 'قيد المراجعة'),
                          Tab(text: 'مقبولة'),
                          Tab(text: 'مرفوضة'),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── قائمة الطلبات ─────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _RequestList(
                          requests: pending,
                          onTap: _showRequestDetails,
                          onAccept: _acceptRequest,
                          onReject: (r) {
                            setState(() => _requestToReject = r);
                            _showRejectDialog(r);
                          }),
                      _RequestList(
                          requests: accepted,
                          onTap: _showRequestDetails),
                      _RequestList(
                          requests: rejected,
                          onTap: _showRequestDetails),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _imgPlaceholder(double h) => Container(
    height: h,
    width: double.infinity,
    color: Colors.grey[200],
    child:
    const Icon(Icons.image, size: 40, color: Colors.grey),
  );
}

// ─── إحصائية ─────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final MaterialColor color;

  const _StatCard(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.shade50,
          border: Border.all(color: color.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color.shade700)),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: color.shade600)),
          ],
        ),
      ),
    );
  }
}

// ─── قائمة الطلبات ───────────────────────────────────────────
class _RequestList extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final void Function(Map<String, dynamic>) onTap;
  final void Function(Map<String, dynamic>)? onAccept;
  final void Function(Map<String, dynamic>)? onReject;

  const _RequestList({
    required this.requests,
    required this.onTap,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(
        child: Text('لا توجد طلبات',
            style: TextStyle(color: Colors.grey, fontSize: 15)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final confidence = req['aiConfidence'] ?? 0;

        return GestureDetector(
          onTap: () => onTap(req),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFbbf7d0)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFdcfce7),
                    child: Text(
                      (req['userName'] as String? ?? '').isNotEmpty
                          ? req['userName'][0]
                          : '؟',
                      style: const TextStyle(
                          color: Color(0xFF15803d), fontSize: 17),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(req['userName'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: confidence < 50
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFFEF9C3),
                                borderRadius:
                                BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$confidence% دقة AI',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: confidence < 50
                                        ? Colors.red[700]
                                        : Colors.yellow[800]),
                              ),
                            ),
                          ],
                        ),
                        Text(req['date'] ?? '',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500])),
                        const SizedBox(height: 6),

                        // صورة النبات
                        if ((req['plantImage'] ?? '').isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              req['plantImage'],
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(
                                    height: 120,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.image,
                                        color: Colors.grey),
                                  ),
                            ),
                          ),
                        const SizedBox(height: 6),

                        Text(req['description'] ?? '',
                            style: const TextStyle(
                                fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(
                          'تشخيص AI: ${req['aiDiagnosis'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.amber),
                        ),

                        // أزرار القبول والرفض
                        if (req['status'] == 'pending' &&
                            onAccept != null &&
                            onReject != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(
                                        color: Colors.red),
                                    padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 6),
                                  ),
                                  icon: const Icon(Icons.close,
                                      size: 14),
                                  label: const Text('رفض',
                                      style:
                                      TextStyle(fontSize: 13)),
                                  onPressed: () => onReject!(req),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                    const Color(0xFF16a34a),
                                    padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 6),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.check,
                                      size: 14),
                                  label: const Text('قبول',
                                      style:
                                      TextStyle(fontSize: 13)),
                                  onPressed: () => onAccept!(req),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}