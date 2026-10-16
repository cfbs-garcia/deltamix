import 'package:flutter/material.dart';

import 'app_styles.dart';
import 'home.dart';
import 'register.dart'; // <--- Importante ter este import para o RegisterScreen funcionar

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool rememberMe = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void login() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Home()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // =====================================================
                // LOGO
                // =====================================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    const Text('DELTAMIX', style: AppTheme.logo),
                  ],
                ),

                const SizedBox(height: 45),

                // =====================================================
                // TÍTULO
                // =====================================================
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Bem-vindo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 7),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Entre na sua conta para continuar.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),

                const SizedBox(height: 30),

                // =====================================================
                // E-MAIL
                // =====================================================
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'E-MAIL',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 7),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Digite seu e-mail',
                    hintStyle: const TextStyle(
                      color: Colors.white24,
                      fontSize: 12,
                    ),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Colors.white38,
                      size: 19,
                    ),
                    filled: true,
                    fillColor: AppTheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: const BorderSide(
                        color: AppTheme.green,
                        width: 1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // =====================================================
                // SENHA
                // =====================================================
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SENHA',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 7),

                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Digite sua senha',
                    hintStyle: const TextStyle(
                      color: Colors.white24,
                      fontSize: 12,
                    ),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Colors.white38,
                      size: 19,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white38,
                        size: 19,
                      ),
                    ),
                    filled: true,
                    fillColor: AppTheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: const BorderSide(
                        color: AppTheme.green,
                        width: 1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // =====================================================
                // LEMBRAR + ESQUECI SENHA
                // =====================================================
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          rememberMe = !rememberMe;
                        });
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: rememberMe
                                  ? AppTheme.green
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: rememberMe
                                    ? AppTheme.green
                                    : Colors.white24,
                              ),
                            ),
                            child: rememberMe
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.black,
                                    size: 12,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 7),
                          const Text(
                            'Lembrar de mim',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    GestureDetector(
                      onTap: () {},
                      child: const Text(
                        'Esqueci minha senha',
                        style: TextStyle(
                          color: AppTheme.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                // =====================================================
                // BOTÃO ENTRAR
                // =====================================================
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.green,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: const Text(
                      'ENTRAR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // =====================================================
                // DIVISOR
                // =====================================================
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OU',
                        style: TextStyle(color: Colors.white24, fontSize: 9),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                // =====================================================
                // CRIAR CONTA (CORRIGIDO SEM CONST)
                // =====================================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Ainda não possui uma conta? ',
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Criar conta',
                        style: TextStyle(
                          color: AppTheme.green,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
