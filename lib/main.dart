import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Supabase.initialize(
      url: 'https://cijfgqrtkerqsejlrgew.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNpamZncXJ0a2VycXNlamxyZ2V3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NjkzNDksImV4cCI6MjA4OTQ0NTM0OX0.MFvo_Iz6LtntJZdiJjlBtAkb2ouaoNDoSYRYnZHBvjc',
    );
  } catch (e) {
    debugPrint("Could not initialize Supabase. This might happen if already initialized: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Task App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2ECC94)),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}
