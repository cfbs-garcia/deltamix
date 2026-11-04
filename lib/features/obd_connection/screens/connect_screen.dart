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
///
/// Utilizada para conectar ou reconectar um veículo existente ou em cadastro
/// diretamente ao leitor Bluetooth OBD-II pareado no Android.
class ConnectScreen extends StatefulWidget {
  final VehicleModel? pendingVehicle;

  const ConnectScreen({super.key, this.pendingVehicle});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  bool _isScanning = false;
  final ObdController _obd = ObdController.instance;

  // Lista real de dispositivos OBD-II pareados no celular
  List<Map<String, String>> _devices = [];

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  /// Busca os dispositivos Bluetooth pareados compatíveis com OBD-II/ELM327.
  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    try {
      final found = await _obd.getPairedObdDevices();
      if (mounted) {
        setState(() {
          _devices = found;
          _isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  /// Conecta via socket Bluetooth RFCOMM ao leitor selecionado.
  Future<void> _onDeviceSelected(Map<String, String> dev) async {
    if (_obd.isConnecting) return;

    final connected = await _obd.connect(dev['name']!, dev['address']!);

    if (!mounted) return;

    if (!connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _obd.errorMessage ?? 'Não foi possível conectar ao leitor OBD-II.',
          ),
          backgroundColor: AppColors.dangerNeon,
        ),
      );
      return;
    }

    if (widget.pendingVehicle != null) {
      // Salva o veículo com o scanner conectado
      final completeVehicle = widget.pendingVehicle!.copyWith(
        obdName: dev['name'],
        obdMacAddress: dev['address'],
        isObdConnected: true,
        ethanolPercentage:
            _obd.ethanolPercentage ?? widget.pendingVehicle!.ethanolPercentage,
      );

      GarageController.instance.addVehicle(completeVehicle);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${completeVehicle.displayName} conectado com sucesso!',
          ),
          backgroundColor: AppColors.surfaceCard,
        ),
      );

      // Abre diretamente o Diagnóstico Mínimo do carro recém-conectado
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

    return ListenableBuilder(
      listenable: _obd,
      builder: (context, _) {
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.green,
                        ),
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
                    child: _isScanning
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.green,
                            ),
                          )
                        : _devices.isEmpty
                            ? Center(
                                child: Text(
                                  'Nenhum leitor OBD-II pareado encontrado.\nPareie seu scanner nas configurações de Bluetooth do celular.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _devices.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final dev = _devices[index];

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.06,
                                        ),
                                      ),
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceInput,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.bluetooth_searching,
                                          color: AppColors.obdCyan,
                                        ),
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
                                        style: TextStyle(
                                          color: AppTheme.muted,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                      trailing: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.green,
                                          foregroundColor: Colors.black,
                                          minimumSize: const Size(80, 36),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                        ),
                                        onPressed: _obd.isConnecting
                                            ? null
                                            : () => _onDeviceSelected(dev),
                                        child: Text(
                                          _obd.isConnecting
                                              ? '...'
                                              : 'Conectar',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
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
                        GarageController.instance.addVehicle(
                          widget.pendingVehicle!,
                        );
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Pular conexão e conectar depois',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
