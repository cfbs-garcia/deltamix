import 'package:flutter/material.dart';
import '../../../core/bluetooth/obd_controller.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../obd_connection/screens/connect_screen.dart';
import '../widgets/ethanol_gauge_chart.dart';

/// ============================================================================
/// 4. DIAGNÓSTICO MAIS DETALHADO (TELEMETRIA DO MOTOR & PROTOCOLO ECU)
/// ============================================================================
///
/// Estruturado conforme a arquitetura modular do projeto e conectado aos PIDs
/// reais da ECU via Bluetooth OBD-II:
/// - Topo: [← Voltar] - TÍTULO DO CARRO - Badge dinâmico [ONLINE / OFFLINE]
/// - Gauge Chart Circular com cor dinâmica por nível + Badges [Predominante] e [AFR Est.]
/// - Mistura no Tanque: Cards [🌿 Etanol] e [⛽ Gasolina]
/// - Telemetria do Motor (Indicadores pertinentes via OBD-II Mode 01):
///     1. Rotação do Motor (RPM) — PID 01 0C
///     2. STFT (Short Term Fuel Trim / Ajuste de Combustível a Curto Prazo) — PID 01 06
///     3. LTFT (Long Term Fuel Trim / Ajuste de Combustível a Longo Prazo) — PID 01 07
/// - Saúde e Diagnóstico da Injeção
/// - Expansível: [Dados Técnicos e Protocolo ECU] com resposta hexadecimal bruta e latência real
class DetailedDiagnosticScreen extends StatefulWidget {
  final VehicleModel vehicle;

  const DetailedDiagnosticScreen({
    super.key,
    required this.vehicle,
  });

  @override
  State<DetailedDiagnosticScreen> createState() =>
      _DetailedDiagnosticScreenState();
}

class _DetailedDiagnosticScreenState extends State<DetailedDiagnosticScreen> {
  final ObdController _obd = ObdController.instance;

  /// Formata os valores de Fuel Trim (STFT / LTFT) exibindo sinal explícito (+ ou -).
  String _formatFuelTrim(double? trim) {
    if (trim == null) return '-- %';
    final sign = trim > 0 ? '+' : '';
    return '$sign${trim.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _obd,
      builder: (context, _) {
        final bool isConnected = _obd.isConnected;
        final double ethanol =
            _obd.ethanolPercentage ?? widget.vehicle.ethanolPercentage;
        final double gasoline = (100.0 - ethanol).clamp(0.0, 100.0);
        final bool isLoading = _obd.isInitializing || _obd.isReading;

        // Formatação dos 3 indicadores pertinentes de telemetria do motor
        final String rpmValue =
            _obd.engineRpm != null ? '${_obd.engineRpm} RPM' : '-- RPM';
        final String stftValue = _formatFuelTrim(_obd.shortTermFuelTrim);
        final String ltftValue = _formatFuelTrim(_obd.longTermFuelTrim);

        return Scaffold(
          backgroundColor: const Color(0xFF0C0D10),
          appBar: AppBar(
            backgroundColor: const Color(0xFF101217),
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
              // Badge interativo de status da conexão Bluetooth OBD-II
              Padding(
                padding: const EdgeInsets.only(right: 14, top: 12, bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: isConnected
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ConnectScreen(),
                            ),
                          );
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isConnected
                          ? AppColors.ethanolNeon.withValues(alpha: 0.12)
                          : AppColors.dangerNeon.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isConnected
                            ? AppColors.ethanolNeon
                            : AppColors.dangerNeon,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isConnected
                              ? Icons.check_circle_rounded
                              : Icons.bluetooth_disabled_rounded,
                          size: 12,
                          color: isConnected
                              ? AppColors.ethanolNeon
                              : AppColors.dangerNeon,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isConnected ? 'ONLINE' : 'OFFLINE',
                          style: TextStyle(
                            color: isConnected
                                ? AppColors.ethanolNeon
                                : AppColors.dangerNeon,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner de aviso caso haja mensagem de erro da ECU/Bluetooth
                  if (_obd.errorMessage != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.dangerNeon.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.dangerNeon.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.dangerNeon,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _obd.errorMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ===========================================================
                  // 1. MOSTRADOR CENTRAL (GAUGE CHART CIRCULAR + BADGES)
                  // ===========================================================
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14161C),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
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

                        // Badge: [ Predominante ]
                        Center(
                          child: _buildTopPillBadge(
                            label: ethanol >= 75.0
                                ? 'Predominante: Etanol'
                                : ethanol <= 32.0
                                    ? 'Predominante: Gasolina'
                                    : 'Mistura Flex',
                            color: EthanolGaugeChart.colorForLevel(ethanol),
                            icon: Icons.local_fire_department_rounded,
                          ),
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
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14161C),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.ethanolNeon.withValues(
                                alpha: 0.35,
                              ),
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
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14161C),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.gasolineNeon.withValues(
                                alpha: 0.35,
                              ),
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
                  // 3. TELEMETRIA DO MOTOR (RPM, STFT E LTFT)
                  // ===========================================================
                  // Mantém os 3 indicadores pertinentes da injeção eletrônica:
                  // - Rotação do Motor (RPM) [PID 01 0C]
                  // - Short Term Fuel Trim (STFT) - Ajuste a Curto Prazo [PID 01 06]
                  // - Long Term Fuel Trim (LTFT) - Ajuste a Longo Prazo [PID 01 07]
                  _buildSectionHeader('TELEMETRIA DO MOTOR'),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTelemetryTile(
                          label: 'Rotação (RPM)',
                          subtitle: 'Velocidade do Motor',
                          value: rpmValue,
                          icon: Icons.speed_rounded,
                          valueColor: AppColors.ethanolNeon,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTelemetryTile(
                          label: 'STFT (Trim Rápido)',
                          subtitle: 'Ajuste Curto Prazo',
                          value: stftValue,
                          icon: Icons.show_chart_rounded,
                          valueColor: AppColors.obdCyan,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTelemetryTile(
                          label: 'LTFT (Trim Longo)',
                          subtitle: 'Ajuste Longo Prazo',
                          value: ltftValue,
                          icon: Icons.timeline_rounded,
                          valueColor: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ===========================================================
                  // 4. SAÚDE E DIAGNÓSTICO (STATUS MIL / CHECK ENGINE)
                  // ===========================================================
                  _buildSectionHeader('SAÚDE E DIAGNÓSTICO'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14161C),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.ethanolNeon.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.ethanolNeon,
                          size: 20,
                        ),
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
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
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
                          style: TextStyle(
                            color: Color(0xFF7A8394),
                            fontSize: 11,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              children: [
                                const Divider(
                                  color: Color(0xFF222632),
                                  height: 1,
                                ),
                                const SizedBox(height: 10),
                                _buildTechnicalBullet(
                                  'Resposta Bruta (01 52)',
                                  _obd.lastRawResponse?.isNotEmpty == true
                                      ? _obd.lastRawResponse!
                                      : 'Aguardando leitura...',
                                ),
                                _buildTechnicalBullet(
                                  'Scanner Conectado',
                                  _obd.connectedName ?? 'Não conectado',
                                ),
                                _buildTechnicalBullet(
                                  'Latência da ECU',
                                  _obd.lastLatencyMs != null
                                      ? '${_obd.lastLatencyMs} ms'
                                      : '-- ms',
                                ),
                                _buildTechnicalBullet(
                                  'PIDs Monitorados',
                                  '01 52 (Etanol), 01 0C (RPM), 01 06 (STFT), 01 07 (LTFT)',
                                ),
                                _buildTechnicalBullet(
                                  'Fila Serial',
                                  'Half-Duplex FIFO Ativa',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Botão de Atualizar Leitura (ou Conectar se estiver offline)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ethanolNeon,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    onPressed: isLoading
                        ? null
                        : () {
                            if (isConnected) {
                              _obd.refreshEthanol();
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ConnectScreen(),
                                ),
                              );
                            }
                          },
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Icon(
                            isConnected
                                ? Icons.refresh_rounded
                                : Icons.bluetooth_searching_rounded,
                            size: 20,
                          ),
                    label: Text(
                      isLoading
                          ? 'Consultando ECU...'
                          : isConnected
                              ? 'Atualizar Leitura'
                              : 'Conectar Scanner OBD-II',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
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

  /// Card de indicador da Telemetria do Motor (RPM, STFT e LTFT)
  Widget _buildTelemetryTile({
    required String label,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
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
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF7A8394),
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
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
          Text(
            '• $label:',
            style: const TextStyle(color: Color(0xFF7A8394), fontSize: 12),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
