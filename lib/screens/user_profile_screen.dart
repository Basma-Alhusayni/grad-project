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

class _UserProfileScreenState extends State<UserProfileScreen>
    with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    _fetchUserData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchUserData();
    }
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // reload to get latest Auth state
    await user.reload();
    final authEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    // sync email from Auth to Firestore if different
    final firestoreEmail = userDoc.data()?['email'] ?? '';
    if (authEmail.isNotEmpty && authEmail != firestoreEmail) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'email': authEmail});
      await FirebaseFirestore.instance
          .collection('accounts')
          .doc(user.uid)
          .update({'email': authEmail});
    }

    String name = userDoc.data()?['fullName'] ?? userDoc.data()?['username'] ?? '';

    if (name.isEmpty) {
      final accountDoc = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(user.uid)
          .get();
      name = accountDoc.data()?['fullName'] ??
          accountDoc.data()?['username'] ?? '';
    }

    if (name.isEmpty) {
      name = user.email?.split('@')[0] ?? '';
    }

    if (!mounted) return;
    setState(() {
      _name = name;
      _email = authEmail.isNotEmpty ? authEmail : firestoreEmail;
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

  void _showChangeEmailDialog() {
    final emailController = TextEditingController();
    String? emailError;
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
              'تغيير البريد الإلكتروني',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _green900,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أدخل بريدك الإلكتروني الجديد. سيتم إرسال رابط تحقق إليه.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  onChanged: (v) => setDialogState(() {
                    emailError = v.trim().isEmpty
                        ? 'البريد الإلكتروني مطلوب'
                        : !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())
                        ? 'صيغة البريد غير صحيحة'
                        : null;
                  }),
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني الجديد',
                    prefixIcon: const Icon(Icons.email_outlined, color: _green600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    errorText: emailError,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ستحتاج لإعادة تسجيل الدخول بعد تغيير البريد',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                  final newEmail = emailController.text.trim();
                  if (newEmail.isEmpty ||
                      !RegExp(r'^[^@]+@[^@]+\.[^@]+')
                          .hasMatch(newEmail)) {
                    setDialogState(
                            () => emailError = 'أدخل بريداً صحيحاً');
                    return;
                  }
                  if (newEmail == _email) {
                    setDialogState(
                            () => emailError = 'هذا هو بريدك الحالي');
                    return;
                  }
                  setDialogState(() => saving = true);
                  try {
                    final user = FirebaseAuth.instance.currentUser!;
                    final uid = user.uid;

                    // 1. إرسال رابط تحقق للبريد الجديد
                    await user.verifyBeforeUpdateEmail(newEmail);

                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '✅ تم إرسال رابط التحقق إلى بريدك الجديد. تحقق منه لإتمام التغيير.',
                        ),
                        backgroundColor: _green600,
                        duration: Duration(seconds: 5),
                      ),
                    );
                  } on FirebaseAuthException catch (e) {
                    setDialogState(() => saving = false);
                    String msg = 'حدث خطأ';
                    if (e.code == 'requires-recent-login') {
                      msg = 'يرجى تسجيل الخروج والدخول مجدداً ثم المحاولة';
                    } else if (e.code == 'email-already-in-use') {
                      msg = 'هذا البريد مستخدم بالفعل';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(msg),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _green600),
                child: saving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
                    : const Text('إرسال رابط التحقق',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Delete user's account ────────────────

  Future<void> _deleteAccount() async {
    // Step 1 — Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'حذف الحساب نهائياً',
            style: TextStyle(
                color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'هذا الإجراء لا يمكن التراجع عنه. سيتم حذف:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              _deleteItem('بياناتك الشخصية'),
              _deleteItem('جميع تقاريرك'),
              _deleteItem('منشوراتك في المجتمع'),
              _deleteItem('حسابك بشكل كامل'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Row(children: [
                  Icon(Icons.warning_amber, color: Colors.red, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لا يمكن استرجاع أي بيانات بعد الحذف',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('حذف حسابي',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    // Step 2 — Password re-authentication dialog (required by Firebase)
    final passwordController = TextEditingController();
    bool obscure = true;
    String? authError;

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'تأكيد الهوية',
              style: TextStyle(
                  color: _green900, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أدخل كلمة المرور الحالية لتأكيد حذف الحساب.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon:
                    const Icon(Icons.lock_outline, color: _green600),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey),
                      onPressed: () =>
                          setDialogState(() => obscure = !obscure),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    errorText: authError,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child:
                const Text('إلغاء', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(ctx, passwordController.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('تأكيد الحذف',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );

    if (password == null || password.isEmpty) return;

    // Step 3 — Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: _green600),
        ),
      );
    }

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final uid = user.uid;

      // Step 4 — Re-authenticate
      final credential = EmailAuthProvider.credential(
        email: _email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Step 5 — Delete all Firestore data in parallel
      await Future.wait([
        // Delete user doc
        FirebaseFirestore.instance.collection('users').doc(uid).delete(),

        // Delete account doc
        FirebaseFirestore.instance.collection('accounts').doc(uid).delete(),

        // Delete user's AI reports
        _deleteCollection('reports', 'userId', uid),

        // Delete user's specialist reports
        _deleteCollection('specialist_reports', 'userId', uid),

        // Delete community feed posts shared by user
        _deleteCollection('community_feed', 'userId', uid),

        // Delete shared_reports entries by user
        _deleteCollection('shared_reports', 'userId', uid),
      ]);

      // Step 6 — Delete Firebase Auth account
      await user.delete();

      // Step 7 — Navigate to splash
      if (mounted) {
        Navigator.pop(context); // close loading
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen()),
              (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context); // close loading
      String msg = 'حدث خطأ أثناء الحذف';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'كلمة المرور غير صحيحة';
      } else if (e.code == 'requires-recent-login') {
        msg = 'يرجى تسجيل الخروج والدخول مجدداً ثم المحاولة';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg, textDirection: TextDirection.rtl),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ خطأ: $e', textDirection: TextDirection.rtl),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

// ── Helper: delete all docs in a collection matching a field ──
  Future<void> _deleteCollection(
      String collection, String field, String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .where(field, isEqualTo: uid)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

// ── Helper: bullet point row in confirm dialog ────────────────
  Widget _deleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        const Icon(Icons.remove_circle_outline, color: Colors.red, size: 14),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 13)),
      ]),
    );
  }

// ── changing password ────────────────
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
                                      'تعديل الاسم',
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
                            child: Column(
                              children: [
                                ListTile(
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
                                const Divider(height: 1, indent: 16, endIndent: 16),
                                ListTile(
                                  leading: const Icon(Icons.email_outlined, color: _green600),
                                  title: const Text('تغيير البريد الإلكتروني',
                                      style: TextStyle(fontSize: 14)),
                                  trailing: const Icon(Icons.arrow_forward_ios,
                                      size: 14, color: Colors.grey),
                                  onTap: _showChangeEmailDialog,
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          // ── زر حذف الحساب ──
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: OutlinedButton.icon(
                                onPressed: _deleteAccount,
                                icon: const Icon(Icons.delete_forever, color: Colors.red),
                                label: const Text(
                                  'حذف الحساب',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ),
                          // ── زر تسجيل الخروج ──
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
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
