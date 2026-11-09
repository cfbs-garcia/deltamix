import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../core/models/diary_entry.dart';
import '../../../core/services/cloud_repository.dart';

/// ============================================================================
/// CONTROLADOR DO DIÁRIO DE LEITURAS (UM HISTÓRICO POR VEÍCULO)
/// ============================================================================
///
/// Guarda os instantâneos lidos pelo scanner OBD-II de cada carro. Os registros
/// ficam em memória para a interface e cada novo registro é gravado na conta
/// do usuário no Firestore (via [CloudRepository]). O carregamento ao entrar
/// na conta é feito por UserDataSync.
class DiaryController extends ChangeNotifier {
  static final DiaryController instance = DiaryController._internal();
  DiaryController._internal();

  /// Máximo de registros mantidos por veículo na memória (e carregados da nuvem).
  static const int maxEntriesPerVehicle = 500;

  /// Intervalo mínimo entre dois registros do mesmo veículo. O polling da ECU
  /// lê a cada ~0,5 s; o diário guarda um instantâneo a cada 30 s, o que também
  /// limita o número de gravações no Firestore.
  static const Duration minInterval = Duration(seconds: 30);

  // Ordem cronológica: do mais antigo para o mais recente.
  final Map<String, List<DiaryEntry>> _entries = {};

  /// Registros do veículo, do mais antigo para o mais recente.
  List<DiaryEntry> entriesFor(String vehicleId) =>
      List.unmodifiable(_entries[vehicleId] ?? const <DiaryEntry>[]);

  /// Registro mais recente do veículo (ou null se ainda não há leituras).
  DiaryEntry? latestFor(String vehicleId) {
    final list = _entries[vehicleId];
    return (list == null || list.isEmpty) ? null : list.last;
  }

  /// Chamado pelo ObdController a cada ciclo de leitura bem-sucedido.
  void recordSnapshot({
    required String vehicleId,
    double? ethanolPercentage,
    int? rpm,
    double? stft,
    double? ltft,
    DateTime? at,
  }) {
    final entry = DiaryEntry(
      timestamp: at ?? DateTime.now(),
      ethanolPercentage: ethanolPercentage,
      rpm: rpm,
      stft: stft,
      ltft: ltft,
    );
    if (entry.isEmpty) return;

    final list = _entries.putIfAbsent(vehicleId, () => []);
    if (list.isNotEmpty &&
        entry.timestamp.difference(list.last.timestamp) < minInterval) {
      return;
    }
    list.add(entry);
    if (list.length > maxEntriesPerVehicle) {
      list.removeRange(0, list.length - maxEntriesPerVehicle);
    }
    notifyListeners();

    unawaited(CloudRepository.instance.saveReading(vehicleId, entry));
  }

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

  /// Apaga o diário de um veículo da memória (a nuvem é limpa por
  /// GarageController.removeVehicle).
  void clearFor(String vehicleId) {
    if (_entries.remove(vehicleId) != null) notifyListeners();
  }

  /// Esvazia todos os diários da memória (logout / troca de conta).
  void clearAll() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }
}
