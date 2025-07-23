import 'package:flutter/material.dart';
import 'package:x3_gui/chat/pages/chat_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'X³ Credit Assistant',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7FAFC),
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF6A89A7),
          onPrimary: Colors.white,
          secondary: const Color(0xFF88BDF2),
          onSecondary: Colors.white,
          surface: const Color(0xFFBDDDFC),
          onSurface: Colors.black,
          surfaceContainerHighest: const Color(0xFFEAF3FB),
          primaryContainer: const Color(0xFFBDDDFC),
          onPrimaryContainer: Colors.black,
          outline: const Color(0xFF384959),
          onSurfaceVariant: Colors.black87,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF6A89A7),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardColor: const Color(0xFFBDDDFC),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}
