import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Start the auth check as soon as the splash screen opens
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  // Waits 2 seconds then checks if the user is logged in, verifies their role, and navigates to the right screen
  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final bool rememberMe = prefs.getBool('remember_me') ?? false;
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && !rememberMe) {
      await FirebaseAuth.instance.signOut();
      _go(const LoginScreen());
      return;
    }

    if (user == null) {
      _go(const LoginScreen());
      return;
    }

    try {
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser!;

      final doc = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(refreshedUser.uid)
          .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        _go(const LoginScreen());
        return;
      }

      final data = doc.data()!;
      final role = data['role'] ?? 'user';
      final isFirstLogin = data['isFirstLogin'] == true;

      if (!mounted) return;

      if (role == 'specialist' && isFirstLogin) {
        _go(const FirstLoginScreen());
        return;
      }

      if ((role == 'user' || role == 'admin') && !refreshedUser.emailVerified) {
        _go(EmailVerificationScreen(email: refreshedUser.email ?? ''));
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
    } catch (e) {
      _go(const LoginScreen());
    }
  }

  // Replaces the current screen with the given screen
  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  // Builds the splash screen with the app logo, name, and a loading spinner
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
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.eco,
                        color: Color(0xFF16A34A),
                        size: 64),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'BioShield',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF14532D)),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
                color: Color(0xFF16A34A)),
          ],
        ),
      ),
    );
  }
}