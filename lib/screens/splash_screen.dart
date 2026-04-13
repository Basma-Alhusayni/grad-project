import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'user_home_screen.dart';
import 'expert_home_screen.dart';
import 'admin_home_screen.dart';
import 'first_login_screen.dart';
import 'email_verification_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _go(const LoginScreen());
      return;
    }

    await user.reload();
    final refreshed = FirebaseAuth.instance.currentUser!;

    final doc = await FirebaseFirestore.instance
        .collection('accounts')
        .doc(refreshed.uid)
        .get();

    if (!doc.exists) {
      _go(const LoginScreen());
      return;
    }

    final role = doc.data()?['role'] ?? 'user';
    final isFirstLogin = doc.data()?['isFirstLogin'] == true;

    if (!mounted) return;

    // Specialist first login → force password change
    if (role == 'specialist' && isFirstLogin) {
      _go(const FirstLoginScreen());
      return;
    }

    // User or admin not yet verified → go to verification screen
    if ((role == 'user' || role == 'admin') &&
        !refreshed.emailVerified) {
      _go(EmailVerificationScreen(email: refreshed.email ?? ''));
      return;
    }

    switch (role) {
      case 'admin':
        _go(const AdminHomeScreen());
        break;
      case 'specialist':
        _go(const ExpertHomeScreen());
        break;
      default:
        _go(const UserHomeScreen());
    }
  }

  void _go(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, 4))
                ],
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                        Icons.eco,
                        color: Color(0xFF16A34A),
                        size: 64),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('BioShield',
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF14532D))),
            const SizedBox(height: 8),
            const Text('حماية نباتاتك بالذكاء الاصطناعي',
                style: TextStyle(
                    fontSize: 16, color: Color(0xFF16A34A))),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
                color: Color(0xFF16A34A)),
          ],
        ),
      ),
    );
  }
}