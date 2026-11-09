import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/services/cloud_repository.dart';
import '../../diary/controllers/diary_controller.dart';

/// ============================================================================
/// CONTROLADOR DA GARAGEM DE VEÍCULOS
/// ============================================================================
///
/// Gerencia a lista de carros cadastrados pelo motorista, o veículo selecionado
/// e sincroniza o estado de conexão e a % de etanol lida via OBD-II.
///
/// Os carros ficam em memória para a interface e são gravados no Firestore da
/// conta logada (via [CloudRepository]). O carregamento ao entrar na conta é
/// feito por UserDataSync.
class GarageController extends ChangeNotifier {
  static final GarageController instance = GarageController._internal();
  GarageController._internal();

  final List<VehicleModel> _vehicles = [];

  VehicleModel? _selectedVehicle;
  bool _loading = false;

  List<VehicleModel> get vehicles => List.unmodifiable(_vehicles);
  VehicleModel? get activeVehicle =>
      _selectedVehicle ?? (_vehicles.isNotEmpty ? _vehicles.first : null);

  /// Carro ao qual o leitor OBD-II está vinculado agora (independe de qual
  /// carro está selecionado na tela). Null se nenhum carro está conectado.
  VehicleModel? get connectedVehicle {
    for (final v in _vehicles) {
      if (v.isObdConnected && !v.isDemo) return v;
    }
    return null;
  }

  /// Carro que recebe as leituras da ECU: o que está conectado ao leitor; se
  /// ainda não houver vínculo, o carro selecionado (e o vínculo é criado na
  /// primeira leitura, ficando fixo até desconectar).
  VehicleModel? get telemetryTarget => connectedVehicle ?? activeVehicle;

  /// Verdadeiro enquanto os carros da conta estão sendo carregados da nuvem.
  bool get isLoading => _loading;

  void setLoading(bool value) {
    if (_loading == value) return;
    _loading = value;
    notifyListeners();
  }

  /// Esvazia a garagem (logout / troca de conta). Não apaga nada na nuvem.
  void clearAll() {
    _vehicles.clear();
    _selectedVehicle = null;
    notifyListeners();
  }

  /// Substitui a lista pelos carros carregados da nuvem (sem regravá-los).
  void replaceAll(List<VehicleModel> vehicles) {
    _vehicles
      ..clear()
      ..addAll(vehicles);
    _selectedVehicle = _vehicles.isNotEmpty ? _vehicles.last : null;
    notifyListeners();
  }

  /// Define o veículo atualmente selecionado na garagem
  void selectVehicle(VehicleModel vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  /// Remove um veículo cadastrado da garagem pelo ID (e da nuvem, com o diário)
  void removeVehicle(String vehicleId) {
    final index = _vehicles.indexWhere((v) => v.id == vehicleId);
    final removed = index == -1 ? null : _vehicles[index];

    _vehicles.removeWhere((v) => v.id == vehicleId);
    DiaryController.instance.clearFor(vehicleId);
    if (_selectedVehicle?.id == vehicleId) {
      _selectedVehicle = _vehicles.isNotEmpty ? _vehicles.first : null;
    }
    notifyListeners();

    if (removed != null && !removed.isDemo) {
      unawaited(CloudRepository.instance.deleteVehicle(vehicleId));
    }
  }

  /// Adiciona um novo carro cadastrado à garagem e (por padrão) o seleciona
  /// como ativo. O carro é gravado na conta do usuário no Firestore.
  void addVehicle(VehicleModel vehicle, {bool select = true}) {
    // Desmarca outros carros caso o novo já venha conectado ao leitor OBD-II
    if (vehicle.isObdConnected) {
      for (int i = 0; i < _vehicles.length; i++) {
        _vehicles[i] = _vehicles[i].copyWith(isObdConnected: false);
      }
    }
    _vehicles.add(vehicle);
    if (select) _selectedVehicle = vehicle;
    notifyListeners();

    unawaited(CloudRepository.instance.saveVehicle(vehicle));
  }

  /// Vincula o scanner OBD-II Bluetooth a um carro específico
  void bindObdToVehicle(String vehicleId, String obdName, String macAddress) {
    VehicleModel? bound;
    for (int i = 0; i < _vehicles.length; i++) {
      if (_vehicles[i].id == vehicleId) {
        _vehicles[i] = _vehicles[i].copyWith(
          obdName: obdName,
          obdMacAddress: macAddress,
          isObdConnected: true,
        );
        bound = _vehicles[i];
        if (_selectedVehicle?.id == vehicleId) {
          _selectedVehicle = _vehicles[i];
        }
      } else {
        _vehicles[i] = _vehicles[i].copyWith(isObdConnected: false);
      }
    }
    notifyListeners();

    if (bound != null) unawaited(CloudRepository.instance.saveVehicle(bound));
  }

  /// Sincroniza a porcentagem real de etanol lida pelo ObdController com o carro
  /// ao qual o leitor está conectado (e não com o carro selecionado na tela).
  void updateActiveVehicleTelemetry({
    required double ethanolPercentage,
    required bool isConnected,
    String? obdName,
    String? obdMacAddress,
  }) {
    final target = telemetryTarget;
    // O carro de exemplo não recebe leituras reais
    if (target == null || target.isDemo) return;

    final index = _vehicles.indexWhere((v) => v.id == target.id);
    if (index == -1) return;

    final old = _vehicles[index];
    final updated = old.copyWith(
      ethanolPercentage: ethanolPercentage,
      gasolinePercentage: (100.0 - ethanolPercentage).clamp(0.0, 100.0),
      isObdConnected: isConnected,
      obdName: obdName ?? old.obdName,
      obdMacAddress: obdMacAddress ?? old.obdMacAddress,
    );
    _vehicles[index] = updated;
    // Mantém a cópia do carro selecionado atualizada, sem trocar a seleção
    if (_selectedVehicle?.id == updated.id) _selectedVehicle = updated;
    notifyListeners();

    // Se o leitor vinculado mudou, grava (a % de etanol vai junto com o diário)
    if (updated.obdName != old.obdName ||
        updated.obdMacAddress != old.obdMacAddress) {
      unawaited(CloudRepository.instance.saveVehicle(updated));
    }
  }

  /// Marca todos os veículos como desconectados quando o Bluetooth é encerrado
  void markAllDisconnected() {
    for (int i = 0; i < _vehicles.length; i++) {
      _vehicles[i] = _vehicles[i].copyWith(isObdConnected: false);
    }
    if (_selectedVehicle != null) {
      _selectedVehicle = _selectedVehicle!.copyWith(isObdConnected: false);
    }
    notifyListeners();
  }
}
