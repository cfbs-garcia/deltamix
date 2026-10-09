import 'package:flutter/material.dart';
import 'app_styles.dart';
import 'login.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---------------- LOGÓTIPO FIXO NO TOPO
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.green.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'DELTAMIX',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),

              // ---------------- CADASTRO NO CENTRO DO RESTO DO ECRÃ
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Criar nova conta',
                      style: TextStyle(
                        color: AppTheme.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ---------------- Email
                    TextField(
                      style: const TextStyle(color: AppTheme.white),
                      decoration: AppTheme.input('E-mail', Icons.email_outlined),
                    ),
                    const SizedBox(height: 16),

                    // ---------------- Senha
                    TextField(
                      obscureText: true,
                      style: const TextStyle(color: AppTheme.white),
                      decoration: AppTheme.input('Senha', Icons.lock_outline),
                    ),
                    const SizedBox(height: 16),
                    
                    // ---------------- Confirma a senha
                    TextField(
                      obscureText: true,
                      style: const TextStyle(color: AppTheme.white),
                      decoration: AppTheme.input('Confirma a senha', Icons.lock_reset_outlined),
                    ),
                    const SizedBox(height: 32),

                    // ---------------- Botão Criar Conta
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: AppTheme.button,
                        onPressed: () {},
                        child: const Text(
                          'Criar conta',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Já tem uma conta? Login',
                          style: TextStyle(
                            color: AppTheme.green,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}