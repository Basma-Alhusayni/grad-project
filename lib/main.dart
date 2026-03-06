import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BioShieldApp());
}

class BioShieldApp extends StatelessWidget {
  const BioShieldApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioShield',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        fontFamily: 'Cairo', // add Cairo font or use google_fonts
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}