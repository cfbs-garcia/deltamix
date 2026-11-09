import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/diary_entry.dart';
import '../models/vehicle_model.dart';

/// Dados do usuário carregados do Firestore.
class CloudData {
  final List<VehicleModel> vehicles;
  final Map<String, List<DiaryEntry>> entries; // do mais antigo ao mais recente
  const CloudData(this.vehicles, this.entries);
}

/// ============================================================================
/// ACESSO AO FIRESTORE: CARROS E DIÁRIO DE CADA USUÁRIO
/// ============================================================================
///
/// Estrutura (tudo dentro da conta de quem está logado):
///   users/{uid}/vehicles/{vehicleId}            -> dados do carro
///   users/{uid}/vehicles/{vehicleId}/readings/* -> leituras do diário
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

  /// Apaga o carro e todas as leituras do diário dele.
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

  // ------------------------------------------------------------- carregar
  Future<CloudData> loadAll({int readingsLimit = 500}) async {
    final col = _vehiclesCol;
    if (col == null) return const CloudData([], {});

    final snap = await col.get();
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final x = (a.data()['createdAtMs'] as num?) ?? 0;
        final y = (b.data()['createdAtMs'] as num?) ?? 0;
        return x.compareTo(y);
      });

    final vehicles = <VehicleModel>[];
    final entries = <String, List<DiaryEntry>>{};

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
    }
    return CloudData(vehicles, entries);
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
    );
  }
}
