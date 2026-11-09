import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Centraliza Authentication + Firestore (coleção `users`).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  /// Emite também quando o usuário recarrega (ex.: e-mail verificado).
  Stream<User?> get userChanges => _auth.userChanges();

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String uid) =>
      _userDoc(uid).snapshots();

  // ------------------------------------------------------------ cadastro
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    await user.updateDisplayName(name.trim());
    await _userDoc(user.uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'deleted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await user.sendEmailVerification();
  }

  Future<void> login({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ------------------------------------------------- login com Google
  /// Login com Google (fluxo do próprio Firebase, sem SDK extra).
  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile');
    final cred = await _auth.signInWithProvider(provider);
    await _ensureUserDoc(cred.user);
  }

  /// Cria o documento em `users` no primeiro login com Google.
  Future<void> _ensureUserDoc(User? user) async {
    if (user == null) return;
    final ref = _userDoc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'deleted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> logout() => _auth.signOut();

  // ------------------------------------------------- verificação de e-mail
  Future<void> sendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  // -------------------------------------------------------------- perfil
  Future<void> updateName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name.trim());
    await _userDoc(user.uid).set({
      'name': name.trim(),
    }, SetOptions(merge: true));
  }

  /// Guarda a foto (já reduzida/comprimida) como base64 no Firestore.
  Future<void> updatePhoto(Uint8List bytes) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _userDoc(user.uid).set({
      'photoBase64': base64Encode(bytes),
    }, SetOptions(merge: true));
  }

  Future<void> removePhoto() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _userDoc(user.uid).update({'photoBase64': FieldValue.delete()});
  }

  //  soft delete
  /// Marca a conta como excluída (os dados continuam no banco) e desconecta.
  Future<void> softDeleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _userDoc(user.uid).set({
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _auth.signOut();
  }

  Future<void> reactivateAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _userDoc(user.uid).set({
      'deleted': false,
      'deletedAt': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  /// Traduz códigos de erro do Firebase para mensagens em português.
  static String errorMessage(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'E-mail inválido.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'E-mail ou senha incorretos.';
        case 'email-already-in-use':
          return 'Este e-mail já está cadastrado.';
        case 'weak-password':
          return 'A senha é muito fraca.';
        case 'user-disabled':
          return 'Esta conta foi desativada.';
        case 'account-exists-with-different-credential':
          return 'Já existe uma conta com este e-mail usando outro método '
              'de login. Entre por ele.';
        case 'web-context-canceled':
        case 'canceled':
        case 'cancelled':
          return ''; // usuário fechou a janela de login: sem mensagem
        case 'too-many-requests':
          return 'Muitas tentativas. Tente novamente mais tarde.';
        case 'network-request-failed':
          return 'Sem conexão com a internet.';
        default:
          return 'Erro de autenticação (${e.code}).';
      }
    }
    if (e is FirebaseException) {
      return 'Erro no servidor (${e.code}).';
    }
    return 'Ocorreu um erro inesperado.';
  }
}
