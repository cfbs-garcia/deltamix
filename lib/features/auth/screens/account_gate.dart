import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../navigation/main_scaffold.dart';
import 'login_screen.dart';

/// Decide qual tela mostrar:
/// sem login -> Login | e-mail não verificado -> verificação |
/// conta excluída (soft delete) -> reativação | senão -> MainScaffold.
class AccountGate extends StatelessWidget {
  const AccountGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.userChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        // Login com Google não precisa do link de verificação.
        final isSocial = user.providerData.any((p) => p.providerId != 'password');
        if (!user.emailVerified && !isSocial) return const VerifyEmailScreen();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: AuthService.instance.userStream(user.uid),
          builder: (context, snap) {
            if (!snap.hasData && !snap.hasError) return const _Loading();
            if (snap.data?.data()?['deleted'] == true) {
              return const AccountDeletedScreen();
            }
            return const MainScaffold();
          },
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AppColors.ethanolNeon),
      ),
    );
  }
}

/// Ícone circular com glow neon, no mesmo estilo das telas de login/cadastro.
class _NeonIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final List<BoxShadow> shadow;
  const _NeonIcon({
    required this.icon,
    this.color = AppColors.ethanolNeon,
    this.shadow = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          shape: BoxShape.circle,
          boxShadow: shadow,
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Icon(icon, size: 38, color: color),
      ),
    );
  }
}

// ======================================================= verificar e-mail
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Confere sozinho a cada 4 s se o usuário já clicou no link.
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      AuthService.instance.reloadUser().catchError((_) {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _check() async {
    setState(() => _busy = true);
    try {
      await AuthService.instance.reloadUser();
      final verified = AuthService.instance.currentUser?.emailVerified ?? false;
      if (!verified && mounted) _msg('E-mail ainda não verificado.');
    } catch (e) {
      if (mounted) _msg(AuthService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await AuthService.instance.sendVerificationEmail();
      if (mounted) _msg('E-mail de verificação reenviado.');
    } catch (e) {
      if (mounted) _msg(AuthService.errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.instance.currentUser?.email ?? '';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                _NeonIcon(
                  icon: Icons.mark_email_unread_outlined,
                  shadow: AppColors.ethanolNeonShadow,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verifique seu e-mail',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Enviamos um link de confirmação para\n$email\n\n'
                  'Abra o e-mail (veja também o spam) e toque no link. '
                  'Esta tela avança sozinha depois disso.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _busy ? null : _check,
                  child: const Text('Já verifiquei'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _resend,
                  child: const Text('Reenviar e-mail'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => AuthService.instance.logout(),
                  child: const Text(
                    'Usar outra conta',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========================================================= conta excluída
class AccountDeletedScreen extends StatefulWidget {
  const AccountDeletedScreen({super.key});

  @override
  State<AccountDeletedScreen> createState() => _AccountDeletedScreenState();
}

class _AccountDeletedScreenState extends State<AccountDeletedScreen> {
  bool _busy = false;

  Future<void> _reactivate() async {
    setState(() => _busy = true);
    try {
      await AuthService.instance.reactivateAccount();
      // O gate volta para a tela principal sozinho.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthService.errorMessage(e))),
        );
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const _NeonIcon(
                  icon: Icons.person_off_outlined,
                  color: AppColors.alertRed,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Conta excluída',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Esta conta foi excluída. Se foi um engano, '
                  'você pode reativá-la agora.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _busy ? null : _reactivate,
                  child: const Text('Reativar conta'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => AuthService.instance.logout(),
                  child: const Text(
                    'Sair',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
