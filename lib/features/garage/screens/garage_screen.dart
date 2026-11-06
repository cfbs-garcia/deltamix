import 'package:flutter/material.dart';
import '../../../core/bluetooth/obd_controller.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../fuel_dashboard/screens/quick_diagnostic_screen.dart';
import '../../obd_connection/screens/add_vehicle_screen.dart';
import '../controllers/garage_controller.dart';

/// ============================================================================
/// 2. TELA PRINCIPAL (GARAGEM DE VEÍCULOS)
/// ============================================================================
///
/// Responsabilidades:
/// 1. Listar os carros cadastrados do motorista (com apelido opcional em destaque).
/// 2. Ao clicar em um carro, abrir o Diagnóstico Mínimo (QuickDiagnosticScreen).
/// 3. Permitir excluir perfis de veículos diretamente pelo card na Garagem.
/// 4. Botão para cadastrar novo veículo e parear com o scanner OBD-II.
class GarageScreen extends StatelessWidget {
  const GarageScreen({super.key});

  Future<void> _confirmDeleteVehicle(
    BuildContext context,
    VehicleModel vehicle,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          'Excluir veículo?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Deseja remover "${vehicle.displayName}" da sua garagem?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Excluir',
              style: TextStyle(
                color: AppColors.alertRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Se o veículo removido estiver conectado ao scanner, encerra a sessão OBD-II
    if (vehicle.isObdConnected && ObdController.instance.isConnected) {
      await ObdController.instance.disconnect();
    }

    GarageController.instance.removeVehicle(vehicle.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${vehicle.displayName} removido da garagem.'),
          backgroundColor: AppColors.surfaceCard,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final garage = GarageController.instance;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Garagem dos seus Veículos'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: garage,
          builder: (context, _) {
            final vehicles = garage.vehicles;

            if (vehicles.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.directions_car_outlined,
                      size: 64,
                      color: AppTheme.muted,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhum veículo cadastrado',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cadastre seu carro para monitorar a mistura Flex.',
                      style: TextStyle(fontSize: 13, color: AppTheme.muted),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddVehicleScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Cadastrar Carro'),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SEUS VEÍCULOS (${vehicles.length})',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Text(
                        'Toque para diagnosticar',
                        style: TextStyle(
                          color: AppTheme.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: vehicles.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final vehicle = vehicles[index];
                      return _buildVehicleCard(context, vehicle);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVehicleCard(BuildContext context, VehicleModel vehicle) {
    final bool isConnected = vehicle.isObdConnected;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      // Conforme o diagrama: Clica em um Carro -> Abre 3. Diagnóstico Mínimo
      onTap: () {
        GarageController.instance.selectVehicle(vehicle);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuickDiagnosticScreen(vehicle: vehicle),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isConnected
                ? AppColors.ethanolNeon.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
            width: isConnected ? 1.4 : 1.0,
          ),
          boxShadow: isConnected ? AppColors.ethanolNeonShadow : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceInput,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.directions_car_filled_rounded,
                          color: isConnected
                              ? AppColors.ethanolNeon
                              : AppColors.textMuted,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Apelido (se houver) ou Modelo do Carro
                            Text(
                              vehicle.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Subtítulo: Modelo e Placa
                            Text(
                              vehicle.displaySubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Excluir veículo',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppColors.alertRed,
                      ),
                      onPressed: () => _confirmDeleteVehicle(context, vehicle),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppTheme.muted,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      size: 15,
                      color: isConnected ? AppColors.obdCyan : AppTheme.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      vehicle.obdName ?? 'Nenhum leitor pareado',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isConnected ? AppColors.obdCyan : AppTheme.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  isConnected ? 'Pronto para Diagnóstico' : 'Toque para Conectar',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isConnected ? AppColors.ethanolNeon : AppTheme.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
