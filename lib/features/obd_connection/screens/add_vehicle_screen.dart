import 'package:flutter/material.dart';
import '../../../core/bluetooth/obd_controller.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../garage/controllers/garage_controller.dart';

/// ============================================================================
/// TELA DE BUSCA E CADASTRO VIA BLUETOOTH OBD-II
/// ============================================================================
///
/// Reproduz fielmente a interface da imagem de referência:
/// - Topo: Título DELTAMIX com badge [DESCONECTADO].
/// - Card superior com ícone Bluetooth: "Selecione seu aparelho OBD-II".
/// - Campo opcional de Apelido / Modelo do Veículo.
/// - Seção "APARELHOS OBD-II DISPONÍVEIS" com ícone de refresh.
/// - Estado de lista com aparelhos encontrados ou estado vazio ("Nenhum aparelho encontrado").
/// - Botão inferior de largura total: "Conectar".
class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _obd = ObdController.instance;
  final _nameController = TextEditingController();

  bool _isScanning = false;
  int? _selectedDeviceIndex;

  // Lista de dispositivos encontrados (simulação / scan)
  List<Map<String, String>> _availableDevices = [
    {
      'name': 'OBDII',
      'address': '00:1D:A5:02:C4:91',
      'type': 'ELM327 v1.5 Bluetooth',
    },
    {
      'name': 'v-link',
      'address': '88:18:56:88:99:AA',
      'type': 'Vgate iCar Pro SPP',
    },
    {
      'name': 'Viecar BLE-SPP',
      'address': 'DC:0D:30:11:22:33',
      'type': 'Viecar OBD-II Adapter',
    },
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _triggerScan() async {
    setState(() {
      _isScanning = true;
      _selectedDeviceIndex = null;
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _handleConnect() async {
    if (_selectedDeviceIndex == null) return;

    final selectedDev = _availableDevices[_selectedDeviceIndex!];

    // Conecta via ObdController
    await _obd.connect(selectedDev['name']!, selectedDev['address']!);

    // Cria e cadastra o veículo
    final rawName = _nameController.text.trim();
    final vehicleName = rawName.isNotEmpty ? rawName : 'Civic 2.0 Flex';

    final newCar = VehicleModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      model: vehicleName,
      plate: 'BRA-${(1000 + (DateTime.now().millisecond % 9000)).toString()}',
      nickname: rawName.isNotEmpty ? rawName : null,
      obdName: selectedDev['name'],
      obdMacAddress: selectedDev['address'],
      isObdConnected: true,
      ethanolPercentage: 72.4, // Leitura inicial
    );

    GarageController.instance.addVehicle(newCar);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${newCar.displayName} conectado via ${selectedDev['name']}!'),
          backgroundColor: AppColors.surfaceCard,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = _selectedDeviceIndex != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0D10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'DELTAMIX',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          // Badge DESCONECTADO (Conforme a imagem de referência)
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4A1015),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFF3B56).withValues(alpha: 0.4)),
              ),
              child: const Center(
                child: Text(
                  'DESCONECTADO',
                  style: TextStyle(
                    color: Color(0xFFFF5252),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  // 1. CARD PRINCIPAL COM ÍCONE BLUETOOTH (EXATO AO PRINT)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14161C),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: const [
                        Icon(
                          Icons.bluetooth_rounded,
                          size: 32,
                          color: Color(0xFF9EACB9),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Selecione seu aparelho OBD-II',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2. CAMPO OPCIONAL DE APELIDO / MODELO DO CARRO
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF14161C),
                      hintText: 'Apelido do Carro (Opcional - ex: Civic 2.0 Flex)',
                      hintStyle: TextStyle(color: AppTheme.muted, fontSize: 13),
                      prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded, color: Color(0xFF9EACB9), size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.ethanolNeon, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 3. SEÇÃO: APARELHOS OBD-II DISPONÍVEIS + ÍCONE REFRESH VERDE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'APARELHOS OBD-II DISPONÍVEIS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7A8394),
                      letterSpacing: 1.2,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _isScanning ? null : _triggerScan,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: _isScanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.ethanolNeon,
                              ),
                            )
                          : const Icon(
                              Icons.refresh_rounded,
                              size: 18,
                              color: AppColors.ethanolNeon,
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 4. LISTA DE DISPOSITIVOS OU ESTADO VAZIO
            Expanded(
              child: _isScanning
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.ethanolNeon),
                    )
                  : _availableDevices.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          itemCount: _availableDevices.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final dev = _availableDevices[index];
                            final isSelected = _selectedDeviceIndex == index;

                            return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                setState(() {
                                  _selectedDeviceIndex = index;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF14161C),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.ethanolNeon
                                        : Colors.white.withValues(alpha: 0.05),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.bluetooth_rounded,
                                      size: 20,
                                      color: isSelected ? AppColors.ethanolNeon : const Color(0xFF7A8394),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dev['name']!,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: isSelected ? AppColors.ethanolNeon : Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${dev['type']} • ${dev['address']}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF7A8394),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 20,
                                        color: AppColors.ethanolNeon,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // 5. BOTÃO INFERIOR DE CONECTAR (CONFORME O PRINT)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasSelection
                      ? AppColors.ethanolNeon
                      : const Color(0xFF181A20),
                  foregroundColor: hasSelection
                      ? Colors.black
                      : const Color(0xFF454B59),
                  elevation: hasSelection ? 6 : 0,
                  shadowColor: hasSelection ? AppColors.ethanolGlow : Colors.transparent,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(27),
                  ),
                ),
                onPressed: hasSelection ? _handleConnect : null,
                child: const Text(
                  'Conectar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Estado Vazio (quando nenhum aparelho for encontrado, exato ao print)
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 54,
              color: Color(0xFF7A8394),
            ),
            const SizedBox(height: 18),
            const Text(
              'Nenhum aparelho OBD-II encontrado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Certifique-se de parear seu leitor (OBD, ELM327 ou VGATE) nas configurações de Bluetooth do celular primeiro.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF7A8394),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _availableDevices = [
                    {'name': 'OBDII', 'address': '00:1D:A5:02:C4:91', 'type': 'ELM327 v1.5'},
                    {'name': 'v-link', 'address': '88:18:56:88:99:AA', 'type': 'Vgate iCar Pro'},
                  ];
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.ethanolNeon),
              label: const Text(
                'Buscar novamente',
                style: TextStyle(
                  color: AppColors.ethanolNeon,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
