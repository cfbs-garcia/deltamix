import 'package:flutter/foundation.dart';
import '../../../core/models/vehicle_model.dart';

/// ============================================================================
/// CONTROLADOR DA GARAGEM DE VEÍCULOS
/// ============================================================================
///
/// Gerencia a lista de carros cadastrados pelo motorista, o veículo selecionado
/// e sincroniza o estado de conexão e a % de etanol lida via OBD-II.
class GarageController extends ChangeNotifier {
  static final GarageController instance = GarageController._internal();
  GarageController._internal();

  final List<VehicleModel> _vehicles = [
    VehicleModel(
      id: '1',
      model: 'Golf 1.4 TSI Flex',
      plate: 'BRA-2E19',
      nickname: 'Foguete Flex',
      obdName: null,
      obdMacAddress: null,
      isObdConnected: false,
      ethanolPercentage: 0.0,
    ),
    VehicleModel(
      id: '2',
      model: 'Civic 2.0 i-VTEC Flex',
      plate: 'ABC-1D23',
      nickname: null, // Sem apelido opcional
      obdName: null,
      obdMacAddress: null,
      isObdConnected: false,
      ethanolPercentage: 0.0,
    ),
  ];

  VehicleModel? _selectedVehicle;

  List<VehicleModel> get vehicles => List.unmodifiable(_vehicles);
  VehicleModel get activeVehicle => _selectedVehicle ?? _vehicles.first;

  /// Define o veículo atualmente selecionado na garagem
  void selectVehicle(VehicleModel vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  /// Adiciona um novo carro cadastrado à garagem e o seleciona como ativo
  void addVehicle(VehicleModel vehicle) {
    // Desmarca outros carros caso o novo já venha conectado ao leitor OBD-II
    if (vehicle.isObdConnected) {
      for (int i = 0; i < _vehicles.length; i++) {
        _vehicles[i] = _vehicles[i].copyWith(isObdConnected: false);
      }
    }
    _vehicles.add(vehicle);
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  /// Vincula o scanner OBD-II Bluetooth a um carro específico
  void bindObdToVehicle(String vehicleId, String obdName, String macAddress) {
    for (int i = 0; i < _vehicles.length; i++) {
      if (_vehicles[i].id == vehicleId) {
        _vehicles[i] = _vehicles[i].copyWith(
          obdName: obdName,
          obdMacAddress: macAddress,
          isObdConnected: true,
        );
        if (_selectedVehicle?.id == vehicleId) {
          _selectedVehicle = _vehicles[i];
        }
      } else {
        _vehicles[i] = _vehicles[i].copyWith(isObdConnected: false);
      }
    }
    notifyListeners();
  }

  /// Sincroniza a porcentagem real de etanol lida pelo ObdController com o carro ativo
  void updateActiveVehicleTelemetry({
    required double ethanolPercentage,
    required bool isConnected,
    String? obdName,
    String? obdMacAddress,
  }) {
    if (_vehicles.isEmpty) return;

    final targetId = (_selectedVehicle ?? _vehicles.first).id;
    final index = _vehicles.indexWhere((v) => v.id == targetId);
    if (index != -1) {
      final updated = _vehicles[index].copyWith(
        ethanolPercentage: ethanolPercentage,
        gasolinePercentage: (100.0 - ethanolPercentage).clamp(0.0, 100.0),
        isObdConnected: isConnected,
        obdName: obdName ?? _vehicles[index].obdName,
        obdMacAddress: obdMacAddress ?? _vehicles[index].obdMacAddress,
      );
      _vehicles[index] = updated;
      _selectedVehicle = updated;
      notifyListeners();
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
