import 'package:flutter/material.dart';

class Connect extends StatelessWidget {
  const Connect({super.key}); // Garanta que o construtor é const

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar Veículo'),
      ),
      body: const Center(
        child: Text('Tela de conexão'),
      ),
    );
  }
}