// main.dart
import 'package:flutter/material.dart';
import 'splash_screen.dart'; // Import the splash screen file
import 'home_screen.dart'; // Import the home screen file

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '열차위치',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SplashScreen(), // Start with SplashScreen
    );
  }
}
