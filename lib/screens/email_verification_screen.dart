import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'splash_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _pollTimer;
  Timer? _cooldownTimer;
  bool _resending = false;
  bool _checking = false;
  int _cooldown = 0;

  static const _green600 = Color(0xFF16A34A);
  static const _green900 = Color(0xFF14532D);
  static const _green50 = Color(0xFFF0FDF4);

  // Start a timer that checks every 3 seconds if the user has verified their email
  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await FirebaseAuth.instance.currentUser?.reload();
      if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
        _pollTimer?.cancel();
        if (mounted) _navigateForward();
      }
    });
  }

  // Cancel both timers when the screen is removed to avoid memory leaks
  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // Goes to the splash screen and clears the navigation stack after verification
  void _navigateForward() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
          (_) => false,
    );
  }

  // Resends the verification email and starts a 60-second cooldown to prevent spam
  Future<void> _resendEmail() async {
    if (_cooldown > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ تم إعادة إرسال رابط التحقق',
            textDirection: TextDirection.rtl),
        backgroundColor: _green600,
      ));
      setState(() => _cooldown = 60);
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        setState(() {
          _cooldown--;
          if (_cooldown <= 0) t.cancel();
        });
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('❌ حدث خطأ، حاول مجدداً',
              textDirection: TextDirection.rtl),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  // Reloads the user's auth state and navigates forward if email is now verified
  Future<void> _checkManually() async {
    setState(() => _checking = true);
    await FirebaseAuth.instance.currentUser?.reload();
    if (!mounted) return;
    setState(() => _checking = false);
    if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
      _pollTimer?.cancel();
      _navigateForward();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('لم يتم التحقق بعد، يرجى التحقق من بريدك الإلكتروني',
            textDirection: TextDirection.rtl),
        backgroundColor: Colors.orange,
      ));
    }
  }

  // Cancels the poll timer, signs the user out, and goes back to the splash screen
  Future<void> _signOut() async {
    _pollTimer?.cancel();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
          (_) => false,
    );
  }

  // Builds the verification screen with the user's email, info box, verify button, resend button, and sign out option
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _green50,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mark_email_unread_outlined,
                        color: _green600, size: 52),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'تحقق من بريدك الإلكتروني',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _green900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'لقد أرسلنا رابط التحقق إلى:',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.email,
                      style: const TextStyle(
                        color: _green900,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'افتح بريدك الإلكتروني واضغط على رابط التحقق. سيتم تسجيل دخولك تلقائياً.',
                          style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 13),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _checking ? null : _checkManually,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green600,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: _checking
                          ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline,
                          color: Colors.white),
                      label: const Text('لقد تحققت من بريدي',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: (_cooldown > 0 || _resending) ? null : _resendEmail,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _green600),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _resending
                          ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: _green600, strokeWidth: 2))
                          : const Icon(Icons.refresh, color: _green600),
                      label: Text(
                        _cooldown > 0
                            ? 'إعادة الإرسال ($_cooldown ث)'
                            : 'إعادة إرسال رابط التحقق',
                        style: const TextStyle(color: _green600, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout, color: Colors.grey, size: 18),
                    label: const Text('تسجيل الخروج والعودة',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}