import 'package:flutter/foundation.dart';

/// ============================================================================
/// CONTROLADOR DO SCANNER AUTOMOTIVO OBD-II (ELM327 / SPP BLUETOOTH)
/// ============================================================================
///
/// Gerencia reativamente o estado da conexão serial, ciclo de vida do handshake
/// (ATZ -> ATE0 -> ATL0 -> ATSP0) e polling do PID 01 52 (Porcentagem de Etanol).
class ObdController extends ChangeNotifier {
  // Padrão Singleton
  static final ObdController instance = ObdController._internal();
  ObdController._internal();

  // Estados internos
  bool _isConnected = false;
  bool _isInitializing = false;
  bool _isReading = false;
  double? _ethanolPercentage = 78.5; // Leitura inicial simulada
  String? _connectedName;
  String? _errorMessage;

  // Getters públicos reativos consumidos pelo ListenableBuilder na Home
  bool get isConnected => _isConnected;
  bool get isInitializing => _isInitializing;
  bool get isReading => _isReading;
  double? get ethanolPercentage => _ethanolPercentage;
  String? get connectedName => _connectedName;
  String? get errorMessage => _errorMessage;

  /// Inicia conexão Bluetooth com o scanner automotivo (RFCOMM SPP)
  Future<void> connect(String deviceName, String macAddress) async {
    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // TODO: Integrar com flutter_classic_bluetooth usando RfcommSocket
      // Handshake inicial: ATZ -> ATE0 -> ATL0 -> ATSP0
      await Future.delayed(const Duration(milliseconds: 1200));

      _isConnected = true;
      _connectedName = deviceName;
      _isInitializing = false;
      notifyListeners();

      // Dispara a primeira leitura do PID 01 52
      await refreshEthanol();
    } catch (e) {
      _isConnected = false;
      _isInitializing = false;
      _errorMessage = 'Falha ao conectar ao scanner: $e';
      notifyListeners();
    }
  }

  /// Envia comando PID 01 52 na fila serial FIFO e atualiza a % de etanol
  Future<void> refreshEthanol() async {
    if (!_isConnected) return;

    _isReading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // TODO: Enviar '01 52\r' e aguardar '>'
      await Future.delayed(const Duration(milliseconds: 800));

      // Exemplo de atualização de leitura (simulada ou real)
      _ethanolPercentage = 78.5;
      _isReading = false;
      notifyListeners();
    } catch (e) {
      _isReading = false;
      _errorMessage = 'ECU não respondeu (Verifique se a ignição está ligada)';
      notifyListeners();
    }
  }

  /// Encerra a conexão serial com o leitor
  Future<void> disconnect() async {
    _isConnected = false;
    _connectedName = null;
    _ethanolPercentage = null;
    _errorMessage = null;
    notifyListeners();
  }
}
