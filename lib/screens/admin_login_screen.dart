import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/validated_field.dart';
import '../widgets/green_button.dart';
import 'admin_home_screen.dart';
import 'email_verification_screen.dart';

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

  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  bool _loginPassVisible = false;

  final _signupUser = TextEditingController();
  final _signupEmail = TextEditingController();
  final _signupPass = TextEditingController();
  final _signupConfirm = TextEditingController();
  bool _signupPassVisible = false;
  bool _signupConfirmVisible = false;

  String? _usernameError;
  String? _emailError;
  String? _passError;
  String? _confirmError;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(
            () => setState(() => _error = null));
    _signupUser.addListener(_validateUsername);
    _signupEmail.addListener(_validateEmail);
    _signupPass.addListener(_validatePassword);
    _signupConfirm.addListener(_validateConfirm);
  }

  @override
  void dispose() {
    _tab.dispose();
    _signupUser.removeListener(_validateUsername);
    _signupEmail.removeListener(_validateEmail);
    _signupPass.removeListener(_validatePassword);
    _signupConfirm.removeListener(_validateConfirm);
    _loginEmail.dispose();
    _loginPass.dispose();
    _signupUser.dispose();
    _signupEmail.dispose();
    _signupPass.dispose();
    _signupConfirm.dispose();
    super.dispose();
  }

  void _validateUsername() {
    final v = _signupUser.text.trim();
    setState(() {
      if (v.isEmpty) {
        _usernameError = 'اسم المستخدم مطلوب';
      } else if (v.length < 3) {
        _usernameError = 'يجب أن يكون 3 أحرف على الأقل';
      } else {
        _usernameError = null;
      }
    });
  }

  void _validateEmail() {
    final v = _signupEmail.text.trim();
    setState(() {
      if (v.isEmpty) {
        _emailError = 'البريد الإلكتروني مطلوب';
      } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
        _emailError = 'صيغة البريد الإلكتروني غير صحيحة';
      } else {
        _emailError = null;
      }
    });
  }

  void _validatePassword() {
    final v = _signupPass.text;
    setState(() {
      if (v.isEmpty) {
        _passError = 'كلمة المرور مطلوبة';
      } else if (v.length < 6) {
        _passError = 'يجب أن تكون 6 أحرف على الأقل';
      } else {
        _passError = null;
      }
    });
    if (_signupConfirm.text.isNotEmpty) _validateConfirm();
  }

  void _validateConfirm() {
    setState(() {
      if (_signupConfirm.text.isEmpty) {
        _confirmError = 'تأكيد كلمة المرور مطلوب';
      } else if (_signupConfirm.text != _signupPass.text) {
        _confirmError = 'كلمة المرور غير متطابقة';
      } else {
        _confirmError = null;
      }
    });
  }

  bool get _signupValid =>
      _usernameError == null &&
          _emailError == null &&
          _passError == null &&
          _confirmError == null &&
          _signupUser.text.isNotEmpty &&
          _signupEmail.text.isNotEmpty &&
          _signupPass.text.isNotEmpty &&
          _signupConfirm.text.isNotEmpty;

  Future<void> _login() async {
    if (_loginEmail.text.trim().isEmpty ||
        _loginPass.text.isEmpty) {
      setState(() => _error = 'يرجى ملء جميع الحقول');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final res = await _auth.login(
      email: _loginEmail.text.trim(),
      password: _loginPass.text,
      expectedRole: 'admin',
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (res['needsVerification'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
              email: _loginEmail.text.trim()),
        ),
      );
      return;
    }
    if (res['error'] != null) {
      setState(() => _error = res['error']);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => const AdminHomeScreen()),
            (_) => false,
      );
    }
  }

  Future<void> _signup() async {
    _validateUsername();
    _validateEmail();
    _validatePassword();
    _validateConfirm();
    if (!_signupValid) return;

    setState(() { _loading = true; _error = null; });
    final err = await _auth.registerAdmin(
      email: _signupEmail.text.trim(),
      password: _signupPass.text,
      username: _signupUser.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
              email: _signupEmail.text.trim()),
        ),
            (_) => false,
      );
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
              // Logo
              Container(
                width: 110, height: 110,
                decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 12,
                          offset: Offset(0, 4))
                    ]),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.eco,
                          color: Color(0xFF16A34A),
                          size: 64),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('BioShield',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF14532D))),
              const Text('لوحة تحكم الإدارة',
                  style: TextStyle(color: Color(0xFF16A34A))),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          offset: Offset(0, 4))
                    ]),
                child: Column(children: [
                  const SizedBox(height: 16),
                  Row(children: [
                    Padding(
                      padding:
                      const EdgeInsets.only(right: 12),
                      child: TextButton.icon(
                        onPressed: () =>
                            Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back,
                            color: Color(0xFF16A34A)),
                        label: const Text('رجوع',
                            style: TextStyle(
                                color: Color(0xFF16A34A))),
                      ),
                    ),
                  ]),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.shield,
                        size: 36,
                        color: Color(0xFF16A34A)),
                  ),
                  const SizedBox(height: 8),
                  const Text('حساب الإدارة',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF14532D))),
                  const Text('سجل دخول أو أنشئ حساب جديد',
                      style: TextStyle(
                          color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius:
                        BorderRadius.circular(12)),
                    child: TabBar(
                      controller: _tab,
                      indicator: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius:
                          BorderRadius.circular(10)),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey[600],
                      tabs: const [
                        Tab(text: 'تسجيل الدخول'),
                        Tab(text: 'إنشاء حساب'),
                      ],
                    ),
                  ),
                  if (_error != null)
                    _errorBanner(_error!),

                  // ── LOGIN ────────────────────────────────
                  if (_tab.index == 0)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.end,
                          children: [
                            _label('البريد الإلكتروني'),
                            const SizedBox(height: 6),
                            ValidatedField(
                              hint: 'admin@bioshield.com',
                              icon: Icons.email_outlined,
                              controller: _loginEmail,
                              keyboardType:
                              TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            _label('كلمة المرور'),
                            const SizedBox(height: 6),
                            PasswordField(
                              hint: '••••••••',
                              controller: _loginPass,
                              visible: _loginPassVisible,
                              onToggle: () => setState(() =>
                              _loginPassVisible =
                              !_loginPassVisible),
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

                  // ── SIGNUP ───────────────────────────────
                  if (_tab.index == 1)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.end,
                          children: [
                            _label('اسم المستخدم'),
                            const SizedBox(height: 6),
                            ValidatedField(
                              hint: 'أدخل اسم المستخدم',
                              icon: Icons.person_outline,
                              controller: _signupUser,
                              errorText: _usernameError,
                            ),
                            const SizedBox(height: 12),
                            _label('البريد الإلكتروني'),
                            const SizedBox(height: 6),
                            ValidatedField(
                              hint: 'admin@bioshield.com',
                              icon: Icons.email_outlined,
                              controller: _signupEmail,
                              errorText: _emailError,
                              keyboardType:
                              TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            _label('كلمة المرور'),
                            const SizedBox(height: 6),
                            PasswordField(
                              hint: '••••••••',
                              controller: _signupPass,
                              visible: _signupPassVisible,
                              errorText: _passError,
                              onToggle: () => setState(() =>
                              _signupPassVisible =
                              !_signupPassVisible),
                            ),
                            const SizedBox(height: 12),
                            _label('تأكيد كلمة المرور'),
                            const SizedBox(height: 6),
                            PasswordField(
                              hint: '••••••••',
                              controller: _signupConfirm,
                              visible: _signupConfirmVisible,
                              errorText: _confirmError,
                              onToggle: () => setState(() =>
                              _signupConfirmVisible =
                              !_signupConfirmVisible),
                            ),
                            const SizedBox(height: 14),
                            _verificationNote(),
                            const SizedBox(height: 16),
                            GreenButton(
                              label: 'إنشاء حساب',
                              icon: Icons.shield,
                              onPressed: _signup,
                              isLoading: _loading,
                            ),
                            const SizedBox(height: 8),
                          ]),
                    ),
                ]),
              ),
              const SizedBox(height: 16),
              const Text('جميع الحقوق محفوظة © 2025 BioShield',
                  style: TextStyle(
                      color: Colors.grey, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}

Widget _errorBanner(String message) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
  child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border:
        Border.all(color: const Color(0xFFFECACA))),
    child: Row(children: [
      const Icon(Icons.error_outline,
          color: Colors.red, size: 20),
      const SizedBox(width: 8),
      Expanded(
          child: Text(message,
              style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 13))),
    ]),
  ),
);

Widget _verificationNote() => Container(
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: const Color(0xFFEFF6FF),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: const Color(0xFFBFDBFE)),
  ),
  child: const Row(children: [
    Icon(Icons.info_outline,
        color: Color(0xFF3B82F6), size: 16),
    SizedBox(width: 8),
    Expanded(
      child: Text(
        'سيتم إرسال رابط تحقق إلى بريدك الإلكتروني',
        style: TextStyle(
            color: Color(0xFF1D4ED8), fontSize: 12),
      ),
    ),
  ]),
);