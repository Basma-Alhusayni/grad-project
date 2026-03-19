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

  // Fetch admin data from Firestore and sync email with Firebase Auth
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

    // If email in Auth differs from Firestore, update Firestore
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
      _name  = doc.data()?['username'] ?? '';
      _email = authEmail.isNotEmpty ? authEmail : firestoreEmail;
      _loading = false;
    });
  }

  // Sign out and navigate to splash screen
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
        // Show loading indicator while fetching data
        body: _loading
            ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF16A34A)))
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

  // ── Home Tab ──────────────────────────────────────────────────
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
        ],
      ),
    );
  }

  // ── Requests Tab - streams pending specialist requests ────────
  Widget _buildRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('specialist_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
              CircularProgressIndicator(color: Color(0xFF16A34A)));
        }
        final docs = snapshot.data?.docs ?? [];

        // Show empty state if no pending requests
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                const Text('لا توجد طلبات معلقة',
                    style:
                    TextStyle(color: Colors.grey, fontSize: 15)),
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
            return _buildRequestCard(data, docId);
          },
        );
      },
    );
  }

  // Build a single request card with approve/reject buttons
  Widget _buildRequestCard(Map<String, dynamic> data, String docId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        children: [
          // Card header with applicant info
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
              ],
            ),
          ),
          // Card details: certificates and experience
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _requestRow(Icons.workspace_premium_outlined,
                    'الشهادات', data['certificates'] ?? '—'),
                const SizedBox(height: 8),
                _requestRow(Icons.history_edu_outlined, 'الخبرة',
                    data['experience'] ?? '—'),
              ],
            ),
          ),
          // Approve and reject action buttons
          Padding(
            padding:
            const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveRequest(data, docId),
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
                    onPressed: () => _rejectRequest(docId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFCC0000),
                      side: const BorderSide(color: Color(0xFFCC0000)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.close,
                        color: Color(0xFFCC0000), size: 16),
                    label: const Text('رفض',
                        style: TextStyle(
                            color: Color(0xFFCC0000), fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper row widget for displaying request details
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

  // ── Approve Request ───────────────────────────────────────────
  Future<void> _approveRequest(
      Map<String, dynamic> data, String docId) async {
    final email    = data['email'] ?? '';
    final fullName = data['fullName'] ?? '';

    try {
      String uid = '';

      // Check if an account with this email already exists in Firestore
      final existingAccount = await FirebaseFirestore.instance
          .collection('accounts')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (existingAccount.docs.isNotEmpty) {
        // Account exists - update role to specialist
        uid = existingAccount.docs.first.id;
        await FirebaseFirestore.instance
            .collection('accounts')
            .doc(uid)
            .update({
          'role': 'specialist',
          'status': 'active',
          'username': fullName,
        });
      } else {
        // Account does not exist - create a new Firebase Auth account
        final password =
            'Bio${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}!';
        final cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        uid = cred.user!.uid;
        await FirebaseFirestore.instance
            .collection('accounts')
            .doc(uid)
            .set({
          'accountId': uid,
          'role': 'specialist',
          'status': 'active',
          'email': email,
          'username': fullName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Save or update specialist profile in Firestore
      await FirebaseFirestore.instance
          .collection('specialists')
          .doc(uid)
          .set({
        'specialistId': uid,
        'accountId': uid,
        'email': email,
        'fullName': fullName,
        'certificates': data['certificates'] ?? '',
        'experience': data['experience'] ?? '',
        'rating': 0.0,
        'reviewCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Mark the request as approved
      await FirebaseFirestore.instance
          .collection('specialist_requests')
          .doc(docId)
          .update({'status': 'approved', 'specialistId': uid});

      // Send password reset email so specialist can set their password
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'تم قبول $fullName ✓  |  تم إرسال رابط الدخول على إيميله'),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Reject Request ────────────────────────────────────────────
  Future<void> _rejectRequest(String docId) async {
    // Show confirmation dialog before rejecting
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('تأكيد الرفض',
              style: TextStyle(
                  color: Color(0xFF14532D),
                  fontWeight: FontWeight.bold)),
          content:
          const Text('هل أنت متأكد من رفض هذا الطلب؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0000),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: const Text('رفض',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    // Update request status to rejected
    await FirebaseFirestore.instance
        .collection('specialist_requests')
        .doc(docId)
        .update({'status': 'rejected'});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم رفض الطلب'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // ── Profile Tab ───────────────────────────────────────────────
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Profile avatar and name
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
                    style:
                    TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Personal information card
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
                      // Edit button opens edit dialog
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
          const SizedBox(height: 12),

          // System information card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Text('معلومات النظام',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                ),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                          child: _buildSystemInfoItem(
                              label: 'آخر تحديث',
                              value: '2024-11-18')),
                      Expanded(
                          child: _buildSystemInfoItem(
                              label: 'إصدار التطبيق',
                              value: '1.0.0')),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                      right: 16, left: 16, bottom: 14),
                  child: _buildSystemInfoItem(
                      label: 'حالة النظام', value: 'نشط'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout button
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

  // ── Edit Dialog - update name and email in Firestore and Auth ─
  void _showEditDialog() {
    final nameController  = TextEditingController(text: _name);
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
                    final uid = FirebaseAuth
                        .instance.currentUser?.uid;
                    final newName =
                    nameController.text.trim();
                    final newEmail =
                    emailController.text.trim();
                    if (uid != null) {
                      // Save name and email to admins collection
                      await FirebaseFirestore.instance
                          .collection('admins')
                          .doc(uid)
                          .update({
                        'username': newName,
                        'email': newEmail,
                      });
                      // Save name and email to accounts collection
                      await FirebaseFirestore.instance
                          .collection('accounts')
                          .doc(uid)
                          .update({
                        'username': newName,
                        'email': newEmail,
                      });
                      // Send email verification if email changed
                      if (newEmail != _email) {
                        await FirebaseAuth.instance.currentUser
                            ?.verifyBeforeUpdateEmail(newEmail);
                      }
                    }
                    if (!mounted) return;
                    setState(() {
                      _name  = newName;
                      _email = newEmail;
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(newEmail != _email
                            ? 'تم الحفظ ✓  |  تحقق من إيميلك الجديد'
                            : 'تم حفظ التعديلات بنجاح ✓'),
                        backgroundColor:
                        const Color(0xFF16A34A),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  } catch (e) {
                    setDialogState(() => saving = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('حدث خطأ: \$e'),
                        backgroundColor: Colors.red,
                      ),
                    );
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

  // Helper widget for displaying a labeled info row
  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  // Helper widget for displaying a system info item
  Widget _buildSystemInfoItem(
      {required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
            const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                fontSize: 14, color: Colors.black87)),
      ],
    );
  }
}