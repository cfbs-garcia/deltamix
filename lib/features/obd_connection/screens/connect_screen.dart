import 'package:flutter/material.dart';
import '../../../core/bluetooth/obd_controller.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../fuel_dashboard/screens/quick_diagnostic_screen.dart';
import '../../garage/controllers/garage_controller.dart';

/// ============================================================================
/// TELA DE BUSCA E PAREAMENTO BLUETOOTH OBD-II (CONNECT)
/// ============================================================================
class ConnectScreen extends StatefulWidget {
  final VehicleModel? pendingVehicle;

  const ConnectScreen({super.key, this.pendingVehicle});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  bool _isScanning = false;
  final ObdController _obd = ObdController.instance;

  // Lista simulada de dispositivos encontrados no scan
  final List<Map<String, String>> _devices = [
    {
      'name': 'OBDII (Vgate iCar)',
      'address': '00:1D:A5:02:C4:91',
      'type': 'ELM327 v1.5 / SPP',
    },
    {
      'name': 'Viecar BLE-SPP',
      'address': '88:18:56:88:99:AA',
      'type': 'Viecar Auto-Connect',
    },
    {
      'name': 'ELM327 Mini BT',
      'address': 'DC:0D:30:11:22:33',
      'type': 'Generic ELM327',
    },
  ];

  void _startScan() async {
    setState(() => _isScanning = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _isScanning = false);
  }

  void _onDeviceSelected(Map<String, String> dev) async {
    await _obd.connect(dev['name']!, dev['address']!);

    if (!mounted) return;

    if (widget.pendingVehicle != null) {
      // Salva o veículo com o scanner pareado
      final completeVehicle = widget.pendingVehicle!.copyWith(
        obdName: dev['name'],
        obdMacAddress: dev['address'],
        isObdConnected: true,
      );

      GarageController.instance.addVehicle(completeVehicle);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${completeVehicle.displayName} conectado com sucesso!'),
          backgroundColor: AppColors.surfaceCard,
        ),
      );

      // Abre diretamente o Diagnóstico Mínimo do carro recém-criado
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QuickDiagnosticScreen(vehicle: completeVehicle),
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleTitle = widget.pendingVehicle != null
        ? 'Conectar ${widget.pendingVehicle!.displayName}'
        : 'Conectar Leitor OBD-II';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(vehicleTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.green),
                  )
                : const Icon(Icons.refresh_rounded, color: AppTheme.green),
            onPressed: _isScanning ? null : _startScan,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ligue a ignição do veículo e selecione o leitor Bluetooth:',
                style: TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: ListView.separated(
                  itemCount: _devices.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final dev = _devices[index];

                    return Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceInput,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.bluetooth_searching, color: AppColors.obdCyan),
                        ),
                        title: Text(
                          dev['name']!,
                          style: const TextStyle(
                            color: AppTheme.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          '${dev['type']} • ${dev['address']}',
                          style: TextStyle(color: AppTheme.muted, fontSize: 11.5),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.green,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(80, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () => _onDeviceSelected(dev),
                          child: const Text('Parear', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                ),
              ),

              if (widget.pendingVehicle != null) ...[
                TextButton(
                  onPressed: () {
                    // Pular conexão no momento e apenas salvar o carro
                    GarageController.instance.addVehicle(widget.pendingVehicle!);
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Pular conexão e conectar depois',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
