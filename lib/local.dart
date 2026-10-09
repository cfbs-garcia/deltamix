import 'package:flutter/material.dart';

class Local extends StatelessWidget {
  const Local({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local'),
      ),
      body: const Center(
        child: Text("Local legal yeah"),
    ));
  }
}