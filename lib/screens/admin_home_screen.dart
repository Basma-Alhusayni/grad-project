import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  String _name = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchName();
  }

  Future<void> _fetchName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('admins')
        .doc(uid)
        .get();
    if (!mounted) return;
    setState(() {
      _name = doc.data()?['username'] ?? '';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        title: Image.asset('assets/images/logo.png', height: 36),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF16A34A)),
            onPressed: () async {
              await AuthService().signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                      (_) => false);
            },
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
            : Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: RichText(
                  textAlign: TextAlign.right,
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF14532D)),
                    children: [
                      const TextSpan(text: 'مرحباً '),
                      TextSpan(
                        text: _name,
                        style: const TextStyle(color: Color(0xFF16A34A)),
                      ),
                      const TextSpan(text: ' !'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('لوحة تحكم الإدارة',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}