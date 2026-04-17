import 'package:bioshield/screens/user_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';
import 'specialist_list_screen.dart';
import 'user_reports_screen.dart';
import 'user_camera_screen.dart';
import 'package:bioshield/services/image_upload_service.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});
  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    _ReportsDashboard(),
    SpecialistListScreen(),
    //_CameraPlaceholder(),
    UserCameraScreen(),
    UserReportsScreen(), //Jumana
    _UserProfilePage(),
  ];

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
          title: const Text(
            'BioShield',
            style: TextStyle(
              color: Color(0xFF16A34A),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset('assets/images/logo.png',
                errorBuilder: (_, _, _) =>
                const Icon(Icons.eco, color: Color(0xFF16A34A))),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Color(0xFF16A34A)),
              onPressed: () async {
                await AuthService().signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                      (_) => false,
                );
              },
            ),
          ],
        ),
        body: _pages[_currentIndex],
        bottomNavigationBar: _buildBottomNav(),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF16A34A),
          shape: const CircleBorder(),
          onPressed: () => setState(() => _currentIndex = 2),
          child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, Icons.home_outlined, 'الرئيسية'),
          _navItem(1, Icons.chat_bubble_outline, 'الخبراء'),
          const SizedBox(width: 48),
          _navItem(3, Icons.description_outlined, 'تقاريري'),//Jumana
          _navItem(4, Icons.person_outline, 'ملفي'),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isSelected ? const Color(0xFF16A34A) : Colors.grey[400],
              size: 24),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? const Color(0xFF16A34A)
                      : Colors.grey[400])),
        ],
      ),
    );
  }
}

// ─── صفحة البروفايل ───────────────────────────────────────────
class _UserProfilePage extends StatefulWidget {
  const _UserProfilePage();

  @override
  State<_UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<_UserProfilePage> {
  String _name = '';
  String _email = '';
  bool _loading = true;
  int _tabIndex = 0; // 0=الكل, 1=صحية, 2=مريضة

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!mounted) return;
      setState(() {
        _name  = doc.data()?['username'] ?? doc.data()?['fullName'] ?? '';
        _email = FirebaseAuth.instance.currentUser?.email ?? '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return _loading
        ? const Center(
        child: CircularProgressIndicator(color: Color(0xFF16A34A)))
        : StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final allReports = snapshot.data?.docs
            .map((d) => {
          'id': d.id,
          ...d.data() as Map<String, dynamic>
        })
            .toList() ??
            [];

        final total    = allReports.length;
        final shared   = allReports.where((r) => r['isShared'] == true).length;
        final healthy  = allReports.where((r) => r['status'] == 'healthy').length;
        final diseased = allReports.where((r) => r['status'] == 'diseased').length;
        final avgConf  = total == 0
            ? 0
            : (allReports.fold<num>(
            0, (s, r) => s + (r['confidence'] ?? 0)) /
            total)
            .round();

        // فلترة حسب التاب
        final filtered = _tabIndex == 0
            ? allReports
            : _tabIndex == 1
            ? allReports.where((r) => r['status'] == 'healthy').toList()
            : allReports.where((r) => r['status'] == 'diseased').toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── هيدر البروفايل ───────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      _name.isNotEmpty ? _name[0].toUpperCase() : 'م',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16A34A)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name.isNotEmpty ? _name : 'المستخدم',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _email,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: Colors.white, size: 20),
                    onPressed: () => _showEditDialog(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── الإحصائيات ───────────────────────────


            // ── تابات الفلترة ─────────────────────────


            // ── قائمة التقارير ────────────────────────


            // ── أزرار ────────────────────────────────
            OutlinedButton.icon(
              onPressed: () => _showDeleteDialog(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(double.infinity, 46),
              ),
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              label: const Text('حذف الحساب',
                  style: TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCC0000),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                minimumSize: const Size(double.infinity, 46),
              ),
              icon: const Icon(Icons.logout,
                  color: Colors.white, size: 18),
              label: const Text('تسجيل الخروج',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'حذف الحساب',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red),
          ),
          content: const Text(
            'هل أنت متأكد من حذف حسابك؟ سيتم حذف جميع بياناتك بشكل نهائي ولا يمكن التراجع.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    // حذف بيانات Firestore
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .delete();
                    await FirebaseFirestore.instance
                        .collection('accounts')
                        .doc(uid)
                        .delete();
                    // حذف الحساب من Firebase Auth
                    await FirebaseAuth.instance.currentUser?.delete();
                  }
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SplashScreen()),
                        (_) => false,
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('حدث خطأ: \$e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('حذف',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

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
            title: const Text(
              'تعديل المعلومات الشخصية',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF14532D)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: 'الاسم',
                    labelStyle: const TextStyle(color: Color(0xFF16A34A)),
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
                    labelStyle: const TextStyle(color: Color(0xFF16A34A)),
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
                    final newName  = nameController.text.trim();
                    final newEmail = emailController.text.trim();

                    if (uid != null) {
                      // تحديث الاسم في Firestore
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .update({
                        'username': newName,
                        'email': newEmail,
                      });
                      // تحديث في accounts أيضاً
                      await FirebaseFirestore.instance
                          .collection('accounts')
                          .doc(uid)
                          .update({
                        'username': newName,
                        'email': newEmail,
                      });
                      // إذا تغيّر الإيميل أرسل رابط تأكيد
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
                        backgroundColor: const Color(0xFF16A34A),
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

  Widget _statBox(String value, String label, MaterialColor color) {
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
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color.shade700)),
            Text(label,
                textAlign: TextAlign.center,
                style:
                TextStyle(fontSize: 10, color: color.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(int index, String label) {
    final selected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF16A34A)
              : Colors.white,
          border: Border.all(
              color: selected
                  ? const Color(0xFF16A34A)
                  : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              color: selected ? Colors.white : Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _reportListItem(
      Map<String, dynamic> r, BuildContext context) {
    final isHealthy = r['status'] == 'healthy';
    //final imageUrl = r['plantImage'] ?? '';
    final imageUrl = r['imageUrl'] ?? '';//Jumana

    return GestureDetector(
      onTap: () => _showReportDetails(context, r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Row(
          children: [
            // صورة
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      _imgPlaceholder(60))
                  : _imgPlaceholder(60),
            ),
            const SizedBox(width: 12),
            // معلومات
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r['plantName'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isHealthy
                              ? Colors.green
                              : Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isHealthy ? 'صحي' : 'مريض',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(r['diagnosis'] ?? '',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          border:
                          Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('AI  ${r['confidence'] ?? 0}%',
                            style:
                            const TextStyle(fontSize: 10)),
                      ),
                      const SizedBox(width: 6),
                      Text(r['date'] ?? '',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500])),
                      const Spacer(),
                      if (r['isShared'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius:
                            BorderRadius.circular(10),
                          ),
                          child: const Text('مشارك',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF16A34A))),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDetails(
      BuildContext context, Map<String, dynamic> r) {
    final isHealthy = r['status'] == 'healthy';
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تفاصيل التقرير'),
          contentPadding: const EdgeInsets.all(16),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child:

                  //(r['plantImage'] ?? '').isNotEmpty
                      //? Image.network(r['plantImage'],

                  (r['imageUrl'] ?? '').isNotEmpty
                      ? Image.network(r['imageUrl'],//Jumana

                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _imgPlaceholder(160))
                      : _imgPlaceholder(160),
                ),
                const SizedBox(height: 12),
                _detailRow('🌱 اسم النبات', r['plantName'] ?? ''),
                _detailRow('🔍 التشخيص', r['diagnosis'] ?? ''),
                _detailRow('🦠 المرض', r['disease'] ?? ''),
                _detailRow('💊 العلاج', r['treatment'] ?? ''),
                _detailRow(
                    'دقة AI', '${r['confidence'] ?? 0}%'),
                _detailRow('التاريخ', r['date'] ?? ''),
                const SizedBox(height: 8),
                // زر إلغاء المشاركة أو المشاركة
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('reports')
                          .doc(r['id'])
                          .update({
                        'isShared': !(r['isShared'] ?? false)
                      });
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF16A34A),
                      side: const BorderSide(
                          color: Color(0xFF16A34A)),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(8)),
                    ),
                    icon: Icon(
                      r['isShared'] == true
                          ? Icons.share
                          : Icons.share_outlined,
                      size: 16,
                    ),
                    label: Text(r['isShared'] == true
                        ? 'إلغاء المشاركة'
                        : 'مشاركة مع المجتمع'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder(double size) => Container(
    width: size,
    height: size,
    color: Colors.grey[200],
    child: const Icon(Icons.image, color: Colors.grey),
  );
}

// ─── صفحة التقارير (الرئيسية) ────────────────────────────────
class _ReportsDashboard extends StatefulWidget {
  const _ReportsDashboard();


  @override
  State<_ReportsDashboard> createState() => _ReportsDashboardState();
}

class _ReportsDashboardState extends State<_ReportsDashboard> {
  final _db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _username = '';

  @override
  void initState() {
    super.initState();
    _fetchUsername();
  }

  Future<void> _fetchUsername() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!mounted) return;
    setState(() {
      _username = doc.data()?['username'] ?? 'مستخدم';
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('community_feed')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final allReports = snapshot.data?.docs
            .map((d) =>
        {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList() ??
            [];

        final filtered = allReports.where((r) {
          final q = _searchQuery.toLowerCase();
          return (r['plantName'] ?? '').toLowerCase().contains(q) ||
              (r['diagnosis'] ?? '').toLowerCase().contains(q) ||
              (r['disease'] ?? '').toLowerCase().contains(q);
        }).toList();

        final total    = allReports.length;
        final healthy  = allReports.where((r) => r['status'] == 'healthy').length;
        final diseased = allReports.where((r) => r['status'] == 'diseased').length;
        final avgConf  = total == 0
            ? 0
            : (allReports.fold<num>(
            0, (s, r) => s + (r['confidence'] ?? 0)) /
            total)
            .round();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            /*const Text('لوحة التقارير',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF166534))),
            const SizedBox(height: 4),
            const Text(
                'استكشف تقارير تشخيص النباتات المشاركة من المجتمع',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),

            Row(
              children: [
                _StatCard(total.toString(), 'تقرير',
                    Icons.bar_chart, Colors.blue),
                const SizedBox(width: 8),
                _StatCard(healthy.toString(), 'صحي',
                    Icons.trending_up, Colors.green),
                const SizedBox(width: 8),
                _StatCard(diseased.toString(), 'مريض',
                    Icons.warning_amber, Colors.red),
                const SizedBox(width: 8),
                _StatCard('$avgConf%', 'دقة',
                    Icons.emoji_events, Colors.purple),
              ],
            ),
             */

            // ── Greeting banner ───────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14532D), Color(0xFF16A34A)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(' مرحبا,ً$_username 👋',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ])),
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.eco_rounded,
                      color: Colors.white, size: 28),
                ),
              ]),
            ),
            const SizedBox(height: 20),


            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _searchController,
                textDirection: TextDirection.rtl,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: const InputDecoration(
                  hintText: 'ابحث عن نبات أو مرض...',
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: Colors.grey),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('${filtered.length} نتيجة',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey)),
            ],
            const SizedBox(height: 16),
            const Text('التقارير المشاركة',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF166534))),
            const SizedBox(height: 10),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (filtered.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'لم يتم العثور على نتائج'
                        : 'لا توجد تقارير مشاركة بعد',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.8,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final report = filtered[index];
                  return _ReportCard(
                      report: report, onTap: () {});
                },
              ),
          ],
        );
      },
    );
  }
}

// ─── بطاقة إحصائية ───────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final MaterialColor color;

  const _StatCard(this.value, this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
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
            Icon(icon, color: color.shade600, size: 20),
            const SizedBox(height: 4),
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

// ─── بطاقة تقرير ─────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onTap;

  const _ReportCard({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isHealthy = report['status'] == 'healthy';
    //final imageUrl = report['plantImage'] ?? '';
    final imageUrl = report['imageUrl'] ?? ''; //Jumana

    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                    child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _imgPlaceholder())
                        : _imgPlaceholder(),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isHealthy
                            ? Colors.green
                            : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isHealthy ? 'صحي' : 'مريض',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(report['plantName'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(report['diagnosis'] ?? '',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.grey[300]!),
                          borderRadius:
                          BorderRadius.circular(10),
                        ),
                        child: Text(
                            '${report['confidence'] ?? 0}%',
                            style:
                            const TextStyle(fontSize: 10)),
                      ),
                      Row(
                        children: [
                          Icon(Icons.visibility,
                              size: 12,
                              color: Colors.grey[500]),
                          const SizedBox(width: 2),
                          Text('عرض',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final isHealthy = report['status'] == 'healthy';
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تفاصيل التقرير'),
          contentPadding: const EdgeInsets.all(16),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child:

                  //(report['plantImage'] ?? '').isNotEmpty
                      //? Image.network(report['plantImage'],

                  (report['imageUrl'] ?? '').isNotEmpty
                      ? Image.network(report['imageUrl'],//Jumana

                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _imgPlaceholder())
                      : _imgPlaceholder(),
                ),
                const SizedBox(height: 12),
                _detailCard('🌱 اسم النبات',
                    report['plantName'] ?? '', Colors.purple),
                _detailCard(
                  '🔍 التشخيص',
                  report['diagnosis'] ?? '',
                  isHealthy ? Colors.green : Colors.red,
                  extra: report['disease'] ?? '',
                ),
                _detailCard('💊 العلاج الموصى به',
                    report['treatment'] ?? '', Colors.blue),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Text('تم التشخيص بواسطة',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey)),
                          Text(report['capturedBy'] ?? '',
                              style: const TextStyle(
                                  fontSize: 13)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius:
                          BorderRadius.circular(20),
                        ),
                        child: Text(
                          'دقة: ${report['confidence'] ?? 0}%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Text('تاريخ التقرير:',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey)),
                      const SizedBox(width: 8),
                      Text(report['date'] ?? '',
                          style:
                          const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
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

  Widget _detailCard(String title, String content,
      MaterialColor color,
      {String extra = ''}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.shade50,
        border: Border.all(color: color.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color.shade800)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 13)),
          if (extra.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(extra,
                  style: const TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    height: 120,
    color: Colors.grey[200],
    child: const Center(
        child: Icon(Icons.image, size: 40, color: Colors.grey)),
  );
}

// ─── Placeholders ─────────────────────────────────────────────
class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();
  @override
  Widget build(BuildContext context) => const Center(
      child: Text('صفحة الكاميرا',
          style: TextStyle(fontSize: 18, color: Colors.grey)));
}