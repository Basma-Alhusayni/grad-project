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
      name =
          accountDoc.data()?['fullName'] ??
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
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'تعديل المعلومات الشخصية',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _green900,
              ),
            ),
            content: TextField(
              controller: nameController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: 'الاسم',
                prefixIcon: const Icon(Icons.person_outline, color: _green600),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final newName = nameController.text.trim();
                        if (newName.isEmpty) return;
                        setDialogState(() => saving = true);
                        try {
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          if (uid != null) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .update({
                                  'username': newName,
                                  'fullName': newName,
                                });
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
                        } catch (e) {
                          setDialogState(() => saving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: _green600),
                child: saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('حفظ', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    bool sending = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'تغيير كلمة المرور',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _green900,
              ),
            ),
            content: Text(
              'سيتم إرسال رابط إعادة تعيين كلمة المرور إلى: \n$_email',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: sending
                    ? null
                    : () async {
                        setDialogState(() => sending = true);
                        await FirebaseAuth.instance.sendPasswordResetEmail(
                          email: _email,
                        );
                        if (!mounted) return;
                        Navigator.pop(ctx);
                      },
                style: ElevatedButton.styleFrom(backgroundColor: _green600),
                child: const Text(
                  'إرسال',
                  style: TextStyle(color: Colors.white),
                ),
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
        // هذه الخاصية تضمن أن الشاشة لا تضغط العناصر بشكل سيء عند ظهور الكيبورد
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(
            // يستخدم لضمان توزيع العناصر بشكل صحيح في المساحات المختلفة
            builder: (context, constraints) {
              return SingleChildScrollView(
                // نعيد السكرول ولكن نجعله يعمل فقط إذا ضاقت الشاشة (مثل عند ظهور الكيبورد)
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // ── Custom Header ──
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'الملف الشخصي',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _green900,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── بطاقة معلومات المستخدم ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: _green100,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _green600,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: _green600,
                                    size: 45,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _green900,
                                  ),
                                ),
                                const Text(
                                  'مستخدم BioShield',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── قسم المعلومات التفصيلية ──
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  title: const Text(
                                    'المعلومات الشخصية',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: TextButton.icon(
                                    onPressed: _showEditDialog,
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: _green600,
                                    ),
                                    label: const Text(
                                      'تعديل',
                                      style: TextStyle(
                                        color: _green600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                _buildInfoRow(
                                  'الاسم',
                                  _name,
                                  Icons.person_outline,
                                ),
                                const Divider(indent: 16, endIndent: 16),
                                _buildInfoRow(
                                  'البريد الإلكتروني',
                                  _email,
                                  Icons.email_outlined,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── قسم الأمان ──
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.lock_outline,
                                color: _green600,
                              ),
                              title: const Text(
                                'تغيير كلمة المرور',
                                style: TextStyle(fontSize: 14),
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.grey,
                              ),
                              onTap: _showChangePasswordDialog,
                            ),
                          ),

                          const Spacer(),

                          // ── زر تسجيل الخروج ──
                          // ── زر تسجيل الخروج ──
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  // 🔥 NEW: Set user to offline before logging out
                                  final uid =
                                      FirebaseAuth.instance.currentUser?.uid;
                                  if (uid != null) {
                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(uid)
                                          .update({'isOnline': false});
                                    } catch (e) {
                                      debugPrint(
                                        'Error updating online status: $e',
                                      );
                                    }
                                  }

                                  await AuthService().signOut();
                                  if (!context.mounted) return;
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SplashScreen(),
                                    ),
                                    (_) => false,
                                  );
                                },
                                icon: const Icon(Icons.logout),
                                label: const Text(
                                  'تسجيل الخروج',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFCC0000),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: _green600, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
