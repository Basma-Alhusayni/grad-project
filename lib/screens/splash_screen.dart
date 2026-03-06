import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'user_home_screen.dart';
import 'expert_home_screen.dart';
import 'admin_home_screen.dart';

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
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    if (user == null) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('accounts')
        .doc(user.uid)
        .get();
    final role = doc.data()?['role'] ?? 'user';
    if (!mounted) return;
    switch (role) {
      case 'admin':
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const AdminHomeScreen()));
        break;
      case 'specialist':
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const ExpertHomeScreen()));
        break;
      default:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const UserHomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
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
                style: TextStyle(fontSize: 16, color: Color(0xFF16A34A))),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Color(0xFF16A34A)),
          ],
        ),
      ),
    );
  }
}