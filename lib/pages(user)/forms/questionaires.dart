import 'package:flutter/material.dart';

class Questionaires extends StatelessWidget {
  final Map<String, dynamic> userData;
  
  const Questionaires({Key? key, required this.userData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Welcome, ${userData['department']}!'),
      ),
    );
  }
}