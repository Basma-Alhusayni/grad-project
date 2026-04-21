import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  String _name = '';
  String _email = '';
  bool _loading = true;

  static const _green600 = Color(0xFF16A34A);
  static const _green900 = Color(0xFF14532D);
  static const _green50 = Color(0xFFF0FDF4);
  static const _green100 = Color(0xFFDCFCE7);

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    String name =
        userDoc.data()?['fullName'] ?? userDoc.data()?['username'] ?? '';

    if (name.isEmpty) {
      final accountDoc = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(user.uid)
          .get();
      name = accountDoc.data()?['fullName'] ??
          accountDoc.data()?['username'] ??
          '';
    }

    if (name.isEmpty) {
      name = user.email?.split('@')[0] ?? '';
    }

    if (!mounted) return;
    setState(() {
      _name = name;
      _email = user.email ?? '';
      _loading = false;
    });
  }

  // ── تعديل الاسم (نفس ستايل الأدمن) ──────────────────────────
  void _showEditDialog() {
    final nameController = TextEditingController(text: _name);
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
                  color: _green900),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'الاسم',
                    labelStyle: const TextStyle(color: _green600),
                    prefixIcon:
                    const Icon(Icons.person_outline, color: _green600),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                      const BorderSide(color: _green600, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                const Text('إلغاء', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                  final newName = nameController.text.trim();
                  if (newName.isEmpty) return;
                  setDialogState(() => saving = true);
                  try {
                    final uid =
                        FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      // حفظ في مجموعة users (كلا الحقلين)
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .update({
                        'username': newName,
                        'fullName': newName,
                      });
                      // حفظ في مجموعة accounts
                      await FirebaseFirestore.instance
                          .collection('accounts')
                          .doc(uid)
                          .update({
                        'username': newName,
                        'fullName': newName,
                      });
                    }
                    if (!mounted) return;
                    setState(() => _name = newName);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم حفظ التعديلات بنجاح ✓'),
                        backgroundColor: _green600,
                      ),
                    );
                  } catch (e) {
                    setDialogState(() => saving = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('حدث خطأ: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green600,
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

  // ── تغيير كلمة المرور ──────────────────────────────────────
  Future<void> _showChangePasswordDialog() async {
    bool sending = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'تغيير كلمة المرور',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _green900),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'سيتم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border:
                    Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined,
                          color: _green600, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _email,
                          style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF166534),
                              fontWeight: FontWeight.w500),
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                    ],
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
                onPressed: sending
                    ? null
                    : () async {
                  setDialogState(() => sending = true);
                  try {
                    await FirebaseAuth.instance
                        .sendPasswordResetEmail(email: _email);
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            '✅ تم إرسال رابط إعادة التعيين إلى بريدك'),
                        backgroundColor: _green600,
                      ),
                    );
                  } catch (e) {
                    setDialogState(() => sending = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('حدث خطأ: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green600,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: sending
                    ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Text('إرسال',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _green50,
        body: Center(child: CircularProgressIndicator(color: _green600)),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _green50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header ──
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
                        color: _green100,
                        shape: BoxShape.circle,
                        border: Border.all(color: _green600, width: 2),
                      ),
                      child: const Icon(Icons.person,
                          color: _green600, size: 38),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _green900),
                    ),
                    const SizedBox(height: 4),
                    const Text('مستخدم',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── المعلومات الشخصية ──
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
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المعلومات الشخصية',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                          // ── زر التعديل (نفس الأدمن) ──
                          GestureDetector(
                            onTap: _showEditDialog,
                            child: const Row(
                              children: [
                                Icon(Icons.edit_outlined,
                                    color: _green600, size: 17),
                                SizedBox(width: 4),
                                Text('تعديل',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: _green600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    _buildInfoRow(
                        'الاسم', _name, Icons.person_outline),
                    const Divider(
                        height: 1,
                        color: Color(0xFFEEEEEE),
                        indent: 16,
                        endIndent: 16),
                    _buildInfoRow('البريد الإلكتروني', _email,
                        Icons.email_outlined),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── قسم الأمان ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8E8E8)),
                ),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'الأمان',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                      ),
                    ),
                    const Divider(
                        height: 1, color: Color(0xFFEEEEEE)),
                    ListTile(
                      leading: const Icon(Icons.lock_outline,
                          color: _green600),
                      title: const Text('تغيير كلمة المرور',
                          style: TextStyle(fontSize: 14)),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey,
                        textDirection: TextDirection.ltr,
                      ),
                      onTap: _showChangePasswordDialog,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── الخبراء ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8E8E8)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.people_alt_rounded,
                      color: _green900),
                  title: const Text('الخبراء'),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    textDirection: TextDirection.ltr,
                  ),
                  onTap: () => ScaffoldMessenger.of(context)
                      .showSnackBar(
                      const SnackBar(content: Text('قريباً 🌿'))),
                ),
              ),

              const SizedBox(height: 24),

              // ── زر تسجيل الخروج ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await AuthService().signOut();
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SplashScreen()),
                            (_) => false,
                      );
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('تسجيل الخروج',
                        style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCC0000),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
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
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
          Icon(icon, color: _green600),
        ],
      ),
    );
  }
}