import 'package:flutter/material.dart';
import 'theme/tokens.dart';

void main() {
  runApp(const BoardcastApp());
}

class BoardcastApp extends StatelessWidget {
  const BoardcastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boardcast',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
      ),
      home: const Scaffold(
        body: Center(child: Text('Boardcast — Phase 0 complete')),
      ),
    );
  }
}
