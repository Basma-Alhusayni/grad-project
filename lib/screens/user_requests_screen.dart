import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRequestsScreen extends StatefulWidget {
  const UserRequestsScreen({super.key});

  @override
  State<UserRequestsScreen> createState() => _UserRequestsScreenState();
}

class _UserRequestsScreenState extends State<UserRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _selectedRequest;
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── فلترة الطلبات ──────────────────────────────────────────
  List<Map<String, dynamic>> _filter(
      List<Map<String, dynamic>> all, int tabIndex) {
    switch (tabIndex) {
      case 0:
        return all;
      case 1:
        return all.where((r) => r['status'] == 'pending').toList();
      case 2:
        return all.where((r) => r['status'] == 'accepted').toList();
      case 3:
        return all.where((r) => r['status'] == 'rejected').toList();
      default:
        return all;
    }
  }

  // ── badge الحالة ────────────────────────────────────────────
  Widget _statusBadge(String status) {
    switch (status) {
      case 'pending':
        return _badge(Icons.access_time, 'قيد المراجعة',
            Colors.orange, const Color(0xFFFFF7ED));
      case 'accepted':
        return _badge(Icons.check_circle_outline, 'مقبول',
            Colors.green, const Color(0xFFF0FDF4));
      case 'rejected':
        return _badge(Icons.cancel_outlined, 'مرفوض',
            Colors.red, const Color(0xFFFEF2F2));
      default:
        return const SizedBox();
    }
  }

  Widget _badge(
      IconData icon, String label, MaterialColor color, Color bg) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: color.shade300),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.shade700),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color.shade700)),
        ],
      ),
    );
  }

  // ── ديالوج التفاصيل ────────────────────────────────────────
  void _showDetails(Map<String, dynamic> request) {
    setState(() => _selectedRequest = request);
    final status = request['status'] ?? '';

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
                // معلومات الخبير
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFdcfce7),
                      child: Text(
                        (request['specialistName'] as String? ?? 'خ')
                            .isNotEmpty
                            ? request['specialistName'][0]
                            : 'خ',
                        style: const TextStyle(
                            color: Color(0xFF15803d), fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              request['specialistName'] ?? 'خبير',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          Text(request['date'] ?? '',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    _statusBadge(status),
                  ],
                ),
                const SizedBox(height: 12),

                // صورة النبات
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: (request['plantImage'] ?? '').isNotEmpty
                      ? Image.network(
                    request['plantImage'],
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _imgPlaceholder(180),
                  )
                      : _imgPlaceholder(180),
                ),
                const SizedBox(height: 12),

                // وصف المشكلة
                const Text('وصف المشكلة:',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(request['description'] ?? '',
                      style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 12),

                // تحليل AI
                if ((request['aiDiagnosis'] ?? '').isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      border: Border.all(
                          color: const Color(0xFFFDE68A)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('تحليل الذكاء الاصطناعي:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        const SizedBox(height: 6),
                        Text(
                            'التشخيص: ${request['aiDiagnosis']}',
                            style:
                            const TextStyle(fontSize: 13)),
                        if (request['aiConfidence'] != null)
                          Text(
                              'مستوى الثقة: ${request['aiConfidence']}%',
                              style:
                              const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // كارد الحالة
                _statusCard(status, request['rejectionReason']),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(String status, String? rejectionReason) {
    if (status == 'pending') {
      return _infoCard(
        icon: Icons.access_time,
        title: 'طلبك قيد المراجعة',
        body: 'الخبير يقوم بمراجعة طلبك حالياً. سيتم إشعارك بالقرار قريباً.',
        color: Colors.orange,
        bg: const Color(0xFFFFF7ED),
      );
    } else if (status == 'accepted') {
      return _infoCard(
        icon: Icons.check_circle_outline,
        title: 'تم قبول طلبك! 🎉',
        body: 'يمكنك الآن التواصل مع الخبير من صفحة المحادثات للحصول على الاستشارة الكاملة.',
        color: Colors.green,
        bg: const Color(0xFFF0FDF4),
      );
    } else if (status == 'rejected') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cancel_outlined,
                    color: Colors.red.shade600, size: 18),
                const SizedBox(width: 6),
                Text('تم رفض الطلب',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.red.shade800)),
              ],
            ),
            if ((rejectionReason ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('سبب الرفض:',
                  style: TextStyle(
                      fontSize: 12, color: Colors.red.shade700)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(rejectionReason!,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade600)),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'يمكنك محاولة إرسال طلب جديد مع معلومات أكثر وضوحاً.',
              style: TextStyle(
                  fontSize: 11, color: Colors.red.shade700),
            ),
          ],
        ),
      );
    }
    return const SizedBox();
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String body,
    required MaterialColor color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: color.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color.shade800)),
                const SizedBox(height: 4),
                Text(body,
                    style: TextStyle(
                        fontSize: 12, color: color.shade700)),
              ],
            ),
          ),
        ],
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

  // ── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0FDF4),
        body: StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('requests')
              .where('userId', isEqualTo: _uid)
              .snapshots(),
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
                .length;
            final accepted = allRequests
                .where((r) => r['status'] == 'accepted')
                .length;
            final rejected = allRequests
                .where((r) => r['status'] == 'rejected')
                .length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── الهيدر والإحصائيات ──────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('طلباتي للخبراء',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF166534))),
                      const SizedBox(height: 4),
                      const Text(
                          'تابع حالة طلباتك للاستشارة مع الخبراء',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 12),

                      // إحصائيات
                      Row(
                        children: [
                          _statBox('$pending', 'قيد المراجعة',
                              Colors.orange),
                          const SizedBox(width: 10),
                          _statBox('$accepted', 'مقبولة',
                              Colors.green),
                          const SizedBox(width: 10),
                          _statBox('$rejected', 'مرفوضة',
                              Colors.red),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // تابز
                      TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF16a34a),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFF16a34a),
                        labelStyle: const TextStyle(fontSize: 11),
                        onTap: (_) => setState(() {}),
                        tabs: const [
                          Tab(text: 'الكل'),
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
                  child: snapshot.connectionState ==
                      ConnectionState.waiting
                      ? const Center(
                      child: CircularProgressIndicator())
                      : AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) {
                      final filtered = _filter(
                          allRequests,
                          _tabController.index);
                      if (filtered.isEmpty) {
                        return _emptyState(
                            _tabController.index);
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _RequestCard(
                            request: filtered[index],
                            onTap: () => _showDetails(
                                filtered[index]),
                            statusBadge: _statusBadge(
                                filtered[index]['status'] ??
                                    ''),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statBox(String value, String label, MaterialColor color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.shade50,
          border: Border.all(color: color.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18,
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

  Widget _emptyState(int tabIndex) {
    final labels = [
      'لم ترسل أي طلبات بعد',
      'لا توجد طلبات قيد المراجعة',
      'لا توجد طلبات مقبولة',
      'لا توجد طلبات مرفوضة',
    ];
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 52, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(labels[tabIndex],
              style:
              const TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(height: 6),
          const Text('يمكنك إرسال طلب استشارة من قائمة الخبراء',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── بطاقة الطلب ─────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onTap;
  final Widget statusBadge;

  const _RequestCard({
    required this.request,
    required this.onTap,
    required this.statusBadge,
  });

  @override
  Widget build(BuildContext context) {
    final status = request['status'] ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // هيدر
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFdcfce7),
                    child: Text(
                      (request['specialistName'] as String? ?? 'خ')
                          .isNotEmpty
                          ? request['specialistName'][0]
                          : 'خ',
                      style: const TextStyle(
                          color: Color(0xFF15803d), fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            request['specialistName'] ?? 'خبير',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        Text(request['date'] ?? '',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  statusBadge,
                ],
              ),
              const SizedBox(height: 10),

              // صورة
              if ((request['plantImage'] ?? '').isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    request['plantImage'],
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 140,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image,
                          color: Colors.grey),
                    ),
                  ),
                ),
              const SizedBox(height: 8),

              // الوصف
              Text(request['description'] ?? '',
                  style: const TextStyle(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),

              // تشخيص AI
              if ((request['aiDiagnosis'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'تشخيص AI: ${request['aiDiagnosis']}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.amber),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // سبب الرفض
              if (status == 'rejected' &&
                  (request['rejectionReason'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    border: Border.all(
                        color: const Color(0xFFFCA5A5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('سبب الرفض:',
                          style: TextStyle(
                              fontSize: 11, color: Colors.red)),
                      Text(request['rejectionReason'],
                          style: const TextStyle(
                              fontSize: 12, color: Colors.red)),
                    ],
                  ),
                ),
              ],

              // رسالة القبول
              if (status == 'accepted') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    border: Border.all(
                        color: const Color(0xFF86efac)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '✓ تم قبول طلبك! يمكنك التواصل مع الخبير من صفحة المحادثات',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF16a34a)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}