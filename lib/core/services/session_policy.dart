import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// Navigator global, usado para fechar as telas abertas quando a sessão expira.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// ============================================================================
/// POLÍTICA DE SESSÃO ("LEMBRAR-ME")
/// ============================================================================
///
/// - "Lembrar-me" marcado: a pessoa continua logada (comportamento padrão do
///   Firebase), até sair manualmente.
/// - "Lembrar-me" desmarcado: depois de [maxSessionWithoutRemember] desde o
///   login, a pessoa é desconectada automaticamente (conferido ao abrir o app,
///   ao voltar para ele e a cada minuto enquanto ele está aberto).
///
/// A preferência é guardada no próprio aparelho (shared_preferences).
class SessionPolicy with WidgetsBindingObserver {
  SessionPolicy._();
  static final SessionPolicy instance = SessionPolicy._();

  /// Duração máxima da sessão quando "Lembrar-me" NÃO está marcado.
  static const Duration maxSessionWithoutRemember = Duration(hours: 6);

  static const String _kRemember = 'session_remember_me';
  static const String _kLoginAt = 'session_login_at_ms';

  bool _started = false;
  Timer? _timer;
  StreamSubscription<User?>? _sub;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _sub = AuthService.instance.userChanges.listen((user) {
      if (user == null) {
        _clear();
      } else {
        checkNow();
      }
    });
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => checkNow());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) checkNow();
  }

  /// Chamar logo após um login bem-sucedido.
  Future<void> onLogin({required bool rememberMe}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kRemember, rememberMe);
      await prefs.setInt(_kLoginAt, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Falha ao salvar a preferência de sessão: $e');
    }
  }

  /// Desconecta se a sessão (sem "Lembrar-me") passou do tempo máximo.
  Future<void> checkNow() async {
    if (AuthService.instance.currentUser == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_kRemember);
      final loginAtMs = prefs.getInt(_kLoginAt);

      // Sem registro (ex.: sessão anterior a este recurso): mantém logado
      if (remember == null || loginAtMs == null) return;
      if (remember) return;

      final elapsed = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(loginAtMs),
      );
      if (elapsed >= maxSessionWithoutRemember) {
        await AuthService.instance.logout();
        appNavigatorKey.currentState?.popUntil((r) => r.isFirst);
      }
    } catch (e) {
      debugPrint('Falha ao conferir a sessão: $e');
    }
  }

  Future<void> _clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kRemember);
      await prefs.remove(_kLoginAt);
    } catch (_) {}
  }
}
