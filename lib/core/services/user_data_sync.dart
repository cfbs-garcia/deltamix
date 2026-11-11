import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../features/diary/controllers/diary_controller.dart';
import '../../features/garage/controllers/garage_controller.dart';
import '../bluetooth/obd_controller.dart';
import '../demo/demo_data.dart';
import 'auth_service.dart';
import 'cloud_repository.dart';

/// ============================================================================
/// SINCRONIZA OS DADOS DO USUÁRIO LOGADO COM O FIRESTORE
/// ============================================================================
///
/// - Ao entrar numa conta: carrega os carros, o diário e as sprints daquela conta.
/// - Ao sair (ou trocar de conta): limpa tudo da memória, para que nenhum dado
///   de uma pessoa apareça para outra, e desconecta o leitor OBD-II.
/// - As gravações (carro novo, leituras, sprints, exclusão) são feitas pelos
///   controllers via [CloudRepository].
class UserDataSync {
  UserDataSync._();
  static final UserDataSync instance = UserDataSync._();

  StreamSubscription<User?>? _sub;
  String? _currentUid;
  int _token = 0;

  void start() {
    _sub ??= AuthService.instance.userChanges.listen(_onUser);
  }

  Future<void> _onUser(User? user) async {
    final uid = user?.uid;
    if (uid == _currentUid) return; // userChanges também dispara em reload()
    _currentUid = uid;
    final token = ++_token;

    // Troca de conta ou logout: nada do usuário anterior pode ficar na memória
    if (ObdController.instance.isConnected) {
      try {
        await ObdController.instance.disconnect();
      } catch (_) {}
    }
    GarageController.instance.clearAll();
    DiaryController.instance.clearAll();
    if (uid == null) return;

    GarageController.instance.setLoading(true);
    try {
      final data = await CloudRepository.instance.loadAll(
        readingsLimit: DiaryController.maxEntriesPerVehicle,
      );
      if (token != _token) return; // outra troca de conta aconteceu no meio
      GarageController.instance.replaceAll(data.vehicles);
      data.entries.forEach(DiaryController.instance.setEntries);
      data.sprints.forEach(DiaryController.instance.setSprints);

      // Carro de exemplo só aparece para quem ainda não tem carros próprios
      if (data.vehicles.isEmpty) {
        DemoData.seed();
      } else {
        // Se o veículo ativo já possui um scanner OBD-II vinculado, inicia a
        // conexão / espera automática sem o motorista precisar conectar manualmente
        final active = GarageController.instance.activeVehicle;
        if (active != null &&
            !active.isDemo &&
            active.obdMacAddress != null &&
            active.obdMacAddress!.trim().isNotEmpty) {
          ObdController.instance.enableAutoConnectForVehicle(
            active.obdName ?? 'Leitor OBD-II',
            active.obdMacAddress!,
          );
        }
      }
    } catch (e) {
      debugPrint('Falha ao carregar dados do usuário: $e');
    } finally {
      if (token == _token) GarageController.instance.setLoading(false);
    }
  }
}
