import 'package:flutter/material.dart';
import 'package:cognicompanion/pages/splashscreen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CogniCompanion',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: Splash(),
      debugShowCheckedModeBanner: false,
    );
  }
}
