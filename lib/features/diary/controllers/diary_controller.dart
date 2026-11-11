import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../core/models/diary_entry.dart';
import '../../../core/models/refueling_sprint.dart';
import '../../../core/services/cloud_repository.dart';

/// ============================================================================
/// CONTROLADOR DO DIÁRIO DE LEITURAS E SPRINTS DE ABASTECIMENTO
/// ============================================================================
///
/// Gerencia:
/// 1. As Sprints de Abastecimento ([RefuelingSprint]) de cada veículo:
///    - Ao registrar um novo abastecimento, a Sprint anterior é encerrada
///      automaticamente (`endedAt = novo.startedAt`) e a nova Sprint passa a
///      ser a ativa (`endedAt == null`).
/// 2. Os instantâneos de telemetria OBD-II ([DiaryEntry]) com amostragem inteligente:
///    - 1º registro imediato ao conectar na sessão ou iniciar nova Sprint;
///    - Intervalo base de 3 minutos quando a mistura está estável;
///    - Gatilho inteligente (cooldown de 1 min) quando a % de etanol varia >= 1,5%
///      ou o LTFT varia >= 3,0%, capturando a adaptação da ECU logo após abastecer.
class DiaryController extends ChangeNotifier {
  static final DiaryController instance = DiaryController._internal();
  DiaryController._internal();

  /// Máximo de registros mantidos por veículo na memória (e carregados da nuvem).
  static const int maxEntriesPerVehicle = 500;

  /// Intervalo padrão de gravação no Diário/Sprint quando a leitura está estável.
  static const Duration normalInterval = Duration(minutes: 3);

  /// Cooldown mínimo para o Gatilho Inteligente de variação da mistura.
  static const Duration smartTriggerMinCooldown = Duration(minutes: 1);

  /// Variação mínima de Etanol (%) para disparar gravação antecipada.
  static const double ethanolDeltaThreshold = 1.5;

  /// Variação mínima de LTFT (%) para disparar gravação antecipada.
  static const double ltftDeltaThreshold = 3.0;

  // Ordem cronológica: do mais antigo para o mais recente.
  final Map<String, List<DiaryEntry>> _entries = {};
  final Map<String, List<RefuelingSprint>> _sprints = {};

  // Controla se já houve o 1º registro imediato na sessão atual de conexão por veículo
  final Set<String> _recordedInCurrentSession = {};

  /// Chamado quando o Bluetooth desconecta para liberar o 1º registro imediato na próxima conexão
  void resetSessionFlags() {
    _recordedInCurrentSession.clear();
  }

  // ----------------------------------------------------------------- leituras

  /// Todos os registros do veículo, do mais antigo para o mais recente.
  List<DiaryEntry> entriesFor(String vehicleId) =>
      List.unmodifiable(_entries[vehicleId] ?? const <DiaryEntry>[]);

  /// Registro mais recente do veículo (ou null se ainda não há leituras).
  DiaryEntry? latestFor(String vehicleId) {
    final list = _entries[vehicleId];
    return (list == null || list.isEmpty) ? null : list.last;
  }

  /// Registros pertencentes a uma Sprint de Abastecimento específica.
  List<DiaryEntry> entriesForSprint(String vehicleId, RefuelingSprint sprint) {
    final all = _entries[vehicleId];
    if (all == null || all.isEmpty) return const [];

    return all.where((e) {
      if (e.sprintId != null) {
        return e.sprintId == sprint.id;
      }
      final afterStart = !e.timestamp.isBefore(sprint.startedAt);
      final beforeEnd =
          sprint.endedAt == null || e.timestamp.isBefore(sprint.endedAt!);
      return afterStart && beforeEnd;
    }).toList();
  }

  // -------------------------------------------- sprints de abastecimento

  /// Lista de Sprints de Abastecimento do veículo (da mais antiga para a mais recente).
  List<RefuelingSprint> sprintsFor(String vehicleId) =>
      List.unmodifiable(_sprints[vehicleId] ?? const <RefuelingSprint>[]);

  /// Retorna a Sprint Ativa (em andamento) do veículo, se houver.
  RefuelingSprint? activeSprintFor(String vehicleId) {
    final list = _sprints[vehicleId];
    if (list == null || list.isEmpty) return null;
    for (int i = list.length - 1; i >= 0; i--) {
      if (list[i].isActive) return list[i];
    }
    return null;
  }

  /// Inicia uma nova Sprint de Abastecimento:
  /// - Encerra automaticamente a Sprint ativa anterior (se existir) com `endedAt = newSprint.startedAt`.
  /// - Adiciona a nova Sprint como ativa e sincroniza com o Firestore.
  Future<void> startNewSprint(
    String vehicleId,
    RefuelingSprint newSprint,
  ) async {
    final list = _sprints.putIfAbsent(vehicleId, () => []);

    // Fecha qualquer Sprint que estivesse aberta anteriormente
    for (int i = 0; i < list.length; i++) {
      if (list[i].isActive) {
        final closed = list[i].copyWith(endedAt: newSprint.startedAt);
        list[i] = closed;
        unawaited(CloudRepository.instance.saveSprint(vehicleId, closed));
      }
    }

    list.add(newSprint);
    list.sort((a, b) => a.startedAt.compareTo(b.startedAt));

    // Libera gravação imediata do 1º ponto OBD-II desta nova Sprint
    _recordedInCurrentSession.remove(vehicleId);
    notifyListeners();

    await CloudRepository.instance.saveSprint(vehicleId, newSprint);
  }

  /// Exclui uma Sprint de Abastecimento da memória e da nuvem.
  Future<void> deleteSprint(String vehicleId, String sprintId) async {
    final list = _sprints[vehicleId];
    if (list == null) return;
    list.removeWhere((s) => s.id == sprintId);
    notifyListeners();
    await CloudRepository.instance.deleteSprint(vehicleId, sprintId);
  }

  // --------------------------------------------- gravação inteligente OBD-II

  /// Chamado pelo ObdController a cada ciclo de leitura bem-sucedido.
  /// Aplica a regra híbrida:
  /// 1. Grava imediatamente o 1º registro da sessão ou o 1º registro de uma nova Sprint.
  /// 2. Grava antecipadamente (após 1 min) se o Etanol variar >= 1,5% ou LTFT >= 3,0%.
  /// 3. Caso estável, grava a cada 3 minutos.
  void recordSnapshot({
    required String vehicleId,
    double? ethanolPercentage,
    int? rpm,
    double? stft,
    double? ltft,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    final activeSprint = activeSprintFor(vehicleId);

    final entry = DiaryEntry(
      timestamp: now,
      ethanolPercentage: ethanolPercentage,
      rpm: rpm,
      stft: stft,
      ltft: ltft,
      sprintId: activeSprint?.id,
    );
    if (entry.isEmpty) return;

    final list = _entries.putIfAbsent(vehicleId, () => []);

    if (list.isNotEmpty && _recordedInCurrentSession.contains(vehicleId)) {
      final last = list.last;
      final elapsed = now.difference(last.timestamp);

      // Se a última leitura era de outra Sprint (acabou de iniciar nova Sprint), grava na hora
      final bool isFirstOfNewSprint =
          activeSprint != null && last.sprintId != activeSprint.id;

      if (!isFirstOfNewSprint) {
        // Verifica se houve variação brusca de mistura (Gatilho Inteligente)
        final bool ethanolChangedSignificantly =
            ethanolPercentage != null &&
            last.ethanolPercentage != null &&
            (ethanolPercentage - last.ethanolPercentage!).abs() >=
                ethanolDeltaThreshold;

        final bool ltftChangedSignificantly =
            ltft != null &&
            last.ltft != null &&
            (ltft - last.ltft!).abs() >= ltftDeltaThreshold;

        final bool triggeredByDelta =
            elapsed >= smartTriggerMinCooldown &&
            (ethanolChangedSignificantly || ltftChangedSignificantly);

        if (!triggeredByDelta && elapsed < normalInterval) {
          return;
        }
      }
    }

    _recordedInCurrentSession.add(vehicleId);
    list.add(entry);
    if (list.length > maxEntriesPerVehicle) {
      list.removeRange(0, list.length - maxEntriesPerVehicle);
    }
    notifyListeners();

    unawaited(CloudRepository.instance.saveReading(vehicleId, entry));
  }

  // ----------------------------------------- sincronização / carga inicial

  /// Define os registros de um veículo (carregados da nuvem). Não regrava.
  void setEntries(String vehicleId, List<DiaryEntry> entries) {
    final list = List<DiaryEntry>.of(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (list.length > maxEntriesPerVehicle) {
      list.removeRange(0, list.length - maxEntriesPerVehicle);
    }
    _entries[vehicleId] = list;
    notifyListeners();
  }

  /// Define as Sprints de Abastecimento de um veículo (carregadas da nuvem).
  void setSprints(String vehicleId, List<RefuelingSprint> sprints) {
    final list = List<RefuelingSprint>.of(sprints)
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    _sprints[vehicleId] = list;
    notifyListeners();
  }

  /// Adiciona vários registros de uma vez, só na memória (carro de exemplo).
  void addAll(String vehicleId, List<DiaryEntry> entries) {
    final list = _entries.putIfAbsent(vehicleId, () => []);
    list.addAll(entries);
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (list.length > maxEntriesPerVehicle) {
      list.removeRange(0, list.length - maxEntriesPerVehicle);
    }
    notifyListeners();
  }

  /// Apaga o diário e as sprints de um veículo da memória.
  void clearFor(String vehicleId) {
    final removedEntries = _entries.remove(vehicleId);
    final removedSprints = _sprints.remove(vehicleId);
    _recordedInCurrentSession.remove(vehicleId);
    if (removedEntries != null || removedSprints != null) {
      notifyListeners();
    }
  }

  /// Esvazia todos os diários e sprints da memória (logout / troca de conta).
  void clearAll() {
    if (_entries.isEmpty && _sprints.isEmpty) return;
    _entries.clear();
    _sprints.clear();
    _recordedInCurrentSession.clear();
    notifyListeners();
  }
}
