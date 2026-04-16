import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_with_user_screen.dart';

class UserRequestsScreen extends StatefulWidget {
  const UserRequestsScreen({super.key});

  @override
  State<UserRequestsScreen> createState() => _UserRequestsScreenState();
}

class _UserRequestsScreenState extends State<UserRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
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

  List<Map<String, dynamic>> _filter(
      List<Map<String, dynamic>> all, int tabIndex) {
    switch (tabIndex) {
      case 0: return all;
      case 1: return all.where((r) => r['status'] == 'pending').toList();
      case 2: return all.where((r) => r['status'] == 'accepted').toList();
      case 3: return all.where((r) => r['status'] == 'rejected').toList();
      default: return all;
    }
  }

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

  Widget _badge(IconData icon, String label, MaterialColor color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              style: TextStyle(fontSize: 11, color: color.shade700)),
        ],
      ),
    );
  }

  // ── فتح الشات ──────────────────────────────────────────────
  void _openChat(Map<String, dynamic> request) {
    final chatId = request['chatId'] ?? '';
    if (chatId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم إنشاء المحادثة بعد',
              textDirection: TextDirection.rtl),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatWithUserScreen(
          chatId: chatId,
          expertName: request['specialistName'] ?? '',
          expertRating:
          (request['expertRating'] ?? 0).toDouble(),
          isOnline: false,
        ),
      ),
    );
  }

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
                Container(
                  color: Colors.white,
                  padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                      Row(
                        children: [
                          _statBox('$pending', 'قيد المراجعة',
                              Colors.orange),
                          const SizedBox(width: 10),
                          _statBox(
                              '$accepted', 'مقبولة', Colors.green),
                          const SizedBox(width: 10),
                          _statBox(
                              '$rejected', 'مرفوضة', Colors.red),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                Expanded(
                  child: snapshot.connectionState ==
                      ConnectionState.waiting
                      ? const Center(
                      child: CircularProgressIndicator())
                      : AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) {
                      final filtered = _filter(
                          allRequests, _tabController.index);
                      if (filtered.isEmpty) {
                        return _emptyState(
                            _tabController.index);
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final req = filtered[index];
                          return _RequestCard(
                            request: req,
                            statusBadge: _statusBadge(
                                req['status'] ?? ''),
                            onOpenChat: req['status'] ==
                                'accepted'
                                ? () => _openChat(req)
                                : null,
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

  Widget _statBox(
      String value, String label, MaterialColor color) {
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
              style: const TextStyle(
                  color: Colors.grey, fontSize: 15)),
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
  final Widget statusBadge;
  final VoidCallback? onOpenChat;

  const _RequestCard({
    required this.request,
    required this.statusBadge,
    this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    final status = request['status'] ?? '';

    return Container(
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
                      Text(request['specialistName'] ?? 'خبير',
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

            // الوصف
            if ((request['description'] ?? '').isNotEmpty)
              Text(request['description'],
                  style: const TextStyle(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),

            // حالة الطلب
            const SizedBox(height: 10),
            if (status == 'pending')
              _statusInfo(
                icon: Icons.access_time,
                title: 'طلبك قيد المراجعة',
                body: 'الخبير سيراجع طلبك ورسائلك قريباً',
                color: Colors.orange,
                bg: const Color(0xFFFFF7ED),
              )
            else if (status == 'accepted') ...[
              _statusInfo(
                icon: Icons.check_circle_outline,
                title: 'تم قبول طلبك! 🎉',
                body: 'يمكنك الآن متابعة المحادثة مع الخبير',
                color: Colors.green,
                bg: const Color(0xFFF0FDF4),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline,
                      size: 18),
                  label: const Text('فتح المحادثة',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  onPressed: onOpenChat,
                ),
              ),
            ] else if (status == 'rejected') ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  border: Border.all(
                      color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cancel_outlined,
                            color: Colors.red.shade600, size: 16),
                        const SizedBox(width: 6),
                        Text('تم رفض الطلب',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.red.shade800)),
                      ],
                    ),
                    if ((request['rejectionReason'] ?? '')
                        .isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'سبب الرفض: ${request['rejectionReason']}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusInfo({
    required IconData icon,
    required String title,
    required String body,
    required MaterialColor color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: color.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.shade600, size: 18),
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
                const SizedBox(height: 2),
                Text(body,
                    style: TextStyle(
                        fontSize: 11, color: color.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}