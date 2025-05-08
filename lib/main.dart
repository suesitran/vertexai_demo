import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:vertexai_demo/firebase_options.dart';

void main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Vertex AI in Firebase'),
        ),
        body: const Column(
          
        ),
      ),
    );
  }
}
