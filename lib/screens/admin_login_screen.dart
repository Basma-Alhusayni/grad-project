import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/green_button.dart';
import 'admin_home_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _auth = AuthService();
  bool _loading = false;
  String? _error;
  String? _success;

  final _loginUser = TextEditingController();
  final _loginPass = TextEditingController();
  final _signupUser = TextEditingController();
  final _signupEmail = TextEditingController();
  final _signupPass = TextEditingController();
  final _signupConfirm = TextEditingController();

  final _loginKey = GlobalKey<FormState>();
  final _signupKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() { _error = null; _success = null; }));
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
        email: _loginUser.text.trim(),
        password: _loginPass.text,
        expectedRole: 'admin');
    if (!mounted) return;
    setState(() => _loading = false);
    if (res['error'] != null) {
      setState(() => _error = res['error']);
    } else {
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
              (_) => false);
    }
  }

  Future<void> _signup() async {
    if (!_signupKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; _success = null; });
    final err = await _auth.registerAdmin(
        email: _signupEmail.text.trim(),
        password: _signupPass.text,
        username: _signupUser.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      setState(() => _success = 'تم إنشاء الحساب بنجاح! جاري تسجيل الدخول...');
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
              (_) => false);
    }
  }

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
              const SizedBox(height: 8),
              Container(
                width: 110, height: 110,
                decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))]),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('BioShield',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF14532D))),
              const Text('لوحة تحكم الإدارة',
                  style: TextStyle(color: Color(0xFF16A34A))),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 4))
                    ]),
                child: Column(children: [
                  const SizedBox(height: 16),
                  Row(children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF16A34A)),
                        label: const Text('رجوع', style: TextStyle(color: Color(0xFF16A34A))),
                      ),
                    ),
                  ]),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                    child: const Icon(Icons.shield, size: 36, color: Color(0xFF16A34A)),
                  ),
                  const SizedBox(height: 8),
                  const Text('حساب الإدارة',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF14532D))),
                  const Text('سجل دخول أو أنشئ حساب جديد',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
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
                  // Feedback banners
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                  if (_success != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF86EFAC))),
                        child: Row(children: [
                          const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_success!,
                              style: const TextStyle(color: Color(0xFF15803D), fontSize: 13))),
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
                            hint: 'أدخل اسم المستخدم',
                            icon: Icons.person_outline,
                            controller: _loginUser,
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
                          const SizedBox(height: 20),
                          GreenButton(
                            label: 'تسجيل الدخول',
                            icon: Icons.shield,
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
                          _label('اسم المستخدم'),
                          const SizedBox(height: 6),
                          AuthTextField(
                            hint: 'أدخل اسم المستخدم',
                            icon: Icons.person_outline,
                            controller: _signupUser,
                            validator: (v) => v!.length < 3
                                ? 'يجب أن يكون 3 أحرف على الأقل'
                                : null,
                            enabled: _success == null,
                          ),
                          const SizedBox(height: 12),
                          _label('البريد الإلكتروني'),
                          const SizedBox(height: 6),
                          AuthTextField(
                            hint: 'admin@bioshield.com',
                            icon: Icons.email_outlined,
                            controller: _signupEmail,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                            enabled: _success == null,
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
                            enabled: _success == null,
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
                            enabled: _success == null,
                          ),
                          const SizedBox(height: 16),
                          GreenButton(
                            label: 'إنشاء حساب',
                            icon: Icons.shield,
                            onPressed: _success == null ? _signup : null,
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