import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../widgets/validated_field.dart';
import '../widgets/green_button.dart';
import 'admin_home_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _auth = AuthService();
  bool _loading = false;
  String? _error;
  bool _rememberMe = false;

  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  bool _loginPassVisible = false;

  String? _emailError;
  String? _passError;

  // Start listening to email and password fields as the user types
  @override
  void initState() {
    super.initState();
    _loginEmail.addListener(_validateEmail);
    _loginPass.addListener(_validatePassword);
  }

  // Clean up controllers and listeners when the screen is removed
  @override
  void dispose() {
    _loginEmail.removeListener(_validateEmail);
    _loginPass.removeListener(_validatePassword);
    _loginEmail.dispose();
    _loginPass.dispose();
    super.dispose();
  }

  // Checks if the email format is valid while the user types
  void _validateEmail() {
    final v = _loginEmail.text.trim();
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    setState(() {
      if (v.isEmpty) {
        _emailError = null;
      } else if (!regex.hasMatch(v)) {
        _emailError = 'صيغة البريد الإلكتروني غير صحيحة';
      } else {
        _emailError = null;
      }
    });
  }

  // Checks that the password is at least 6 characters
  void _validatePassword() {
    final v = _loginPass.text;
    setState(() {
      if (v.isNotEmpty && v.length < 6) {
        _passError = 'يجب أن تكون 6 أحرف على الأقل';
      } else {
        _passError = null;
      }
    });
  }

  // Validates fields then tries to log in as admin, saves remember-me preference on success
  Future<void> _login() async {
    if (_loginEmail.text.trim().isEmpty || _loginPass.text.isEmpty) {
      setState(() => _error = 'يرجى ملء جميع الحقول');
      return;
    }
    if (_emailError != null || _passError != null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await _auth.login(
      email: _loginEmail.text.trim(),
      password: _loginPass.text,
      expectedRole: 'admin',
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (res['error'] != null) {
      setState(() => _error = res['error']);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', _rememberMe);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
            (route) => false,
      );
    }
  }

  // Shows a dialog where admin can enter their email to receive a password reset link
  void _forgotPassword() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('استعادة كلمة المرور',
              style: TextStyle(color: Color(0xFF14532D), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('أدخل بريد الإدارة لإرسال رابط إعادة التعيين:'),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'admin@bioshield.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (ctrl.text.isEmpty) return;
                final err = await _auth.resetPassword(ctrl.text.trim());
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(err ?? 'تم إرسال رابط إعادة تعيين كلمة المرور بنجاح'),
                  backgroundColor: err == null ? Colors.green : Colors.red,
                ));
              },
              child: const Text('إرسال', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // A red box that displays an error message to the user
  Widget _errorBox(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // A small right-aligned label shown above each input field
  Widget _label(String text) => Align(
    alignment: Alignment.centerRight,
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF374151),
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  // Builds the full login screen with logo, input fields, remember-me checkbox, and login button
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: TextButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                  Icons.arrow_back, color: Color(0xFF16A34A)),
                              label: const Text('رجوع',
                                  style: TextStyle(color: Color(0xFF16A34A))),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield, size: 64,
                                color: Color(0xFF16A34A)),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12,
                                    blurRadius: 20,
                                    offset: Offset(0, 4))
                              ],
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      _label('البريد الإلكتروني'),
                                      const SizedBox(height: 6),
                                      ValidatedField(
                                        hint: 'admin@bioshield.com',
                                        icon: Icons.email_outlined,
                                        controller: _loginEmail,
                                        errorText: _emailError,
                                        keyboardType: TextInputType
                                            .emailAddress,
                                      ),
                                      const SizedBox(height: 12),
                                      _label('كلمة المرور'),
                                      const SizedBox(height: 6),
                                      PasswordField(
                                        hint: '••••••••',
                                        controller: _loginPass,
                                        visible: _loginPassVisible,
                                        errorText: _passError,
                                        onToggle: () =>
                                            setState(() =>
                                            _loginPassVisible =
                                            !_loginPassVisible),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment
                                            .spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Checkbox(
                                                value: _rememberMe,
                                                onChanged: (v) =>
                                                    setState(() =>
                                                    _rememberMe = v!),
                                                activeColor: const Color(
                                                    0xFF16A34A),
                                              ),
                                              const Text('تذكرني',
                                                  style: TextStyle(
                                                      fontSize: 12)),
                                            ],
                                          ),
                                          TextButton(
                                            onPressed: _forgotPassword,
                                            child: const Text(
                                                'نسيت كلمة المرور؟',
                                                style: TextStyle(
                                                    color: Color(0xFF16A34A),
                                                    fontSize: 12)),
                                          ),
                                        ],
                                      ),
                                      if (_error != null) _errorBox(_error!),
                                      const SizedBox(height: 10),
                                      GreenButton(label: 'تسجيل الدخول',
                                          onPressed: _login,
                                          isLoading: _loading),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          const Text(
                              'جميع الحقوق محفوظة © 2026 BioShield',
                              style: TextStyle(color: Colors.grey, fontSize: 12)
                          ),
                          const SizedBox(height: 8),
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
}