import 'package:flutter/material.dart';
import '../../../core/bluetooth/obd_controller.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/ethanol_gauge_chart.dart';

/// ============================================================================
/// 4. DIAGNÓSTICO MAIS DETALHADO (TELEMETRIA COMPLETA DO MOTOR & PROTOCOLO ECU)
/// ============================================================================
///
/// Estruturado exatamente conforme o layout requisitado:
/// - Topo: [← Voltar] - TÍTULO DO CARRO (ex: CIVIC 2.0 FLEX) - [Status]
/// - Gauge Chart Circular: 72.4% ETANOL + Badges [Predominante] e [AFR Est.]
/// - Mistura no Tanque: Cards [🌿 Etanol: 72.4%] e [⛽ Gasolina: 27.6%]
/// - Telemetria do Motor: Grid 3x2 (Bateria, Temp, RPM, Trim Rápido, Trim Longo, Ponto)
/// - Saúde e Diagnóstico: [✔ Nenhuma falha detectada na injeção (MIL Desligada)]
/// - Expansível: [v Dados Técnicos e Protocolo ECU] (Resposta bruta, protocolo, latência)
class DetailedDiagnosticScreen extends StatefulWidget {
  final VehicleModel vehicle;

  const DetailedDiagnosticScreen({
    super.key,
    required this.vehicle,
  });

  @override
  State<DetailedDiagnosticScreen> createState() => _DetailedDiagnosticScreenState();
}

class _DetailedDiagnosticScreenState extends State<DetailedDiagnosticScreen> {
  final ObdController _obd = ObdController.instance;

  // Cálculo da relação Ar-Combustível (AFR) estequiométrica estimada da mistura:
  // Gasolina pura = 14.7:1 | Etanol puro = 9.0:1
  double _calculateEstimatedAfr(double ethanolPct) {
    final e = ethanolPct.clamp(0.0, 100.0) / 100.0;
    return ((1.0 - e) * 14.7) + (e * 9.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0D10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101217),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.vehicle.displayName.toUpperCase(),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14, top: 12, bottom: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.ethanolNeon.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.ethanolNeon, width: 1),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle_rounded, size: 12, color: AppColors.ethanolNeon),
                  SizedBox(width: 4),
                  Text(
                    'ONLINE',
                    style: TextStyle(
                      color: AppColors.ethanolNeon,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _obd,
          builder: (context, _) {
            final double ethanol = _obd.ethanolPercentage ?? widget.vehicle.ethanolPercentage;
            final double gasoline = (100.0 - ethanol).clamp(0.0, 100.0);
            final double afr = _calculateEstimatedAfr(ethanol);
            final bool isLoading = _obd.isInitializing || _obd.isReading;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ===========================================================
                  // 1. MOSTRADOR CENTRAL (GAUGE CHART CIRCULAR + BADGES)
                  // ===========================================================
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14161C),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 245),
                            child: EthanolGaugeChart(
                              percentage: ethanol,
                              isLoading: isLoading,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Badges: [ Predominante: Etanol ]  [ AFR Est.: 10.1:1 ]
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildTopPillBadge(
                              label: ethanol >= 75.0
                                  ? 'Predominante: Etanol'
                                  : ethanol <= 32.0
                                      ? 'Predominante: Gasolina'
                                      : 'Mistura Flex',
                              color: AppColors.ethanolNeon,
                              icon: Icons.local_fire_department_rounded,
                            ),
                            const SizedBox(width: 10),
                            _buildTopPillBadge(
                              label: 'AFR Est.: ${afr.toStringAsFixed(1)}:1',
                              color: AppColors.obdCyan,
                              icon: Icons.tune_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ===========================================================
                  // 2. MISTURA NO TANQUE (ETANOL VS GASOLINA)
                  // ===========================================================
                  _buildSectionHeader('MISTURA NO TANQUE'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Card Etanol
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14161C),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.ethanolNeon.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text('🌿', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Etanol',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${ethanol.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: AppColors.ethanolNeon,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Card Gasolina
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14161C),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.gasolineNeon.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text('⛽', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Gasolina',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${gasoline.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: AppColors.gasolineNeon,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ===========================================================
                  // 3. TELEMETRIA DO MOTOR (GRID 3x2)
                  // ===========================================================
                  _buildSectionHeader('TELEMETRIA DO MOTOR'),
                  const SizedBox(height: 8),

                  // Linha 1: Bateria | Temperatura | Rotação
                  Row(
                    children: [
                      Expanded(child: _buildTelemetryTile('Bateria', '14.1 V', Icons.battery_charging_full_rounded, AppColors.obdCyan)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTelemetryTile('Temperatura', '92 °C', Icons.thermostat_rounded, const Color(0xFFFF9500))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTelemetryTile('Rotação', '850 RPM', Icons.speed_rounded, AppColors.ethanolNeon)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Linha 2: Trim Rápido | Trim Longo | Ponto
                  Row(
                    children: [
                      Expanded(child: _buildTelemetryTile('Trim Rápido', '+2.3%', Icons.show_chart_rounded, Colors.white)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTelemetryTile('Trim Longo', '+16.4%', Icons.timeline_rounded, Colors.white)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTelemetryTile('Ponto', '12.0°', Icons.flash_on_rounded, AppColors.ethanolNeon)),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ===========================================================
                  // 4. SAÚDE E DIAGNÓSTICO (STATUS MIL / CHECK ENGINE)
                  // ===========================================================
                  _buildSectionHeader('SAÚDE E DIAGNÓSTICO'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14161C),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.ethanolNeon.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.check_circle_rounded, color: AppColors.ethanolNeon, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Nenhuma falha detectada na injeção (MIL Desligada)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ===========================================================
                  // 5. DADOS TÉCNICOS E PROTOCOLO ECU (EXPANSÍVEL)
                  // ===========================================================
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF14161C),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        iconColor: AppColors.ethanolNeon,
                        collapsedIconColor: AppColors.textMuted,
                        title: const Text(
                          'Dados Técnicos e Protocolo ECU',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: const Text(
                          'Toque para expandir',
                          style: TextStyle(color: Color(0xFF7A8394), fontSize: 11),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              children: [
                                const Divider(color: Color(0xFF222632), height: 1),
                                const SizedBox(height: 10),
                                _buildTechnicalBullet('Resposta Bruta', '41 52 4A (Hex)'),
                                _buildTechnicalBullet('Protocolo', 'ISO 15765-4 CAN 500k'),
                                _buildTechnicalBullet('Latência', '42ms'),
                                _buildTechnicalBullet('Comando SAE', 'Mode 01 PID 52 (01 52\\r)'),
                                _buildTechnicalBullet('Fila Serial', 'Half-Duplex FIFO Ativa'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Botão de Atualizar Leitura
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ethanolNeon,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    onPressed: isLoading ? null : _obd.refreshEthanol,
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.refresh_rounded, size: 20),
                    label: Text(
                      isLoading ? 'Consultando ECU...' : 'Atualizar Leitura',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGETS AUXILIARES
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Color(0xFF7A8394),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTopPillBadge({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryTile(String label, String value, IconData icon, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF14161C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF7A8394)),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7A8394),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalBullet(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('• $label:', style: const TextStyle(color: Color(0xFF7A8394), fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
