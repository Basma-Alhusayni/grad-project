import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/green_button.dart';
import 'user_home_screen.dart';

class UserAuthScreen extends StatefulWidget {
  const UserAuthScreen({super.key});
  @override
  State<UserAuthScreen> createState() => _UserAuthScreenState();
}

class _UserAuthScreenState extends State<UserAuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _auth = AuthService();
  bool _loading = false;
  String? _error;

  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  final _signupName = TextEditingController();
  final _signupUsername = TextEditingController();
  final _signupEmail = TextEditingController();
  final _signupPass = TextEditingController();
  final _signupConfirm = TextEditingController();

  final _loginKey = GlobalKey<FormState>();
  final _signupKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_loginKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final res = await _auth.login(
        email: _loginEmail.text.trim(),
        password: _loginPass.text,
        expectedRole: 'user');
    if (!mounted) return;
    setState(() => _loading = false);
    if (res['error'] != null) {
      setState(() => _error = res['error']);
    } else {
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const UserHomeScreen()),
              (_) => false);
    }
  }

  Future<void> _signup() async {
    if (!_signupKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final err = await _auth.registerUser(
        email: _signupEmail.text.trim(),
        password: _signupPass.text,
        username: _signupUsername.text.trim(),
        fullName: _signupName.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const UserHomeScreen()),
              (_) => false);
    }
  }

  void _forgotPassword() {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('نسيت كلمة المرور؟', textDirection: TextDirection.rtl),
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('أدخل بريدك الإلكتروني وسنرسل لك رابطاً لإعادة تعيين كلمة المرور'),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                  hintText: 'example@email.com', border: OutlineInputBorder()),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () async {
              if (emailCtrl.text.isEmpty) return;
              final err = await _auth.resetPassword(emailCtrl.text.trim());
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(err ?? 'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك'),
                backgroundColor: err == null ? Colors.green : Colors.red,
              ));
            },
            child: const Text('إرسال', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Reusable right-aligned label
  Widget _label(String text) => Align(
    alignment: Alignment.centerRight,
    child: Text(text,
        style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF374151),
            fontWeight: FontWeight.w500)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Row(children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF16A34A)),
                  label: const Text('رجوع', style: TextStyle(color: Color(0xFF16A34A))),
                ),
              ]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                child: const Icon(Icons.person, size: 40, color: Color(0xFF16A34A)),
              ),
              const SizedBox(height: 12),
              const Text('حساب المستخدم',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF14532D))),
              const Text('سجل دخول أو أنشئ حساب جديد',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 4))
                    ]),
                child: Column(children: [
                  Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12)),
                    child: TabBar(
                      controller: _tab,
                      indicator: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(10)),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey[600],
                      tabs: const [
                        Tab(text: 'تسجيل الدخول'),
                        Tab(text: 'إنشاء حساب'),
                      ],
                    ),
                  ),
                  // Error banner
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA))),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!,
                              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13))),
                        ]),
                      ),
                    ),

                  // ── LOGIN TAB ──────────────────────────────────────────
                  if (_tab.index == 0)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _loginKey,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          _label('البريد الإلكتروني'),
                          const SizedBox(height: 6),
                          AuthTextField(
                            hint: 'example@email.com',
                            icon: Icons.email_outlined,
                            controller: _loginEmail,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: 12),
                          _label('كلمة المرور'),
                          const SizedBox(height: 6),
                          AuthTextField(
                            hint: '••••••••',
                            icon: Icons.lock_outline,
                            controller: _loginPass,
                            obscure: true,
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _forgotPassword,
                              child: const Text('نسيت كلمة المرور؟',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF16A34A))),
                            ),
                          ),
                          const SizedBox(height: 4),
                          GreenButton(
                            label: 'تسجيل الدخول',
                            icon: Icons.eco,
                            onPressed: _login,
                            isLoading: _loading,
                          ),
                          const SizedBox(height: 8),
                        ]),
                      ),
                    ),

                  // ── SIGNUP TAB ─────────────────────────────────────────
                  if (_tab.index == 1)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _signupKey,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          _label('الاسم الكامل'),
                          const SizedBox(height: 6),
                          AuthTextField(
                            hint: 'أدخل اسمك الكامل',
                            icon: Icons.person_outline,
                            controller: _signupName,
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: 12),
                          _label('اسم المستخدم'),
                          const SizedBox(height: 6),
                          AuthTextField(
                            hint: 'أدخل اسم المستخدم',
                            icon: Icons.alternate_email,
                            controller: _signupUsername,
                            validator: (v) => v!.length < 3
                                ? 'يجب أن يكون 3 أحرف على الأقل'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _label('البريد الإلكتروني'),
                          const SizedBox(height: 6),
                          AuthTextField(
                            hint: 'example@email.com',
                            icon: Icons.email_outlined,
                            controller: _signupEmail,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: 12),
                          _label('كلمة المرور'),
                          const SizedBox(height: 6),
                          AuthTextField(
                            hint: '••••••••',
                            icon: Icons.lock_outline,
                            controller: _signupPass,
                            obscure: true,
                            validator: (v) => v!.length < 6
                                ? 'يجب أن تكون 6 أحرف على الأقل'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _label('تأكيد كلمة المرور'),
                          const SizedBox(height: 6),
                          AuthTextField(
                            hint: '••••••••',
                            icon: Icons.lock_outline,
                            controller: _signupConfirm,
                            obscure: true,
                            validator: (v) => v != _signupPass.text
                                ? 'كلمة المرور غير متطابقة'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          GreenButton(
                            label: 'إنشاء حساب',
                            icon: Icons.eco,
                            onPressed: _signup,
                            isLoading: _loading,
                          ),
                          const SizedBox(height: 8),
                        ]),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 16),
              const Text('جميع الحقوق محفوظة © 2025 BioShield',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}