import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

// Initializes Flutter and Firebase then launches the app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BioShieldApp());
}

class BioShieldApp extends StatelessWidget {
  const BioShieldApp({super.key});

  // Builds the root MaterialApp with the Cairo font, green color scheme, and splash screen as the starting page
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioShield',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
        ColorScheme.fromSeed(seedColor: const Color(0xFF16A34A)),
        fontFamily: 'Cairo',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}