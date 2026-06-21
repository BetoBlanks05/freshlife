import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FreshLifeApp());
}

class FreshLifeApp extends StatelessWidget {
  const FreshLifeApp({super.key});

  static const _teal = Color(0xFF4DB6AC);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FreshLife',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _teal),
        primaryColor: _teal,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      // Si ya hay sesión activa, va directo al home
      home: FirebaseAuth.instance.currentUser != null
          ? const HomeScreen()
          : const LoginScreen(),
    );
  }
}
