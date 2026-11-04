import 'package:flutter/foundation.dart';
import '../../../core/models/vehicle_model.dart';

/// Controlador que gerencia a lista de veículos da garagem e o carro ativo
class GarageController extends ChangeNotifier {
  static final GarageController instance = GarageController._internal();
  GarageController._internal();

  final List<VehicleModel> _vehicles = [
    VehicleModel(
      id: '1',
      model: 'Golf 1.4 TSI Flex',
      plate: 'BRA-2E19',
      nickname: 'Foguete Flex',
      obdName: 'Vgate iCar Pro',
      obdMacAddress: '00:1D:A5:02:C4:91',
      isObdConnected: true,
      ethanolPercentage: 78.5,
    ),
    VehicleModel(
      id: '2',
      model: 'Civic 2.0 i-VTEC Flex',
      plate: 'ABC-1D23',
      nickname: null, // Sem apelido opcional
      obdName: null,
      obdMacAddress: null,
      isObdConnected: false,
      ethanolPercentage: 28.0,
    ),
  ];

  VehicleModel? _selectedVehicle;

  List<VehicleModel> get vehicles => List.unmodifiable(_vehicles);
  VehicleModel get activeVehicle => _selectedVehicle ?? _vehicles.first;

  /// Define o veículo atualmente selecionado
  void selectVehicle(VehicleModel vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  /// Adiciona um novo carro cadastrado à garagem e o seleciona como ativo
  void addVehicle(VehicleModel vehicle) {
    _vehicles.add(vehicle);
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  /// Vincula o scanner OBD-II Bluetooth a um carro específico
  void bindObdToVehicle(String vehicleId, String obdName, String macAddress) {
    final index = _vehicles.indexWhere((v) => v.id == vehicleId);
    if (index != -1) {
      _vehicles[index] = _vehicles[index].copyWith(
        obdName: obdName,
        obdMacAddress: macAddress,
        isObdConnected: true,
      );
      if (_selectedVehicle?.id == vehicleId) {
        _selectedVehicle = _vehicles[index];
      }
      notifyListeners();
    }
  }
}
