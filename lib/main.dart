import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const ConfahubApp());
}

class ConfahubApp extends StatelessWidget {
  const ConfahubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Confahub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
