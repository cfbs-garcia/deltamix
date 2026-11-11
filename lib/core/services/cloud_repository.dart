import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/diary_entry.dart';
import '../models/refueling_sprint.dart';
import '../models/vehicle_model.dart';

/// Dados do usuário carregados do Firestore.
class CloudData {
  final List<VehicleModel> vehicles;
  final Map<String, List<DiaryEntry>> entries; // do mais antigo ao mais recente
  final Map<String, List<RefuelingSprint>> sprints; // do mais antigo ao mais recente
  const CloudData(this.vehicles, this.entries, this.sprints);
}

/// ============================================================================
/// ACESSO AO FIRESTORE: CARROS, DIÁRIO E SPRINTS DE ABASTECIMENTO
/// ============================================================================
///
/// Estrutura (tudo dentro da conta de quem está logado):
///   users/{uid}/vehicles/{vehicleId}            -> dados do carro
///   users/{uid}/vehicles/{vehicleId}/readings/* -> leituras do diário (OBD-II)
///   users/{uid}/vehicles/{vehicleId}/sprints/*  -> sprints de abastecimento
///
/// O caminho sempre usa o uid do usuário logado, e as regras do Firestore
/// (firestore.rules) só permitem acessar os documentos do próprio uid.
class CloudRepository {
  CloudRepository._();
  static final CloudRepository instance = CloudRepository._();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _vehiclesCol {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('vehicles');
  }

  // ---------------------------------------------------------------- carros
  Future<void> saveVehicle(VehicleModel v) async {
    if (v.isDemo) return; // o carro de exemplo nunca vai para a nuvem
    final col = _vehiclesCol;
    if (col == null) return;
    try {
      await col.doc(v.id).set({
        'model': v.model,
        'plate': v.plate,
        'nickname': v.nickname,
        'obdName': v.obdName,
        'obdMacAddress': v.obdMacAddress,
        'ethanolPercentage': v.ethanolPercentage,
        'createdAtMs':
            int.tryParse(v.id) ?? DateTime.now().millisecondsSinceEpoch,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Falha ao salvar veículo: $e');
    }
  }

  /// Apaga o carro, todas as leituras do diário e todas as sprints dele.
  Future<void> deleteVehicle(String vehicleId) async {
    final col = _vehiclesCol;
    if (col == null) return;
    try {
      final readings = col.doc(vehicleId).collection('readings');
      while (true) {
        final snap = await readings.limit(400).get();
        if (snap.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }

      final sprints = col.doc(vehicleId).collection('sprints');
      while (true) {
        final snap = await sprints.limit(400).get();
        if (snap.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }

      await col.doc(vehicleId).delete();
    } catch (e) {
      debugPrint('Falha ao excluir veículo: $e');
    }
  }

  // ----------------------------------------------------------------- diário
  Future<void> saveReading(String vehicleId, DiaryEntry e) async {
    final col = _vehiclesCol;
    if (col == null) return;
    try {
      final vehicleRef = col.doc(vehicleId);
      final batch = FirebaseFirestore.instance.batch();
      batch.set(vehicleRef.collection('readings').doc(), {
        'timestamp': Timestamp.fromDate(e.timestamp),
        if (e.ethanolPercentage != null) 'ethanol': e.ethanolPercentage,
        if (e.rpm != null) 'rpm': e.rpm,
        if (e.stft != null) 'stft': e.stft,
        if (e.ltft != null) 'ltft': e.ltft,
        if (e.sprintId != null) 'sprintId': e.sprintId,
      });
      if (e.ethanolPercentage != null) {
        // Guarda a última % de etanol também no carro
        batch.set(vehicleRef, {
          'ethanolPercentage': e.ethanolPercentage,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (err) {
      debugPrint('Falha ao salvar leitura: $err');
    }
  }

  // -------------------------------------------- sprints de abastecimento
  Future<void> saveSprint(String vehicleId, RefuelingSprint s) async {
    if (vehicleId == 'demo-vehicle') return;
    final col = _vehiclesCol;
    if (col == null) return;
    try {
      await col.doc(vehicleId).collection('sprints').doc(s.id).set({
        'startedAt': Timestamp.fromDate(s.startedAt),
        'endedAt': s.endedAt != null ? Timestamp.fromDate(s.endedAt!) : null,
        'fuelType': s.fuelType.name,
        'liters': s.liters,
        'pricePerLiter': s.pricePerLiter,
        'primaryFuelType': s.primaryFuelType?.name,
        'secondaryFuelType': s.secondaryFuelType?.name,
        'secondaryLiters': s.secondaryLiters,
        'secondaryPricePerLiter': s.secondaryPricePerLiter,
        'location': s.location,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (err) {
      debugPrint('Falha ao salvar sprint de abastecimento: $err');
    }
  }

  Future<void> deleteSprint(String vehicleId, String sprintId) async {
    if (vehicleId == 'demo-vehicle') return;
    final col = _vehiclesCol;
    if (col == null) return;
    try {
      await col.doc(vehicleId).collection('sprints').doc(sprintId).delete();
    } catch (err) {
      debugPrint('Falha ao excluir sprint de abastecimento: $err');
    }
  }

  // ------------------------------------------------------------- carregar
  Future<CloudData> loadAll({int readingsLimit = 500}) async {
    final col = _vehiclesCol;
    if (col == null) return const CloudData([], {}, {});

    final snap = await col.get();
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final x = (a.data()['createdAtMs'] as num?) ?? 0;
        final y = (b.data()['createdAtMs'] as num?) ?? 0;
        return x.compareTo(y);
      });

    final vehicles = <VehicleModel>[];
    final entries = <String, List<DiaryEntry>>{};
    final sprints = <String, List<RefuelingSprint>>{};

    for (final d in docs) {
      final m = d.data();
      vehicles.add(
        VehicleModel(
          id: d.id,
          model: (m['model'] as String?) ?? 'Veículo',
          plate: (m['plate'] as String?) ?? '',
          nickname: m['nickname'] as String?,
          obdName: m['obdName'] as String?,
          obdMacAddress: m['obdMacAddress'] as String?,
          ethanolPercentage: (m['ethanolPercentage'] as num?)?.toDouble() ?? 0.0,
        ),
      );

      final r = await d.reference
          .collection('readings')
          .orderBy('timestamp', descending: true)
          .limit(readingsLimit)
          .get();
      final list = <DiaryEntry>[];
      for (final doc in r.docs) {
        final entry = _entryFrom(doc.data());
        if (entry != null) list.add(entry);
      }
      if (list.isNotEmpty) entries[d.id] = list.reversed.toList();

      final sSnap = await d.reference
          .collection('sprints')
          .orderBy('startedAt', descending: false)
          .get();
      final sprintList = <RefuelingSprint>[];
      for (final doc in sSnap.docs) {
        final sprint = _sprintFrom(doc.id, doc.data());
        if (sprint != null) sprintList.add(sprint);
      }
      if (sprintList.isNotEmpty) sprints[d.id] = sprintList;
    }
    return CloudData(vehicles, entries, sprints);
  }

  DiaryEntry? _entryFrom(Map<String, dynamic> m) {
    final ts = m['timestamp'];
    if (ts is! Timestamp) return null;
    return DiaryEntry(
      timestamp: ts.toDate(),
      ethanolPercentage: (m['ethanol'] as num?)?.toDouble(),
      rpm: (m['rpm'] as num?)?.toInt(),
      stft: (m['stft'] as num?)?.toDouble(),
      ltft: (m['ltft'] as num?)?.toDouble(),
      sprintId: m['sprintId'] as String?,
    );
  }

  RefuelingSprint? _sprintFrom(String id, Map<String, dynamic> m) {
    final startedTs = m['startedAt'];
    if (startedTs is! Timestamp) return null;
    final endedTs = m['endedAt'];
    return RefuelingSprint(
      id: id,
      startedAt: startedTs.toDate(),
      endedAt: endedTs is Timestamp ? endedTs.toDate() : null,
      fuelType: FuelType.fromCode(m['fuelType'] as String?),
      liters: (m['liters'] as num?)?.toDouble() ?? 0.0,
      pricePerLiter: (m['pricePerLiter'] as num?)?.toDouble() ?? 0.0,
      primaryFuelType: m['primaryFuelType'] != null
          ? FuelType.fromCode(m['primaryFuelType'] as String?)
          : null,
      secondaryFuelType: m['secondaryFuelType'] != null
          ? FuelType.fromCode(m['secondaryFuelType'] as String?)
          : null,
      secondaryLiters: (m['secondaryLiters'] as num?)?.toDouble(),
      secondaryPricePerLiter: (m['secondaryPricePerLiter'] as num?)?.toDouble(),
      location: m['location'] as String?,
    );
  }
}
