import 'package:flutter/material.dart';
import '../../../core/bluetooth/obd_controller.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../obd_connection/screens/connect_screen.dart';
import '../widgets/ethanol_gauge_chart.dart';
import 'detailed_diagnostic_screen.dart';

/// ============================================================================
/// 3. DIAGNÓSTICO MÍNIMO (DASHBOARD SIMPLES COM GRÁFICO PADRÃO)
/// ============================================================================
///
/// Exibe de forma limpa e direta:
/// - Mostrador circular padrão da telemetria com cor dinâmica por nível.
/// - Percentual essencial de Etanol vs Gasolina atualizado em tempo real via OBD-II.
/// - Botão 'Mais Detalhado' para abrir a telemetria avançada do motor e ECU.
class QuickDiagnosticScreen extends StatelessWidget {
  final VehicleModel vehicle;

  const QuickDiagnosticScreen({
    super.key,
    required this.vehicle,
  });

  /// Retorna o rótulo da mistura predominante com base no percentual de etanol.
  String _getPredominanceLabel(double ethanol) {
    if (ethanol <= 32.0) {
      return 'Predominante: Gasolina (E27)';
    } else if (ethanol < 75.0) {
      return 'Mistura Flex Balanceada';
    } else {
      return 'Predominante: Etanol Flex';
    }
  }

  /// Retorna a cor de destaque usando a mesma escala cromática do Gauge Chart.
  Color _getPredominanceColor(double ethanol) {
    return EthanolGaugeChart.colorForLevel(ethanol);
  }

  @override
  Widget build(BuildContext context) {
    final obd = ObdController.instance;

    return ListenableBuilder(
      listenable: obd,
      builder: (context, _) {
        // Prioriza a leitura real da ECU caso o scanner esteja conectado
        final double ethanol =
            obd.ethanolPercentage ?? vehicle.ethanolPercentage;
        final double gasoline = (100.0 - ethanol).clamp(0.0, 100.0);
        final Color accentColor = _getPredominanceColor(ethanol);
        final bool isLoading = obd.isInitializing || obd.isReading;

        return Scaffold(
          backgroundColor: const Color(0xFF0C0D10),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              children: [
                Text(
                  vehicle.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.white,
                  ),
                ),
                Text(
                  obd.isConnected
                      ? 'Conectado: ${obd.connectedName ?? "OBD-II"}'
                      : vehicle.displaySubtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: obd.isConnected
                        ? AppColors.ethanolNeon
                        : AppTheme.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              // Atalho rápido no topo para parear/reconectar Bluetooth ou atualizar leitura
              IconButton(
                tooltip: obd.isConnected
                    ? 'Atualizar leitura da ECU'
                    : 'Conectar leitor OBD-II',
                icon: Icon(
                  obd.isConnected
                      ? Icons.bluetooth_connected_rounded
                      : Icons.bluetooth_searching_rounded,
                  color: obd.isConnected
                      ? AppColors.ethanolNeon
                      : AppTheme.muted,
                  size: 20,
                ),
                onPressed: () {
                  if (obd.isConnected) {
                    obd.refreshEthanol();
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ConnectScreen(),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // -----------------------------------------------------------
                  // PILL SUPERIOR: PREDOMINÂNCIA DA MISTURA
                  // -----------------------------------------------------------
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ethanol >= 50
                              ? Icons.eco_rounded
                              : Icons.local_gas_station_rounded,
                          color: accentColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getPredominanceLabel(ethanol),
                          style: const TextStyle(
                            color: AppTheme.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // -----------------------------------------------------------
                  // MOSTRADOR CIRCULAR PADRÃO (GAUGE CHART COM COR DINÂMICA)
                  // -----------------------------------------------------------
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 270),
                      child: EthanolGaugeChart(
                        percentage: ethanol,
                        isLoading: isLoading,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // -----------------------------------------------------------
                  // SEÇÃO INFERIOR: CARDS DE ETANOL & GASOLINA
                  // -----------------------------------------------------------
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14161C),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Coluna Etanol
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'ETANOL',
                                style: TextStyle(
                                  color: AppColors.ethanolNeon,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${ethanol.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Biocombustível',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.muted,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Divisor Vertical
                        Container(
                          height: 44,
                          width: 1,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),

                        // Coluna Gasolina
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'GASOLINA',
                                style: TextStyle(
                                  color: AppColors.gasolineNeon,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${gasoline.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Fração Fóssil E27',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // -----------------------------------------------------------
                  // BOTÃO 'MAIS DETALHADO' (TELEMETRIA DO MOTOR & ECU)
                  // -----------------------------------------------------------
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ethanolNeon,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27),
                      ),
                      elevation: 6,
                      shadowColor: AppColors.ethanolGlow,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              DetailedDiagnosticScreen(vehicle: vehicle),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.analytics_rounded,
                      size: 20,
                      color: Colors.black,
                    ),
                    label: const Text(
                      'Mais Detalhado',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
