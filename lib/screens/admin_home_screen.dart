import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  String _name = '';
  String _email = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
  }

  Future<void> _fetchAdminData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.reload();
    final authEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final doc = await FirebaseFirestore.instance
        .collection('admins')
        .doc(user.uid)
        .get();
    final firestoreEmail = doc.data()?['email'] ?? '';
    if (authEmail.isNotEmpty && authEmail != firestoreEmail) {
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .update({'email': authEmail});
      await FirebaseFirestore.instance
          .collection('accounts')
          .doc(user.uid)
          .update({'email': authEmail});
    }
    if (!mounted) return;
    setState(() {
      _name = doc.data()?['username'] ?? '';
      _email = authEmail.isNotEmpty ? authEmail : firestoreEmail;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0FDF4),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF16A34A)),
            onPressed: _logout,
          ),
          title: const Text(
            'لوحة تحكم الإدارة',
            style: TextStyle(
              color: Color(0xFF14532D),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset('assets/images/logo.png', height: 36),
            ),
          ],
        ),
        body: _loading
            ? const Center(
            child: CircularProgressIndicator(
                color: Color(0xFF16A34A)))
            : _currentIndex == 0
            ? _buildHomeTab()
            : _currentIndex == 1
            ? _buildRequestsTab()
            : _buildProfileTab(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: const Color(0xFF16A34A),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 8,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_add_outlined),
              activeIcon: Icon(Icons.person_add),
              label: 'الطلبات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'الملف الشخصي',
            ),
          ],
        ),
      ),
    );
  }

  // ── Home Tab ────────────────────────────────────────────────
  Widget _buildHomeTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: RichText(
              textAlign: TextAlign.right,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF14532D),
                ),
                children: [
                  const TextSpan(text: 'مرحباً '),
                  TextSpan(
                    text: _name,
                    style: const TextStyle(color: Color(0xFF16A34A)),
                  ),
                  const TextSpan(text: ' !'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'لوحة تحكم الإدارة',
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          // Quick stats
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('specialist_requests')
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final pending =
                  docs.where((d) => (d.data() as Map)['status'] == 'pending').length;
              final approved =
                  docs.where((d) => (d.data() as Map)['status'] == 'approved').length;
              final rejected =
                  docs.where((d) => (d.data() as Map)['status'] == 'rejected').length;
              return Row(
                children: [
                  _statCard('$pending', 'طلبات معلقة', Colors.orange,
                      Icons.pending_actions),
                  const SizedBox(width: 12),
                  _statCard('$approved', 'تمت الموافقة', Colors.green,
                      Icons.check_circle_outline),
                  const SizedBox(width: 12),
                  _statCard('$rejected', 'مرفوضة', Colors.red,
                      Icons.cancel_outlined),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statCard(
      String value, String label, MaterialColor color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color.shade600, size: 28),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color.shade700)),
            Text(label,
                textAlign: TextAlign.center,
                style:
                TextStyle(fontSize: 11, color: color.shade600)),
          ],
        ),
      ),
    );
  }

  // ── Requests Tab ────────────────────────────────────────────
  Widget _buildRequestsTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: const Color(0xFF16A34A),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF16A34A),
              tabs: const [
                Tab(text: 'معلقة'),
                Tab(text: 'موافق عليها'),
                Tab(text: 'مرفوضة'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _requestsList('pending'),
                _requestsList('approved'),
                _requestsList('rejected'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestsList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('specialist_requests')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
              CircularProgressIndicator(color: Color(0xFF16A34A)));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  status == 'pending'
                      ? 'لا توجد طلبات معلقة'
                      : status == 'approved'
                      ? 'لا توجد طلبات موافق عليها'
                      : 'لا توجد طلبات مرفوضة',
                  style:
                  const TextStyle(color: Colors.grey, fontSize: 15),
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
            final docId = docs[index].id;
            return _buildRequestCard(data, docId, status);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(
      Map<String, dynamic> data, String docId, String status) {
    final statusColor = status == 'pending'
        ? Colors.orange
        : status == 'approved'
        ? Colors.green
        : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFDCFCE7),
                  child: Text(
                    (data['fullName'] ?? 'خ')[0],
                    style: const TextStyle(
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['fullName'] ?? 'غير محدد',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF14532D)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data['email'] ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                    Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    status == 'pending'
                        ? 'معلق'
                        : status == 'approved'
                        ? 'موافق عليه'
                        : 'مرفوض',
                    style:
                    TextStyle(fontSize: 11, color: statusColor),
                  ),
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _requestRow(Icons.workspace_premium_outlined,
                    'الشهادات', data['certificates'] ?? '—'),
                const SizedBox(height: 8),
                _requestRow(Icons.history_edu_outlined, 'الخبرة',
                    data['experience'] ?? '—'),
                // Show rejection reason if rejected
                if (status == 'rejected' &&
                    (data['rejectionReason'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFFCA5A5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('سبب الرفض:',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(data['rejectionReason'],
                            style: const TextStyle(
                                fontSize: 13, color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Action buttons (only for pending)
          if (status == 'pending')
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _approveRequest(data, docId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check,
                          color: Colors.white, size: 16),
                      label: const Text('قبول',
                          style: TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showRejectDialog(data, docId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFCC0000),
                        side: const BorderSide(
                            color: Color(0xFFCC0000)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.close,
                          color: Color(0xFFCC0000), size: 16),
                      label: const Text('رفض',
                          style: TextStyle(
                              color: Color(0xFFCC0000),
                              fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _requestRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF16A34A), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Approve Request ──────────────────────────────────────────
  Future<void> _approveRequest(
      Map<String, dynamic> data, String docId) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('تأكيد القبول',
              style: TextStyle(
                  color: Color(0xFF14532D),
                  fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'هل تريد قبول طلب ${data['fullName'] ?? ''}؟'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(children: [
                  Icon(Icons.email_outlined,
                      color: Color(0xFF16A34A), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سيتم إرسال رابط تعيين كلمة المرور إلى بريده الإلكتروني تلقائياً',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF166534)),
                    ),
                  ),
                ]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('قبول',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    // Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(
              color: Color(0xFF16A34A)),
        ),
      );
    }

    final err = await AuthService().approveSpecialistRequest(
      requestData: data,
      requestDocId: docId,
    );

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('حدث خطأ: $err'),
        backgroundColor: Colors.red,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ تم قبول ${data['fullName'] ?? ''} | تم إرسال رابط تعيين كلمة المرور إلى بريده'),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ── Reject Dialog ────────────────────────────────────────────
  void _showRejectDialog(Map<String, dynamic> data, String docId) {
    final reasonController = TextEditingController();
    String? reasonError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              const Icon(Icons.cancel_outlined,
                  color: Color(0xFFCC0000), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'رفض طلب ${data['fullName'] ?? ''}',
                  style: const TextStyle(
                      color: Color(0xFF14532D),
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Applicant info
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border:
                    Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFDCFCE7),
                        child: Text(
                          (data['fullName'] ?? 'خ')[0],
                          style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(data['fullName'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            Text(data['email'] ?? '',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'سبب الرفض *',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  maxLines: 4,
                  textDirection: TextDirection.rtl,
                  onChanged: (v) {
                    setDialogState(() {
                      reasonError =
                      v.trim().isEmpty ? 'سبب الرفض مطلوب' : null;
                    });
                  },
                  decoration: InputDecoration(
                    hintText:
                    'مثال: الشهادات المقدمة غير كافية، أو الخبرة غير مناسبة...',
                    hintStyle: TextStyle(
                        fontSize: 12, color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: reasonError != null
                              ? Colors.red
                              : Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: reasonError != null
                              ? Colors.red
                              : Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFFCC0000), width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    errorText: reasonError,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.email_outlined,
                        color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سيتم إرسال سبب الرفض إلى بريد المتقدم تلقائياً',
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    setDialogState(
                            () => reasonError = 'سبب الرفض مطلوب');
                    return;
                  }

                  Navigator.pop(ctx);

                  // Show loading
                  if (mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF16A34A)),
                      ),
                    );
                  }

                  final err =
                  await AuthService().rejectSpecialistRequest(
                    requestDocId: docId,
                    expertEmail: data['email'] ?? '',
                    expertName: data['fullName'] ?? '',
                    rejectionReason: reason,
                  );

                  if (!mounted) return;
                  Navigator.pop(context); // close loading

                  if (err != null && err.contains('فشل إرسال')) {
                    // Soft warning — Firestore updated but email failed
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(err),
                        backgroundColor: Colors.orange,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  } else if (err != null) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(
                      content: Text('حدث خطأ: $err'),
                      backgroundColor: Colors.red,
                    ));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '❌ تم رفض طلب ${data['fullName'] ?? ''} | '
                              'تم إرسال سبب الرفض إلى بريده الإلكتروني',
                        ),
                        backgroundColor: Colors.orange,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0000),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.close,
                    color: Colors.white, size: 16),
                label: const Text('رفض الطلب',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Profile Tab ──────────────────────────────────────────────
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF16A34A), width: 2),
                  ),
                  child: const Icon(Icons.shield,
                      color: Color(0xFF16A34A), size: 38),
                ),
                const SizedBox(height: 10),
                Text(
                  _name.isNotEmpty ? _name : 'مدير النظام',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF14532D)),
                ),
                const SizedBox(height: 4),
                const Text('مدير النظام',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المعلومات الشخصية',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      GestureDetector(
                        onTap: _showEditDialog,
                        child: const Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                color: Color(0xFF16A34A), size: 17),
                            SizedBox(width: 4),
                            Text('تعديل',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF16A34A))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                _buildInfoRow(
                    label: 'الاسم',
                    value: _name.isNotEmpty ? _name : 'مدير النظام',
                    icon: Icons.person_outline,
                    iconColor: const Color(0xFF16A34A)),
                const Divider(
                    height: 1,
                    color: Color(0xFFEEEEEE),
                    indent: 16,
                    endIndent: 16),
                _buildInfoRow(
                    label: 'البريد الإلكتروني',
                    value: _email.isNotEmpty
                        ? _email
                        : 'admin@bioshield.com',
                    icon: Icons.email_outlined,
                    iconColor: const Color(0xFF16A34A)),
                const Divider(
                    height: 1,
                    color: Color(0xFFEEEEEE),
                    indent: 16,
                    endIndent: 16),
                _buildInfoRow(
                    label: 'الصلاحيات',
                    value: 'صلاحيات: كاملة',
                    icon: Icons.settings_outlined,
                    iconColor: const Color(0xFF16A34A)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0000),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.logout,
                    color: Colors.white, size: 20),
                label: const Text('تسجيل الخروج',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showEditDialog() {
    final nameController = TextEditingController(text: _name);
    final emailController = TextEditingController(text: _email);
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('تعديل المعلومات الشخصية',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF14532D))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: 'الاسم',
                    labelStyle:
                    const TextStyle(color: Color(0xFF16A34A)),
                    prefixIcon: const Icon(Icons.person_outline,
                        color: Color(0xFF16A34A)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFF16A34A), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    labelStyle:
                    const TextStyle(color: Color(0xFF16A34A)),
                    prefixIcon: const Icon(Icons.email_outlined,
                        color: Color(0xFF16A34A)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFF16A34A), width: 2),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                  setDialogState(() => saving = true);
                  try {
                    final uid =
                        FirebaseAuth.instance.currentUser?.uid;
                    final newName = nameController.text.trim();
                    final newEmail =
                    emailController.text.trim();
                    if (uid != null) {
                      await FirebaseFirestore.instance
                          .collection('admins')
                          .doc(uid)
                          .update({
                        'username': newName,
                        'email': newEmail,
                      });
                      await FirebaseFirestore.instance
                          .collection('accounts')
                          .doc(uid)
                          .update({
                        'username': newName,
                        'email': newEmail,
                      });
                      if (newEmail != _email) {
                        await FirebaseAuth.instance.currentUser
                            ?.verifyBeforeUpdateEmail(newEmail);
                      }
                    }
                    if (!mounted) return;
                    setState(() {
                      _name = newName;
                      _email = newEmail;
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(
                      content:
                      Text('تم حفظ التعديلات بنجاح ✓'),
                      backgroundColor: Color(0xFF16A34A),
                    ));
                  } catch (e) {
                    setDialogState(() => saving = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: saving
                    ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Text('حفظ',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, color: Colors.black87)),
              ],
            ),
          ),
          Icon(icon, color: iconColor, size: 22),
        ],
      ),
    );
  }
}