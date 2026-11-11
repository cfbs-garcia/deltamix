import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
/// 3. Serviço de 2º plano (WakeLock + Foreground Service) para continuar
///    registrando Sprints e Diário com a tela desligada ou em outros apps.
/// 4. Reconexão automática quando o motorista sai/desliga o carro e retorna,
///    além de recuperação automática de protocolo quando a ignição religa.
class ObdController extends ChangeNotifier {
  // Padrão Singleton
  static final ObdController instance = ObdController._internal();
  ObdController._internal();

  static const MethodChannel _bgChannel = MethodChannel('deltamix/background');

  final FlutterClassicBluetooth bluetooth = FlutterClassicBluetooth();

  BtcConnection? _connection;
  StreamSubscription<BtcConnectionState>? _stateSub;
  StreamSubscription<Uint8List>? _rawInputSub;
  StreamController<Uint8List>? _inputBroadcast;
  Timer? _pollTimer;
  Timer? _reconnectTimer;

  // Fila serial FIFO para garantir que dois comandos nunca colidam no ELM327
  Future<void> _serialQueue = Future.value();

  // ---------------------------------------------------------------------------
  // ESTADOS INTERNOS DE CONEXÃO, RECONEXÃO AUTOMÁTICA E TELEMETRIA
  // ---------------------------------------------------------------------------
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isInitializing = false;
  bool _isReading = false;
  bool _isPollingCycle = false;

  /// Reconexão automática quando o motorista desliga/sai do carro e retorna
  bool _autoReconnectEnabled = false;
  bool _isAutoReconnecting = false;
  String? _targetDeviceName;
  String? _targetMacAddress;

  /// Contador de ciclos sem resposta da ECU (ex.: ignição desligada com scanner no 12V)
  int _consecutiveEmptyCycles = 0;
  DateTime? _lastBgNotificationUpdate;

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
  bool get isAutoReconnecting => _isAutoReconnecting;
  bool get isBusy =>
      _isConnecting || _isInitializing || _isReading || _isPollingCycle;

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

  String? get connectedName => _connectedName ?? _targetDeviceName;
  String? get connectedMac => _connectedMac ?? _targetMacAddress;
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
  // SERVIÇO DE SEGUNDO PLANO (WAKELOCK + NOTIFICAÇÃO PERSISTENTE NO ANDROID)
  // ---------------------------------------------------------------------------
  Future<void> _updateBackgroundService({
    required String title,
    required String body,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _bgChannel.invokeMethod('startOrUpdate', {
        'title': title,
        'body': body,
      });
    } catch (e) {
      debugPrint('[BackgroundService] Aviso: $e');
    }
  }

  Future<void> _stopBackgroundService() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _bgChannel.invokeMethod('stop');
    } catch (e) {
      debugPrint('[BackgroundService] Aviso ao parar: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // AUTO-CONNECT AO VEÍCULO VINCULADO E RECONEXÃO AUTOMÁTICA
  // ---------------------------------------------------------------------------
  /// Ativa a conexão e reconexão automática para o scanner já vinculado ao veículo
  /// (por exemplo, ao abrir o app ou quando o motorista retorna ao carro).
  void enableAutoConnectForVehicle(String deviceName, String macAddress) {
    final cleanMac = macAddress.trim();
    if (cleanMac.isEmpty) return;

    // Se já está conectado ou tentando conectar a este mesmo endereço, mantém
    if ((_isConnected || _isConnecting) && _connectedMac == cleanMac) {
      return;
    }

    _targetDeviceName = deviceName.trim().isNotEmpty
        ? deviceName.trim()
        : 'Leitor OBD-II';
    _targetMacAddress = cleanMac;
    _autoReconnectEnabled = true;

    if (!_isConnected && !_isConnecting) {
      unawaited(_attemptAutoConnect());
    }
  }

  void _startAutoReconnectTimer() {
    _reconnectTimer?.cancel();
    if (!_autoReconnectEnabled || _targetMacAddress == null) return;

    _isAutoReconnecting = true;
    notifyListeners();

    _reconnectTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!_autoReconnectEnabled || _isConnected || _isConnecting) return;
      unawaited(_attemptAutoConnect());
    });
  }

  Future<void> _attemptAutoConnect() async {
    if (!_autoReconnectEnabled || _isConnected || _isConnecting) return;
    final name = _targetDeviceName;
    final mac = _targetMacAddress;
    if (name == null || mac == null || mac.isEmpty) return;

    final ok = await connect(name, mac, isAutoRetry: true);
    if (!ok && _autoReconnectEnabled && !_isConnected) {
      // Continua aguardando silenciosamente o motorista voltar ao carro
      if (_reconnectTimer == null || !_reconnectTimer!.isActive) {
        _startAutoReconnectTimer();
      }
    }
  }

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
  Future<bool> connect(
    String deviceName,
    String macAddress, {
    bool isAutoRetry = false,
  }) async {
    if (_isConnecting) return false;

    if (_isConnected) {
      await disconnect(manual: false);
    }

    _targetDeviceName = deviceName;
    _targetMacAddress = macAddress;
    _autoReconnectEnabled = true;

    if (!isAutoRetry) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _isAutoReconnecting = false;
      _errorMessage = null;
    }

    _isConnecting = true;
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
          timeout: Duration(seconds: isAutoRetry ? 5 : 8),
        );
      } catch (_) {
        debugPrint('[Bluetooth] Insecure falhou, tentando modo seguro...');
        conn = await bluetooth.connect(
          address: macAddress,
          secure: true,
          timeout: Duration(seconds: isAutoRetry ? 5 : 8),
        );
      }

      if (!conn.isConnected) {
        _isConnecting = false;
        if (!isAutoRetry) {
          _errorMessage = 'Não foi possível estabelecer conexão com o scanner.';
        }
        notifyListeners();
        return false;
      }

      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _isAutoReconnecting = false;
      _consecutiveEmptyCycles = 0;

      _connection = conn;
      _connectedName = deviceName;
      _connectedMac = macAddress;
      _isConnecting = false;
      _isConnected = true;
      _errorMessage = null;

      // Inicia o serviço de 2º plano (WakeLock) para funcionar com tela apagada
      unawaited(
        _updateBackgroundService(
          title: 'Deltamix • Conectado ao $deviceName',
          body: 'Monitorando ECU e registrando Sprint em segundo plano.',
        ),
      );

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

      // Monitora desconexão física do adaptador (ex.: motorista saiu/desligou o carro)
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
      if (isAutoRetry) {
        _isAutoReconnecting = true;
        _errorMessage =
            'Aguardando veículo (${_targetDeviceName ?? "OBD-II"}) para reconectar automaticamente...';
      } else {
        _errorMessage =
            'Não foi possível conectar ao scanner. Quando ligar o veículo, o app tentará reconectar automaticamente.';
        _startAutoReconnectTimer();
      }
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
        if (!_isConnected) return;

        // 2. Leituras de telemetria do motor na mesma fila serial
        final rpmResult = await ObdService.readEngineRpm(
          conn,
          inputStream: stream,
        );
        if (!_isConnected) return;

        final stftResult = await ObdService.readShortTermFuelTrim(
          conn,
          inputStream: stream,
        );
        if (!_isConnected) return;

        final ltftResult = await ObdService.readLongTermFuelTrim(
          conn,
          inputStream: stream,
        );
        if (!_isConnected) return;

        stopwatch.stop();
        _lastLatencyMs = stopwatch.elapsedMilliseconds;
        if (ethanolResult.rawResponse.isNotEmpty) {
          _lastRawResponse = ethanolResult.rawResponse;
        }

        // Atualiza sensores auxiliares que responderam com sucesso neste ciclo
        if (rpmResult != null) _engineRpm = rpmResult;
        if (stftResult != null) _shortTermFuelTrim = stftResult;
        if (ltftResult != null) _longTermFuelTrim = ltftResult;

        if (ethanolResult.success) {
          _ethanolPercentage = ethanolResult.percentage;
          _errorMessage = null;
          _lastUpdatedAt = DateTime.now();

          // Sincroniza o veículo ativo na Garagem com o valor real lido da ECU
          GarageController.instance.updateActiveVehicleTelemetry(
            ethanolPercentage: _ethanolPercentage!,
            isConnected: true,
            obdName: _connectedName,
            obdMacAddress: _connectedMac,
          );
        }

        final bool anySuccessNow =
            ethanolResult.success ||
            rpmResult != null ||
            stftResult != null ||
            ltftResult != null;
        final bool hasActiveTelemetry =
            _ethanolPercentage != null ||
            _engineRpm != null ||
            _shortTermFuelTrim != null ||
            _longTermFuelTrim != null;

        if (anySuccessNow) {
          _consecutiveEmptyCycles = 0;
          _errorMessage = null;
          _lastUpdatedAt = DateTime.now();

          // Renova o WakeLock e atualiza a notificação em segundo plano a cada 45s
          final now = DateTime.now();
          if (_lastBgNotificationUpdate == null ||
              now.difference(_lastBgNotificationUpdate!).inSeconds >= 45) {
            _lastBgNotificationUpdate = now;
            final ethLabel = _ethanolPercentage != null
                ? 'Etanol: ${_ethanolPercentage!.toStringAsFixed(0)}%'
                : 'ECU ativa';
            final rpmLabel =
                _engineRpm != null ? ' • $_engineRpm RPM' : '';
            unawaited(
              _updateBackgroundService(
                title: 'Deltamix • $ethLabel$rpmLabel',
                body: 'Monitorando Sprint e Diário em segundo plano.',
              ),
            );
          }
        } else {
          _consecutiveEmptyCycles++;

          // Se o motorista desligou a chave (ECU parou de responder por alguns ciclos),
          // prepara a sessão para gravar imediatamente assim que o motor religar.
          if (_consecutiveEmptyCycles == 4) {
            DiaryController.instance.resetSessionFlags();
          }

          // A cada 8 ciclos sem resposta (motor desligado, mas scanner no 12V contínuo),
          // envia ATSP0 para que o ELM327 ressincronize o barramento CAN assim que
          // o motorista der partida novamente sem precisar reabrir o app.
          if (_consecutiveEmptyCycles % 8 == 0) {
            try {
              await ObdService.sendCommand(
                conn,
                'ATSP0',
                inputStream: stream,
                timeout: const Duration(milliseconds: 1200),
              );
            } catch (_) {}
          }

          if (hasActiveTelemetry) {
            _errorMessage = null;
          } else {
            _errorMessage = ethanolResult.errorMessage;
          }
        }

        // Registra um instantâneo no Diário / Sprint do carro ao qual o leitor está
        // conectado (mesmo com a tela desligada ou app em 2º plano).
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

  /// Disparado quando o sinal Bluetooth cai fisicamente (motorista saiu do carro
  /// ou desligou a chave e o scanner desligou). Mantém o app aguardando para
  /// reconectar automaticamente assim que o motorista voltar ao veículo!
  void _handleRemoteDisconnect() {
    _cleanupResources();
    _isConnected = false;
    _isConnecting = false;
    _isInitializing = false;
    _isReading = false;
    _isPollingCycle = false;
    DiaryController.instance.resetSessionFlags();
    GarageController.instance.markAllDisconnected();

    if (_autoReconnectEnabled && _targetMacAddress != null) {
      _errorMessage =
          'Sinal perdido. O app reconectará sozinho quando você voltar ao veículo.';
      unawaited(
        _updateBackgroundService(
          title: 'Deltamix • Aguardando retorno ao veículo',
          body:
              'Pronto para reconectar automaticamente ao ${_targetDeviceName ?? "OBD-II"}.',
        ),
      );
      _startAutoReconnectTimer();
    } else {
      _errorMessage = 'Leitor OBD-II desconectado.';
      unawaited(_stopBackgroundService());
    }

    notifyListeners();
  }

  /// Encerra a conexão serial com o leitor OBD-II de forma limpa.
  /// Se [manual] for true (usuário clicou em Desconectar), desativa também a reconexão automática.
  Future<void> disconnect({bool manual = true}) async {
    _pollTimer?.cancel();
    _pollTimer = null;

    if (manual) {
      _autoReconnectEnabled = false;
      _isAutoReconnecting = false;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _targetDeviceName = null;
      _targetMacAddress = null;
      unawaited(_stopBackgroundService());
    }

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

    DiaryController.instance.resetSessionFlags();
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
