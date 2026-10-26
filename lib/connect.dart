import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_styles.dart';
import 'device_card.dart';

class Connect extends StatefulWidget {
  const Connect({super.key});

  @override
  State<Connect> createState() => _ConnectState();
}

class _ConnectState extends State<Connect> {
  final FlutterClassicBluetooth _bluetooth = FlutterClassicBluetooth();

  // Estados principais de controle
  bool isScanning = true;
  bool isConnecting = false;
  bool isConnected = false;

  // Dispositivo selecionado
  String? selectedName;
  String? selectedMac;

  // Lista apenas com os dispositivos de interesse (OBD, ELM, VGATE, SCAN)
  List<Map<String, String>> obdDevices = [];

  BtcConnection? _activeConnection;
  StreamSubscription<BtcConnectionState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _initBluetoothAndLoad();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _activeConnection?.finish();
    super.dispose();
  }

  /// Pede permissões e carrega os aparelhos pareados
  Future<void> _initBluetoothAndLoad() async {
    setState(() {
      isScanning = true;
      selectedName = null;
      selectedMac = null;
      obdDevices = [];
    });

    try {
      // Solicita permissões de Bluetooth e Localização
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      // Busca todos os pareados no Android
      final rawDevices = await _bluetooth.getPairedDevices();

      // Palavras-chave dos adaptadores veiculares que nos interessam
      final allowedKeywords = ['obd', 'elm', 'vgate', 'scan', 'vlinker', 'viecar'];

      // Filtra estritamente apenas os leitores de interesse, ignorando caixas de som, fones e afins
      final filtered = rawDevices.where((device) {
        final name = device.displayName.toLowerCase();
        return allowedKeywords.any((key) => name.contains(key));
      }).map((device) {
        return {
          'name': device.displayName.isNotEmpty ? device.displayName : 'Leitor OBD-II',
          'sub': device.address,
        };
      }).toList();

      if (mounted) {
        setState(() {
          obdDevices = filtered;
          isScanning = false;
        });
      }
    } catch (e) {
      debugPrint('[Bluetooth] Erro ao listar dispositivos: $e');
      if (mounted) {
        setState(() => isScanning = false);
        _notify('Verifique se o Bluetooth do celular está ligado.', Colors.red);
      }
    }
  }

  /// Conecta ou desconecta do leitor OBD-II selecionado
  Future<void> _toggleConnection() async {
    if (selectedMac == null || isConnecting) return;

    // Se já estiver conectado, aperta de novo para desconectar
    if (isConnected) {
      await _disconnect();
      return;
    }

    setState(() => isConnecting = true);

    try {
      debugPrint('[Bluetooth] Tentando abrir socket serial com $selectedMac...');

      // Leitores ELM327 funcionam melhor com conexões RFCOMM sem criptografia estrita (secure: false).
      // Se der falha, tentamos o modo seguro por garantia.
      BtcConnection? conn;
      try {
        conn = await _bluetooth.connect(
          address: selectedMac!,
          secure: false, // Insecure socket (padrão dos clones ELM327)
          timeout: const Duration(seconds: 8),
        );
      } catch (_) {
        debugPrint('[Bluetooth] Insecure falhou, tentando modo seguro...');
        conn = await _bluetooth.connect(
          address: selectedMac!,
          secure: true,
          timeout: const Duration(seconds: 8),
        );
      }

      if (conn.isConnected && mounted) {
        _activeConnection = conn;

        // Escuta se o leitor for desligado ou removido da tomada do carro
        _stateSub?.cancel();
        _stateSub = conn.stateStream.listen((state) {
          if (state == BtcConnectionState.disconnected && mounted) {
            setState(() {
              isConnected = false;
              _activeConnection = null;
            });
            _notify('Leitor OBD-II desconectado.', Colors.orange);
          }
        });

        setState(() {
          isConnected = true;
          isConnecting = false;
        });

        _notify('Conectado a $selectedName com sucesso!', AppTheme.green);
      }
    } catch (e) {
      debugPrint('[Bluetooth] Falha ao conectar: $e');
      if (mounted) {
        setState(() {
          isConnecting = false;
          isConnected = false;
        });
        _notify('Não foi possível conectar. Verifique se o leitor está ligado.', Colors.red);
      }
    }
  }

  /// Desconecta de forma limpa
  Future<void> _disconnect() async {
    await _stateSub?.cancel();
    _stateSub = null;
    await _activeConnection?.finish();
    _activeConnection = null;

    if (mounted) {
      setState(() => isConnected = false);
      _notify('Desconectado.', Colors.grey);
    }
  }

  void _notify(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canPress = selectedName != null && !isConnecting;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho simples e direto
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppTheme.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'DELTAMIX',
                        style: TextStyle(color: AppTheme.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (isConnected ? AppTheme.green : Colors.red).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      isConnected ? 'CONECTADO' : 'DESCONECTADO',
                      style: TextStyle(
                        color: isConnected ? AppTheme.green : Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Card de status visual
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(
                      isConnecting
                          ? Icons.bluetooth_searching
                          : (isConnected ? Icons.bluetooth_connected : Icons.bluetooth),
                      color: isConnecting
                          ? Colors.amber
                          : (isConnected ? AppTheme.green : AppTheme.muted),
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isConnecting
                          ? 'Conectando ao aparelho...'
                          : (isConnected ? 'Conectado a $selectedName' : 'Selecione seu aparelho OBD-II'),
                      style: const TextStyle(color: AppTheme.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Título da lista filtrada com botão de recarregar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'APARELHOS OBD-II DISPONÍVEIS',
                    style: TextStyle(color: AppTheme.muted, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  if (!isScanning)
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18, color: AppTheme.green),
                      onPressed: _initBluetoothAndLoad,
                      tooltip: 'Atualizar lista',
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Lista fluida exibindo SOMENTE os aparelhos automotivos
              Expanded(
                child: isScanning
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.green))
                    : obdDevices.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.search_off, color: AppTheme.muted, size: 40),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Nenhum aparelho OBD-II encontrado.',
                                    style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Certifique-se de parear seu leitor (OBD, ELM327 ou VGATE) nas configurações de Bluetooth do celular primeiro.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppTheme.muted, fontSize: 13),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: _initBluetoothAndLoad,
                                    icon: const Icon(Icons.refresh, color: AppTheme.green),
                                    label: const Text('Buscar novamente', style: TextStyle(color: AppTheme.green)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: obdDevices.length,
                            itemBuilder: (context, index) {
                              final dev = obdDevices[index];
                              final name = dev['name']!;
                              final mac = dev['sub']!;

                              return DeviceCard(
                                title: name,
                                subtitle: mac,
                                isSelected: selectedMac == mac,
                                onTap: () {
                                  if (isConnected) {
                                    _notify('Desconecte antes de escolher outro aparelho.', Colors.orange);
                                    return;
                                  }
                                  setState(() {
                                    selectedName = name;
                                    selectedMac = mac;
                                  });
                                },
                              );
                            },
                          ),
              ),

              const SizedBox(height: 12),

              // Botão de ação fluido e limpo
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected
                        ? Colors.red.shade700
                        : (canPress ? AppTheme.green : AppTheme.green.withValues(alpha: 0.3)),
                    foregroundColor: isConnected
                        ? Colors.white
                        : (canPress ? Colors.black : AppTheme.muted),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: canPress ? _toggleConnection : null,
                  child: isConnecting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('Conectando...', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        )
                      : Text(
                          isConnected ? 'Desconectar' : 'Conectar',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
