import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';
import 'user_reports_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});
  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  String _name  = '';
  String _email = '';
  bool _loading = true;

  static const _green600 = Color(0xFF16A34A);
  static const _green900 = Color(0xFF14532D);
  static const _green50  = Color(0xFFF0FDF4);
  static const _green100 = Color(0xFFDCFCE7);

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Try users collection first
    final userDoc = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).get();
    String name = userDoc.data()?['fullName'] ??
        userDoc.data()?['username'] ?? '';

    // If not found, try accounts collection
    if (name.isEmpty) {
      final accountDoc = await FirebaseFirestore.instance
          .collection('accounts').doc(user.uid).get();
      name = accountDoc.data()?['fullName'] ??
          accountDoc.data()?['username'] ?? '';
    }

    // Fallback to email prefix
    if (name.isEmpty) {
      name = user.email?.split('@')[0] ?? '';
    }

    if (!mounted) return;
    setState(() {
      _name  = name;
      _email = user.email ?? '';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0FDF4),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF16A34A))),
      );
    }

    return Scaffold(
      backgroundColor: _green50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _green600),
          onPressed: () => Navigator.pop(context),
        )
            : null,
        title: const Text('ملفي الشخصي',
            style: TextStyle(
                color: _green900, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Avatar ──────────────────────
              Center(child: Container(
                width: 90, height: 90,
                decoration: const BoxDecoration(
                    color: _green100, shape: BoxShape.circle),
                child: const Icon(Icons.person_rounded,
                    color: _green600, size: 50),
              )),
              const SizedBox(height: 14),

              // ── Name ────────────────────────
              Center(child: Text(_name,
                style: const TextStyle(
                  color: _green900, fontSize: 22,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              )),
              const SizedBox(height: 4),

              // ── Email ───────────────────────
              Center(child: Text(_email,
                style: const TextStyle(
                  color: Colors.grey, fontSize: 13,
                  decoration: TextDecoration.none,
                ),
              )),
              const SizedBox(height: 24),

              // ── Stats banner ─────────────────
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .collection('reports')
                    .snapshots(),
                builder: (context, snap) {
                  final docs    = snap.data?.docs ?? [];
                  final total   = docs.length;
                  final sick    = docs.where((d) =>
                  (d.data() as Map)['status'] == 'مريض').length;
                  final healthy = docs.where((d) =>
                  (d.data() as Map)['status'] == 'سليم').length;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF16A34A), Color(0xFF14532D)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStat('$healthy', 'سليم'),
                        _buildStat('$sick',    'مريض'),
                        _buildStat('$total',   'إجمالي'),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Menu items ───────────────────
              _buildMenuItem(
                icon: Icons.list_alt_rounded,
                label: 'تقاريري',
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => Scaffold(
                    backgroundColor: _green50,
                    appBar: AppBar(
                      backgroundColor: Colors.white,
                      elevation: 1,
                      centerTitle: true,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: _green600),
                        onPressed: () => Navigator.pop(context),
                      ),
                      title: const Text('تقارير التشخيص',
                          style: TextStyle(color: _green900,
                              fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                    body: const Directionality(
                      textDirection: TextDirection.rtl,
                      child: UserReportsScreen(),
                    ),
                  ),
                )),
              ),

              _buildMenuItem(
                icon: Icons.people_alt_rounded,
                label: 'الخبراء',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('قريباً 🌿',
                        textDirection: TextDirection.rtl))),
              ),

              _buildMenuItem(
                icon: Icons.lock_outline_rounded,
                label: 'تغيير كلمة المرور',
                onTap: () => _showChangePasswordDialog(),
              ),

              _buildMenuItem(
                icon: Icons.logout_rounded,
                label: 'تسجيل الخروج',
                color: Colors.red,
                onTap: () async {
                  await AuthService().signOut();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (_) => const SplashScreen()),
                          (_) => false);
                },
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ── Change Password Dialog ────────────────────
  Future<void> _showChangePasswordDialog() async {
    final emailController = TextEditingController(text: _email);
    bool sending = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            backgroundColor: const Color(0xFFF0FDF4),
            title: const Text(
              'تغيير كلمة المرور',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF14532D),
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                'أدخل بريدك الإلكتروني وسنرسل لك رابطاً لإعادة تعيين كلمة المرور',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'example@email.com',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF16A34A), width: 2),
                  ),
                ),
              ),
            ]),
            actions: [
              Row(children: [
                Expanded(child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء',
                      style: TextStyle(color: Colors.grey, fontSize: 15)),
                )),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: sending ? null : () async {
                    final email = emailController.text.trim();
                    if (email.isEmpty) return;
                    setDialogState(() => sending = true);
                    try {
                      await FirebaseAuth.instance
                          .sendPasswordResetEmail(email: email);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '✅ تم إرسال رابط إعادة التعيين إلى بريدك الإلكتروني',
                              textDirection: TextDirection.rtl,
                            ),
                            backgroundColor: Color(0xFF16A34A),
                          ));
                    } on FirebaseAuthException catch (e) {
                      if (!ctx.mounted) return;
                      setDialogState(() => sending = false);
                      String msg = 'حدث خطأ، حاول مجدداً';
                      if (e.code == 'user-not-found') {
                        msg = 'البريد الإلكتروني غير مسجل';
                      }
                      if (e.code == 'invalid-email') {
                        msg = 'البريد الإلكتروني غير صحيح';
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(msg,
                            textDirection: TextDirection.rtl),
                        backgroundColor: Colors.red,
                      ));
                    }
                  },
                  child: sending
                      ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : const Text('إرسال',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 15)),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(children: [
      Text(value, style: const TextStyle(
          color: Colors.white, fontSize: 24,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.none)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(
          color: Colors.white70, fontSize: 13,
          decoration: TextDecoration.none)),
    ]);
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFF14532D),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(
              color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600,
                  fontSize: 15, decoration: TextDecoration.none))),
          Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey[400]),
        ]),
      ),
    );
  }
}