import 'package:flutter/material.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import 'package:permission_handler/permission_handler.dart'; // Essencial para gerenciar permissões no Android 12+

import 'app_styles.dart';
import 'device_card.dart'; // Componente visual do card de dispositivo

class Connect extends StatefulWidget {
  const Connect({super.key});

  @override
  State<Connect> createState() => _ConnectState();
}

class _ConnectState extends State<Connect> {
  // Instância do plugin para gerenciar o Bluetooth Clássico
  final FlutterClassicBluetooth _bluetoothManager = FlutterClassicBluetooth();
  
  // Estados da tela
  bool isScanningDevices = true;      // Controla se está buscando/carregando os dispositivos
  bool isDeviceConnected = false;     // Indica se a conexão com o ELM327 foi estabelecida
  
  // Informações do dispositivo selecionado pelo usuário
  String? selectedDeviceName;
  String? selectedDeviceMacAddress;
  
  // Lista formatada para exibição na interface (Nome e Endereço MAC/Subtítulo)
  List<Map<String, String>> formattedPairedDevices = [];
  
  // Objeto de conexão ativo (usado para enviar comandos AT futuramente)
  BtcConnection? activeBluetoothConnection;

  @override
  void initState() {
    super.initState();
    // Ao entrar na tela, verificamos permissões e o estado do Bluetooth antes de carregar
    _checkPermissionsAndLoadDevices();
  }

  /// **Verificação de Permissões e Bluetooth:**
  /// Solicita as permissões obrigatórias do Android 12+ (BLUETOOTH_SCAN e BLUETOOTH_CONNECT)
  /// antes de tentar interagir com o adaptador.
  Future<void> _checkPermissionsAndLoadDevices() async {
    setState(() {
      isScanningDevices = true;
      selectedDeviceName = null;
      selectedDeviceMacAddress = null;
      formattedPairedDevices = [];
    });

    try {
      // Solicita permissões de Bluetooth e Localização necessárias
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      bool scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
      bool connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;

      if (!scanGranted || !connectGranted) {
        if (mounted) {
          setState(() {
            isScanningDevices = false;
          });
          _showFeedbackMessage(
            'Permissões de Bluetooth necessárias negadas. Ative-as nas configurações.',
            Colors.red,
          );
        }
        return;
      }

      // Prossegue para carregar os dispositivos pareados
      await _loadPairedBluetoothDevices();
    } catch (error) {
      if (mounted) {
        setState(() {
          isScanningDevices = false;
        });
        _showFeedbackMessage(
          'Erro: Verifique se o Bluetooth está ligado no telemóvel.',
          Colors.red,
        );
      }
    }
  }

  /// **Lógica de Busca:** 
  /// O Bluetooth Clássico (SPP) exige que o ELM327 esteja previamente pareado 
  /// nas configurações do Android. Esta função recupera essa lista do sistema.
  Future<void> _loadPairedBluetoothDevices() async {
    setState(() {
      isScanningDevices = true;
    });

    try {
      // Busca a lista de aparelhos já pareados no Android
      final rawPairedDevices = await _bluetoothManager.getPairedDevices();

      if (mounted) {
        setState(() {
          isScanningDevices = false;
          // Transforma os dados brutos do plugin em um formato limpo para o ListView
          formattedPairedDevices = rawPairedDevices.map((device) {
            return {
              'name': device.displayName.isNotEmpty 
                  ? device.displayName 
                  : 'Dispositivo Desconhecido',
              'sub': device.address, // Endereço MAC único do adaptador
            };
          }).toList();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          isScanningDevices = false;
        });
        _showFeedbackMessage(
          'Falha ao carregar dispositivos. Certifique-se de que o Bluetooth está ligado.',
          Colors.red,
        );
      }
    }
  }

  /// **Lógica de Conexão:**
  /// Abre um canal de comunicação serial (RFCOMM) utilizando o endereço MAC 
  /// do adaptador OBD-II selecionado pelo usuário.
  Future<void> _connectToSelectedBluetoothDevice() async {
    if (selectedDeviceMacAddress == null) return;

    try {
      // Garante permissão antes de conectar
      var scanStatus = await Permission.bluetoothScan.status;
      var connectStatus = await Permission.bluetoothConnect.status;

      if (!scanStatus.isGranted || !connectStatus.isGranted) {
        _showFeedbackMessage('Permissões de Bluetooth necessárias para conectar.', Colors.red);
        return;
      }

      // Tenta conectar ao endereço MAC via Bluetooth Clássico
      activeBluetoothConnection = await _bluetoothManager.connect(
        address: selectedDeviceMacAddress!,
      );

      if (activeBluetoothConnection != null && mounted) {
        setState(() {
          isDeviceConnected = true;
        });

        _showFeedbackMessage('Conectado a $selectedDeviceName com sucesso!', AppTheme.green);
      } else {
        if (mounted) {
          _showFeedbackMessage('Falha ao conectar ao adaptador OBD-II.', Colors.red);
        }
      }
    } catch (error) {
      if (mounted) {
        _showFeedbackMessage(
          'Erro de conexão: Verifique se o Bluetooth está ligado e o adaptador pareado.',
          Colors.red,
        );
      }
    }
  }

  /// Atalho para exibir mensagens temporárias na parte inferior da tela (SnackBar)
  void _showFeedbackMessage(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // O botão de conectar só fica habilitado se houver um dispositivo selecionado e não estiver conectado
    bool isReadyToConnect = selectedDeviceName != null && !isDeviceConnected;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho da Tela
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppTheme.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'DELTAMIX',
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  // Badge de Status da Conexão no Topo
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (isDeviceConnected ? AppTheme.green : Colors.red)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isDeviceConnected ? 'CONECTADO' : 'DESCONECTADO',
                      style: TextStyle(
                        color: isDeviceConnected ? AppTheme.green : Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Card de Status / Indicador Visual Central
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.bluetooth,
                      color: isScanningDevices
                          ? Colors.amber
                          : (isDeviceConnected ? AppTheme.green : Colors.red),
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isScanningDevices
                          ? 'A procurar dispositivos...'
                          : (isDeviceConnected
                                ? 'Conectado a $selectedDeviceName'
                                : 'Desconectado'),
                      style: const TextStyle(
                        color: AppTheme.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Título da Seção e Botão de Atualizar Lista
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'DISPOSITIVOS BLUETOOTH',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!isScanningDevices)
                    TextButton.icon(
                      onPressed: _checkPermissionsAndLoadDevices,
                      icon: const Icon(
                        Icons.refresh,
                        size: 14,
                        color: AppTheme.green,
                      ),
                      label: const Text(
                        'Atualizar',
                        style: TextStyle(color: AppTheme.green, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Lista Dinâmica de Dispositivos Pareados
              Expanded(
                child: isScanningDevices
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.amber),
                      )
                    : formattedPairedDevices.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum dispositivo encontrado. Verifique se o Bluetooth está ligado e o adaptador OBD-II está pareado nas configurações do Android.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.muted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: formattedPairedDevices.length,
                        itemBuilder: (context, index) {
                          final currentDevice = formattedPairedDevices[index];
                          final deviceName = currentDevice['name']!;
                          final deviceMacAddress = currentDevice['sub']!;
                          
                          return DeviceCard(
                            title: deviceName,
                            subtitle: deviceMacAddress,
                            isSelected: selectedDeviceName == deviceName,
                            onTap: () => setState(() {
                              selectedDeviceName = deviceName;
                              selectedDeviceMacAddress = deviceMacAddress;
                            }),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),

              // Botão Principal de Conexão
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReadyToConnect
                        ? AppTheme.green
                        : AppTheme.green.withOpacity(0.3),
                    foregroundColor: isReadyToConnect ? Colors.black : AppTheme.muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isReadyToConnect ? _connectToSelectedBluetoothDevice : null,
                  child: Text(
                    isDeviceConnected ? 'Conectado' : 'Conectar',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
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