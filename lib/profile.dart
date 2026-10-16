import 'package:flutter/material.dart';

import 'app_styles.dart';

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Foto de Perfil Simples
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.green, width: 2),
                ),
                child: const Icon(
                  Icons.person,
                  size: 40,
                  color: AppTheme.muted,
                ),
              ),
              const SizedBox(height: 16),

              // Nome
              const Text(
                'Usuario Teste',
                style: TextStyle(
                  color: AppTheme.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),

              // E-mail ou Handle
              const Text(
                'usuario@gmail.com',
                style: TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
              const SizedBox(height: 32),

              // Botão Simples
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    style: AppTheme.button,
                    onPressed: () {},
                    child: const Text('Trocar de foto'),
                  ),
                  const SizedBox(height: 15), // Espaçamento vertical

                  ElevatedButton(
                    style: AppTheme.button,
                    onPressed: () {},
                    child: const Text('Editar o nome'),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
