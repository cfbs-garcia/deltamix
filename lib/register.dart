import 'package:flutter/material.dart';

import 'login.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Column(children: [Text('deltamix - cadastro')]),

            // ---------------- Email
            Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                  ),
                ),

                // ---------------- Senha
                SizedBox(height: 16),

                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(),
                  ),
                ),

                // ---------------- Confirma a senha
                SizedBox(height: 16),
                
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirma a senha',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),

            TextButton(onPressed: () {}, child: const Text('Criar conta')),

            TextButton(
              onPressed: () {
                Navigator.push(context, 
                MaterialPageRoute(
                  builder: (context) => LoginScreen(),


                ));
              },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
