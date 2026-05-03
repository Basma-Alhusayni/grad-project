import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../widgets/validated_field.dart';
import '../widgets/green_button.dart';
import 'user_home_screen.dart';
import 'email_verification_screen.dart';

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
  bool _rememberMe = false;

  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  bool _loginPassVisible = false;

  final _signupName = TextEditingController();
  final _signupUsername = TextEditingController();
  final _signupEmail = TextEditingController();
  final _signupPass = TextEditingController();
  final _signupConfirm = TextEditingController();
  bool _signupPassVisible = false;
  bool _signupConfirmVisible = false;

  String? _loginEmailError;
  String? _loginPassError;

  String? _nameError;
  String? _usernameError;
  String? _emailError;
  String? _passError;
  String? _confirmError;

  // Set up the tab controller and attach live validators to all input fields
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) {
        setState(() => _error = null);
      }
    });

    _loginEmail.addListener(_validateLoginEmail);
    _loginPass.addListener(_validateLoginPass);

    _signupName.addListener(_validateName);
    _signupUsername.addListener(_validateUsername);
    _signupEmail.addListener(_validateEmail);
    _signupPass.addListener(_validatePassword);
    _signupConfirm.addListener(_validateConfirm);
  }

  // Clean up the tab controller and all text controllers
  @override
  void dispose() {
    _tab.dispose();
    _loginEmail.dispose();
    _loginPass.dispose();
    _signupName.dispose();
    _signupUsername.dispose();
    _signupEmail.dispose();
    _signupPass.dispose();
    _signupConfirm.dispose();
    super.dispose();
  }

  // Checks if the login email format is valid while the user types
  void _validateLoginEmail() {
    final v = _loginEmail.text.trim();
    final reg = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    setState(() {
      if (v.isEmpty) _loginEmailError = null;
      else if (!reg.hasMatch(v)) _loginEmailError = 'صيغة البريد غير صحيحة';
      else _loginEmailError = null;
    });
  }

  // Checks that the login password is at least 6 characters
  void _validateLoginPass() {
    final v = _loginPass.text;
    setState(() {
      if (v.isNotEmpty && v.length < 6) _loginPassError = 'يجب أن تكون 6 أحرف على الأقل';
      else _loginPassError = null;
    });
  }

  // Checks that the full name field is not empty
  void _validateName() => setState(() => _nameError = _signupName.text.trim().isEmpty ? 'الاسم الكامل مطلوب' : null);

  // Checks that the username is present and at least 3 characters
  void _validateUsername() {
    final v = _signupUsername.text.trim();
    setState(() => _usernameError = v.isEmpty ? 'اسم المستخدم مطلوب' : (v.length < 3 ? 'يجب أن يكون 3 أحرف على الأقل' : null));
  }

  // Checks that the signup email is present and correctly formatted
  void _validateEmail() {
    final v = _signupEmail.text.trim();
    final reg = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    setState(() => _emailError = v.isEmpty ? 'البريد الإلكتروني مطلوب' : (!reg.hasMatch(v) ? 'صيغة البريد غير صحيحة' : null));
  }

  // Checks that the signup password is present and at least 6 characters, then re-validates the confirm field
  void _validatePassword() {
    final v = _signupPass.text;
    setState(() => _passError = v.isEmpty ? 'كلمة المرور مطلوبة' : (v.length < 6 ? 'يجب أن تكون 6 أحرف على الأقل' : null));
    if (_signupConfirm.text.isNotEmpty) _validateConfirm();
  }

  // Checks that the confirm password matches the signup password
  void _validateConfirm() {
    setState(() => _confirmError = _signupConfirm.text.isEmpty ? 'تأكيد كلمة المرور مطلوب' : (_signupConfirm.text != _signupPass.text ? 'كلمة المرور غير متطابقة' : null));
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
    child: Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF374151), fontWeight: FontWeight.w500)),
  );

  // Validates fields then logs the user in, sets them online, and navigates to the home screen
  Future<void> _login() async {
    if (_loginEmail.text.trim().isEmpty || _loginPass.text.isEmpty) {
      setState(() => _error = 'يرجى ملء جميع الحقول');
      return;
    }
    if (_loginEmailError != null || _loginPassError != null) return;

    setState(() { _loading = true; _error = null; });
    final res = await _auth.login(
      email: _loginEmail.text.trim(),
      password: _loginPass.text,
      expectedRole: 'user',
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (res['needsVerification'] == true) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => EmailVerificationScreen(email: _loginEmail.text.trim())));
      return;
    }

    if (res['error'] != null) {
      setState(() => _error = res['error']);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', _rememberMe);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'isOnline': true,
          });
        } catch (e) {
          debugPrint('Error updating online status: $e');
        }
      }

      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const UserHomeScreen()), (_) => false);
    }
  }


  // Validates all signup fields then creates the account and navigates to the email verification screen
  Future<void> _signup() async {
    _validateName(); _validateUsername(); _validateEmail(); _validatePassword(); _validateConfirm();
    if (_nameError != null || _usernameError != null || _emailError != null || _passError != null || _confirmError != null) return;

    setState(() { _loading = true; _error = null; });
    final err = await _auth.registerUser(
      email: _signupEmail.text.trim(),
      password: _signupPass.text,
      username: _signupUsername.text.trim(),
      fullName: _signupName.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => EmailVerificationScreen(email: _signupEmail.text.trim())), (_) => false);
    }
  }

  // Shows a dialog where the user can enter their email to receive a password reset link
  void _forgotPassword() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('نسيت كلمة المرور؟', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14532D))),
          content: TextField(
            controller: ctrl,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(hintText: 'أدخل بريدك الإلكتروني', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              onPressed: () async {
                final err = await _auth.resetPassword(ctrl.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(err ?? 'تم إرسال رابط إعادة التعيين لبريدك'),
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

  // Builds the user auth screen with two tabs: login and sign up
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF16A34A)),
                      label: const Text('رجوع', style: TextStyle(color: Color(0xFF16A34A))),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                    child: const Icon(Icons.person, size: 64, color: Color(0xFF16A34A)),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 4))]),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                          child: TabBar(
                            controller: _tab,
                            indicator: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(10)),
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.grey[600],
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                            tabs: const [Tab(text: 'تسجيل الدخول'), Tab(text: 'إنشاء حساب')],
                          ),
                        ),

                        if (_tab.index == 0)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _label('البريد الإلكتروني'),
                                const SizedBox(height: 6),
                                ValidatedField(hint: 'example@email.com', icon: Icons.email_outlined, controller: _loginEmail, errorText: _loginEmailError),
                                const SizedBox(height: 12),
                                _label('كلمة المرور'),
                                const SizedBox(height: 6),
                                PasswordField(
                                  hint: '••••••••',
                                  controller: _loginPass,
                                  visible: _loginPassVisible,
                                  errorText: _loginPassError,
                                  onToggle: () => setState(() => _loginPassVisible = !_loginPassVisible),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(children: [
                                      Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v!), activeColor: const Color(0xFF16A34A)),
                                      const Text('تذكرني', style: TextStyle(fontSize: 12)),
                                    ]),
                                    TextButton(onPressed: _forgotPassword, child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: Color(0xFF16A34A), fontSize: 12))),
                                  ],
                                ),

                                if (_error != null) _errorBox(_error!),

                                const SizedBox(height: 10),
                                GreenButton(label: 'تسجيل الدخول', onPressed: _login, isLoading: _loading),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),

                        if (_tab.index == 1)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _label('الاسم الكامل'),
                                const SizedBox(height: 6),
                                ValidatedField(hint: 'أدخل اسمك الكامل', icon: Icons.person_outline, controller: _signupName, errorText: _nameError),
                                const SizedBox(height: 12),
                                _label('اسم المستخدم'),
                                const SizedBox(height: 6),
                                ValidatedField(hint: 'أدخل اسم المستخدم', icon: Icons.alternate_email, controller: _signupUsername, errorText: _usernameError),
                                const SizedBox(height: 12),
                                _label('البريد الإلكتروني'),
                                const SizedBox(height: 6),
                                ValidatedField(hint: 'example@email.com', icon: Icons.email_outlined, controller: _signupEmail, errorText: _emailError, keyboardType: TextInputType.emailAddress),
                                const SizedBox(height: 12),
                                _label('كلمة المرور'),
                                const SizedBox(height: 6),
                                PasswordField(hint: '••••••••', controller: _signupPass, visible: _signupPassVisible, errorText: _passError, onToggle: () => setState(() => _signupPassVisible = !_signupPassVisible)),
                                const SizedBox(height: 12),
                                _label('تأكيد كلمة المرور'),
                                const SizedBox(height: 6),
                                PasswordField(hint: '••••••••', controller: _signupConfirm, visible: _signupConfirmVisible, errorText: _confirmError, onToggle: () => setState(() => _signupConfirmVisible = !_signupConfirmVisible)),

                                if (_error != null) _errorBox(_error!),

                                const SizedBox(height: 16),
                                GreenButton(label: 'إنشاء حساب', onPressed: _signup, isLoading: _loading),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text('جميع الحقوق محفوظة © 2026 BioShield', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}