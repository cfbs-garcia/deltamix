import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

import 'obd_service.dart';

/// Gerenciador global (Singleton) da conexão Bluetooth OBD-II e leitura em tempo real.
///
/// Mantém a conexão ativa ao navegar entre as telas [Connect] e [Home] e garante
/// uma única assinatura no stream nativo de bytes para evitar concorrência no socket.
class ObdController extends ChangeNotifier {
  ObdController._();
  static final ObdController instance = ObdController._();

  final FlutterClassicBluetooth bluetooth = FlutterClassicBluetooth();

  BtcConnection? _connection;
  StreamSubscription<BtcConnectionState>? _stateSub;
  StreamSubscription<Uint8List>? _rawInputSub;
  StreamController<Uint8List>? _inputBroadcast;
  Timer? _pollTimer;

  // Fila simples para serializar comandos AT/OBD no barramento serial
  Future<void> _serialQueue = Future.value();

  bool isConnecting = false;
  bool isConnected = false;
  bool isInitializing = false;
  bool isReading = false;

  String? connectedName;
  String? connectedMac;

  /// Última porcentagem de etanol lida com sucesso (0.0 a 100.0), ou null se ainda não lida.
  double? ethanolPercentage;
  String? lastRawResponse;
  String? errorMessage;
  DateTime? lastUpdatedAt;

  bool get isBusy => isConnecting || isInitializing || isReading;

  /// Conecta ao adaptador OBD-II, inicializa o ELM327 e inicia a leitura de etanol.
  Future<bool> connect({
    required String name,
    required String mac,
  }) async {
    if (isConnecting) return false;

    if (isConnected) {
      await disconnect();
    }

    isConnecting = true;
    ethanolPercentage = null;
    lastRawResponse = null;
    lastUpdatedAt = null;
    errorMessage = null;
    notifyListeners();

    try {
      debugPrint('[Bluetooth] Tentando abrir socket serial com $mac...');

      BtcConnection? conn;
      try {
        conn = await bluetooth.connect(
          address: mac,
          secure: false, // Insecure socket (padrão dos clones ELM327)
          timeout: const Duration(seconds: 8),
        );
      } catch (_) {
        debugPrint('[Bluetooth] Insecure falhou, tentando modo seguro...');
        conn = await bluetooth.connect(
          address: mac,
          secure: true,
          timeout: const Duration(seconds: 8),
        );
      }

      if (!conn.isConnected) {
        isConnecting = false;
        notifyListeners();
        return false;
      }

      _connection = conn;
      connectedName = name;
      connectedMac = mac;
      isConnecting = false;
      isConnected = true;

      // Assinatura única no EventChannel nativo para evitar múltiplas threads de leitura no Android
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

      // Monitora queda física da conexão (ex: adaptador removido da porta OBD-II)
      _stateSub?.cancel();
      _stateSub = conn.stateStream.listen((state) {
        if (state == BtcConnectionState.disconnected && isConnected) {
          _handleRemoteDisconnect();
        }
      });

      notifyListeners();

      // Inicializa o ELM327 e faz a primeira leitura em background sem travar a UI
      unawaited(_initializeAndStartPolling());
      return true;
    } catch (e) {
      debugPrint('[Bluetooth] Falha ao conectar: $e');
      isConnecting = false;
      isConnected = false;
      errorMessage = 'Não foi possível conectar ao adaptador OBD-II.';
      notifyListeners();
      return false;
    }
  }

  Future<void> _initializeAndStartPolling() async {
    final conn = _connection;
    final stream = _inputBroadcast?.stream;
    if (conn == null || stream == null || !isConnected) return;

    await _enqueue(() async {
      if (!isConnected || _connection == null) return;
      isInitializing = true;
      errorMessage = null;
      notifyListeners();

      try {
        await ObdService.initializeElm327(conn, inputStream: stream);
      } finally {
        isInitializing = false;
        notifyListeners();
      }
    });

    if (!isConnected) return;

    // Faz a leitura imediata logo após inicializar
    await refreshEthanol();

    // Atualiza periodicamente a cada 8 segundos enquanto estiver conectado
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (isConnected && !isBusy) {
        refreshEthanol();
      }
    });
  }

  /// Solicita uma leitura atualizada da porcentagem de etanol (PID 01 52).
  Future<void> refreshEthanol() async {
    if (!isConnected || _connection == null || _inputBroadcast == null) return;
    if (isReading || isInitializing) return;

    await _enqueue(() async {
      final conn = _connection;
      final stream = _inputBroadcast?.stream;
      if (!isConnected || conn == null || stream == null) return;

      isReading = true;
      notifyListeners();

      try {
        final result = await ObdService.readEthanolPercentage(
          conn,
          inputStream: stream,
        );

        lastRawResponse = result.rawResponse;
        if (result.success) {
          ethanolPercentage = result.percentage.clamp(0.0, 100.0);
          errorMessage = null;
          lastUpdatedAt = DateTime.now();
        } else {
          errorMessage = result.errorMessage;
        }
      } catch (e) {
        errorMessage = 'Erro ao ler sensor de etanol: $e';
      } finally {
        isReading = false;
        notifyListeners();
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() task) {
    _serialQueue = _serialQueue.then((_) => task()).catchError((Object e) {
      debugPrint('[OBD-II] Erro na fila serial: $e');
    });
    return _serialQueue;
  }

  void _handleRemoteDisconnect() {
    _cleanupResources();
    isConnected = false;
    isConnecting = false;
    isInitializing = false;
    isReading = false;
    errorMessage = 'Leitor OBD-II desconectado.';
    notifyListeners();
  }

  /// Desconecta de forma limpa do leitor OBD-II.
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

    isConnected = false;
    isConnecting = false;
    isInitializing = false;
    isReading = false;
    connectedName = null;
    connectedMac = null;
    ethanolPercentage = null;
    lastRawResponse = null;
    lastUpdatedAt = null;
    errorMessage = null;
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
