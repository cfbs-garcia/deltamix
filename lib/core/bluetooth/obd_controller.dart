import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../features/diary/controllers/diary_controller.dart';
import '../../features/garage/controllers/garage_controller.dart';
import 'obd_service.dart';

/// ============================================================================
/// CONTROLADOR GLOBAL DO SCANNER AUTOMOTIVO OBD-II (ELM327 / SPP BLUETOOTH)
/// ============================================================================
///
/// Gerencia de forma centralizada (Singleton):
/// 1. Busca de dispositivos Bluetooth OBD-II pareados no Android.
/// 2. Conexão de socket serial RFCOMM (com fallback Insecure -> Secure).
/// 3. Assinatura única no EventChannel nativo para evitar concorrência de leitura.
/// 4. Fila serial FIFO para envio ordenado de comandos AT e PIDs OBD-II:
///    - PID 01 52: Porcentagem de Etanol (%)
///    - PID 01 0C: Rotação do Motor (RPM)
///    - PID 01 06: Short Term Fuel Trim (STFT - Ajuste de Combustível a Curto Prazo)
///    - PID 01 07: Long Term Fuel Trim (LTFT - Ajuste de Combustível a Longo Prazo)
class ObdController extends ChangeNotifier {
  // Padrão Singleton
  static final ObdController instance = ObdController._internal();
  ObdController._internal();

  final FlutterClassicBluetooth bluetooth = FlutterClassicBluetooth();

  BtcConnection? _connection;
  StreamSubscription<BtcConnectionState>? _stateSub;
  StreamSubscription<Uint8List>? _rawInputSub;
  StreamController<Uint8List>? _inputBroadcast;
  Timer? _pollTimer;

  // Fila serial FIFO para garantir que dois comandos nunca colidam no ELM327
  Future<void> _serialQueue = Future.value();

  // ---------------------------------------------------------------------------
  // ESTADOS INTERNOS DE CONEXÃO E TELEMETRIA
  // ---------------------------------------------------------------------------
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isInitializing = false;
  bool _isReading = false;
  bool _isPollingCycle = false;

  /// Intervalo entre ciclos de leitura da ECU em milissegundos (padrão rápido: 250 ms)
  int _pollingIntervalMs = 250;

  String? _connectedName;
  String? _connectedMac;
  String? _errorMessage;

  // Indicadores lidos em tempo real da ECU
  double? _ethanolPercentage;
  int? _engineRpm;
  double? _shortTermFuelTrim; // STFT (%)
  double? _longTermFuelTrim;  // LTFT (%)
  String? _lastRawResponse;
  int? _lastLatencyMs;
  DateTime? _lastUpdatedAt;

  // ---------------------------------------------------------------------------
  // GETTERS PÚBLICOS REATIVOS (CONSUMIDOS PELOS DASHBOARDS E TELAS)
  // ---------------------------------------------------------------------------
  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  bool get isInitializing => _isInitializing;
  bool get isReading => _isReading;
  bool get isBusy => _isConnecting || _isInitializing || _isReading || _isPollingCycle;

  /// Intervalo de leitura configurado (em ms): 250 ms (padrão rápido), 500 ms ou 1000 ms
  int get pollingIntervalMs => _pollingIntervalMs;
  String get pollingIntervalLabel => '$_pollingIntervalMs ms';

  /// Altera a frequência de leitura da ECU em tempo real
  void setPollingIntervalMs(int ms) {
    if (ms <= 0 || _pollingIntervalMs == ms) return;
    _pollingIntervalMs = ms;
    if (_isConnected) {
      _startPollingTimer();
    }
    notifyListeners();
  }

  String? get connectedName => _connectedName;
  String? get connectedMac => _connectedMac;
  String? get errorMessage => _errorMessage;

  /// Porcentagem de etanol no tanque (0.0 a 100.0) lida via Mode 01 PID 52
  double? get ethanolPercentage => _ethanolPercentage;

  /// Rotação do motor (RPM) lida via Mode 01 PID 0C
  int? get engineRpm => _engineRpm;

  /// Short Term Fuel Trim / Ajuste a Curto Prazo (%) lido via Mode 01 PID 06
  double? get shortTermFuelTrim => _shortTermFuelTrim;

  /// Long Term Fuel Trim / Ajuste a Longo Prazo (%) lido via Mode 01 PID 07
  double? get longTermFuelTrim => _longTermFuelTrim;

  /// Última resposta hexadecimal bruta da ECU para auditoria técnica
  String? get lastRawResponse => _lastRawResponse;

  /// Latência da última leitura da ECU em milissegundos
  int? get lastLatencyMs => _lastLatencyMs;

  DateTime? get lastUpdatedAt => _lastUpdatedAt;

  // ---------------------------------------------------------------------------
  // 1. BUSCA DE APARELHOS OBD-II PAREADOS NO CELULAR
  // ---------------------------------------------------------------------------
  /// Solicita permissões de Bluetooth e retorna apenas os scanners
  /// automotivos pareados (filtrados por palavras-chave como OBD, ELM, VGATE, etc.).
  Future<List<Map<String, String>>> getPairedObdDevices() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    final rawDevices = await bluetooth.getPairedDevices();

    // Palavras-chave dos adaptadores veiculares compatíveis
    const allowedKeywords = [
      'obd',
      'elm',
      'vgate',
      'scan',
      'vlinker',
      'viecar',
      'v-link',
      'konnwei',
    ];

    return rawDevices.where((device) {
      final name = device.displayName.toLowerCase();
      return allowedKeywords.any((key) => name.contains(key));
    }).map((device) {
      final displayName =
          device.displayName.isNotEmpty ? device.displayName : 'Leitor OBD-II';
      return {
        'name': displayName,
        'address': device.address,
        'type': 'Scanner OBD-II Bluetooth SPP',
      };
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // 2. CONEXÃO BLUETOOTH RFCOMM E HANDSHAKE INICIAL ELM327
  // ---------------------------------------------------------------------------
  /// Abre o socket serial Bluetooth com o scanner selecionado, inicializa o chip
  /// ELM327 e inicia o ciclo de leitura automática dos sensores da ECU.
  Future<bool> connect(String deviceName, String macAddress) async {
    if (_isConnecting) return false;

    if (_isConnected) {
      await disconnect();
    }

    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('[Bluetooth] Tentando abrir socket serial com $macAddress...');

      // Scanners ELM327 funcionam prioritariamente com socket RFCOMM inseguro (secure: false).
      // Caso falhe, realiza fallback automático para o modo seguro (secure: true).
      BtcConnection? conn;
      try {
        conn = await bluetooth.connect(
          address: macAddress,
          secure: false,
          timeout: const Duration(seconds: 8),
        );
      } catch (_) {
        debugPrint('[Bluetooth] Insecure falhou, tentando modo seguro...');
        conn = await bluetooth.connect(
          address: macAddress,
          secure: true,
          timeout: const Duration(seconds: 8),
        );
      }

      if (!conn.isConnected) {
        _isConnecting = false;
        _errorMessage = 'Não foi possível estabelecer conexão com o scanner.';
        notifyListeners();
        return false;
      }

      _connection = conn;
      _connectedName = deviceName;
      _connectedMac = macAddress;
      _isConnecting = false;
      _isConnected = true;

      // Cria assinatura única no stream nativo para evitar múltiplas threads de leitura no Android
      _inputBroadcast = StreamController<Uint8List>.broadcast();
      _rawInputSub = conn.input.listen(
        (chunk) {
          if (_inputBroadcast != null && !_inputBroadcast!.isClosed) {
            _inputBroadcast!.add(chunk);
          }
        },
        onError: (Object err) {
          if (_inputBroadcast != null && !_inputBroadcast!.isClosed) {
            _inputBroadcast!.addError(err);
          }
        },
      );

      // Monitora desconexão física do adaptador
      _stateSub?.cancel();
      _stateSub = conn.stateStream.listen((state) {
        if (state == BtcConnectionState.disconnected && _isConnected) {
          _handleRemoteDisconnect();
        }
      });

      notifyListeners();

      // Inicializa o ELM327 e inicia o polling em segundo plano
      unawaited(_initializeAndStartPolling());
      return true;
    } catch (e) {
      debugPrint('[Bluetooth] Falha ao conectar: $e');
      _isConnecting = false;
      _isConnected = false;
      _errorMessage =
          'Não foi possível conectar ao scanner. Verifique se ele está ligado na tomada OBD-II.';
      notifyListeners();
      return false;
    }
  }

  Future<void> _initializeAndStartPolling() async {
    final conn = _connection;
    final stream = _inputBroadcast?.stream;
    if (conn == null || stream == null || !_isConnected) return;

    await _enqueue(() async {
      if (!_isConnected || _connection == null) return;
      _isInitializing = true;
      _errorMessage = null;
      notifyListeners();

      try {
        await ObdService.initializeElm327(conn, inputStream: stream);
      } finally {
        _isInitializing = false;
        notifyListeners();
      }
    });

    if (!_isConnected) return;

    // Executa a primeira leitura completa logo após o handshake
    await refreshEthanol(manual: true);

    // Inicia atualização periódica na frequência configurada (padrão rápido: 250 ms)
    _startPollingTimer();
  }

  void _startPollingTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(milliseconds: _pollingIntervalMs),
      (_) {
        if (_isConnected && !isBusy) {
          refreshEthanol(manual: false);
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 3. LEITURA DE ETANOL (01 52) + TELEMETRIA DO MOTOR (RPM, STFT, LTFT)
  // ---------------------------------------------------------------------------
  /// Consulta a ECU na fila serial FIFO atualizando a % de Etanol e os
  /// parâmetros pertinentes de telemetria do motor (RPM, STFT e LTFT).
  ///
  /// Quando [manual] é false (polling automático em background), os indicadores
  /// são atualizados em tempo real sem travar a interface com estado de loading.
  Future<void> refreshEthanol({bool manual = true}) async {
    if (!_isConnected || _connection == null || _inputBroadcast == null) return;
    if (_isReading || _isInitializing) return;
    if (!manual && _isPollingCycle) return;

    final bool showLoadingIndicator = manual;

    await _enqueue(() async {
      final conn = _connection;
      final stream = _inputBroadcast?.stream;
      if (!_isConnected || conn == null || stream == null) return;

      _isPollingCycle = true;
      if (showLoadingIndicator) {
        _isReading = true;
        notifyListeners();
      }

      try {
        final stopwatch = Stopwatch()..start();

        // 1. Leitura principal: Porcentagem de Etanol (Mode 01 PID 52)
        final ethanolResult = await ObdService.readEthanolPercentage(
          conn,
          inputStream: stream,
        );
        stopwatch.stop();

        _lastLatencyMs = stopwatch.elapsedMilliseconds;
        _lastRawResponse = ethanolResult.rawResponse;

        if (ethanolResult.success) {
          _ethanolPercentage = ethanolResult.percentage.clamp(0.0, 100.0);
          _errorMessage = null;
          _lastUpdatedAt = DateTime.now();

          // Sincroniza a leitura real com o veículo ativo na Garagem
          GarageController.instance.updateActiveVehicleTelemetry(
            ethanolPercentage: _ethanolPercentage!,
            isConnected: true,
            obdName: _connectedName,
            obdMacAddress: _connectedMac,
          );
          notifyListeners();
        }

        // 2. Leitura complementar de Telemetria do Motor (RPM, STFT e LTFT)
        int? rpm;
        double? stft;
        double? ltft;

        if (_isConnected) {
          rpm = await ObdService.readEngineRpm(conn, inputStream: stream);
          if (rpm != null) {
            _engineRpm = rpm;
            notifyListeners();
          }
        }
        if (_isConnected) {
          stft =
              await ObdService.readShortTermFuelTrim(conn, inputStream: stream);
          if (stft != null) {
            _shortTermFuelTrim = stft;
            notifyListeners();
          }
        }
        if (_isConnected) {
          ltft =
              await ObdService.readLongTermFuelTrim(conn, inputStream: stream);
          if (ltft != null) {
            _longTermFuelTrim = ltft;
            notifyListeners();
          }
        }

        // Verifica se a ECU respondeu a qualquer parâmetro neste ciclo ou se já há telemetria ativa.
        // Evita exibir falso aviso de "NO DATA / ignição desligada" quando os parâmetros estão sendo lidos.
        final bool anySuccessNow =
            ethanolResult.success || rpm != null || stft != null || ltft != null;
        final bool hasActiveTelemetry = _ethanolPercentage != null ||
            _engineRpm != null ||
            _shortTermFuelTrim != null ||
            _longTermFuelTrim != null;

        if (anySuccessNow || hasActiveTelemetry) {
          _errorMessage = null;
          if (anySuccessNow) {
            _lastUpdatedAt = DateTime.now();
          }
        } else {
          _errorMessage = ethanolResult.errorMessage;
        }

        // Registra um instantâneo no Diário do carro ao qual o leitor está
        // conectado (não importa qual carro está selecionado na Garagem).
        final target = GarageController.instance.telemetryTarget;
        if (anySuccessNow && target != null && !target.isDemo) {
          // Primeiro registro desta conexão: fixa o vínculo leitor <-> carro
          if (!target.isObdConnected &&
              _connectedName != null &&
              _connectedMac != null) {
            GarageController.instance.bindObdToVehicle(
              target.id,
              _connectedName!,
              _connectedMac!,
            );
          }
          DiaryController.instance.recordSnapshot(
            vehicleId: target.id,
            ethanolPercentage: _ethanolPercentage,
            rpm: _engineRpm,
            stft: _shortTermFuelTrim,
            ltft: _longTermFuelTrim,
          );
        }
      } catch (e) {
        if (_lastUpdatedAt == null) {
          _errorMessage = 'Erro ao consultar a ECU: $e';
        }
      } finally {
        _isPollingCycle = false;
        _isReading = false;
        notifyListeners();
      }
    });
  }

  /// Enfileira comandos para execução sequencial (Half-Duplex FIFO).
  Future<void> _enqueue(Future<void> Function() task) {
    _serialQueue = _serialQueue.then((_) => task()).catchError((Object e) {
      debugPrint('[OBD-II] Erro na fila serial: $e');
    });
    return _serialQueue;
  }

  void _handleRemoteDisconnect() {
    _cleanupResources();
    _isConnected = false;
    _isConnecting = false;
    _isInitializing = false;
    _isReading = false;
    _isPollingCycle = false;
    _errorMessage = 'Leitor OBD-II desconectado.';
    GarageController.instance.markAllDisconnected();
    notifyListeners();
  }

  /// Encerra a conexão serial com o leitor OBD-II de forma limpa.
  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _pollTimer = null;

    await _stateSub?.cancel();
    _stateSub = null;

    await _rawInputSub?.cancel();
    _rawInputSub = null;

    await _inputBroadcast?.close();
    _inputBroadcast = null;

    final conn = _connection;
    _connection = null;

    _isConnected = false;
    _isConnecting = false;
    _isInitializing = false;
    _isReading = false;
    _isPollingCycle = false;
    _connectedName = null;
    _connectedMac = null;
    _ethanolPercentage = null;
    _engineRpm = null;
    _shortTermFuelTrim = null;
    _longTermFuelTrim = null;
    _lastRawResponse = null;
    _lastLatencyMs = null;
    _lastUpdatedAt = null;
    _errorMessage = null;

    GarageController.instance.markAllDisconnected();
    notifyListeners();

    try {
      await conn?.finish();
    } catch (e) {
      debugPrint('[Bluetooth] Aviso ao encerrar socket: $e');
    }
  }

  void _cleanupResources() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _stateSub?.cancel();
    _stateSub = null;
    _rawInputSub?.cancel();
    _rawInputSub = null;
    _inputBroadcast?.close();
    _inputBroadcast = null;
    _connection = null;
  }
}
