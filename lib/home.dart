import 'package:flutter/material.dart';

import 'app_styles.dart';
import 'connect.dart';
import 'ethanol_gauge.dart';
import 'local.dart';
import 'obd_controller.dart';
import 'profile.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int currentPageIndex = 1; // Começa na aba "Veículo" conforme o design
  final ObdController _obd = ObdController.instance;

  String _classifyFuelMix(double ethanolPct) {
    if (ethanolPct <= 32.0) {
      return 'Predominante: Gasolina';
    } else if (ethanolPct < 75.0) {
      return 'Mistura Flex (Etanol + Gasolina)';
    } else {
      return 'Predominante: Etanol';
    }
  }

  void _openConnect() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Connect()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---------------- Logótipo DELTAMIX no Topo
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.green.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Textos separados nas pontas
                  const Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('DELTAMIX', style: AppTheme.logo),
                        Text('Usuario', style: AppTheme.logo),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ---------------- Conteúdo Principal com Gauge Chart
              Expanded(
                child: ListenableBuilder(
                  listenable: _obd,
                  builder: (context, _) {
                    final bool isConnected = _obd.isConnected;
                    final bool isLoading = _obd.isInitializing || _obd.isReading;
                    final double? ethanol = _obd.ethanolPercentage;
                    final double? gasoline =
                        ethanol != null ? (100.0 - ethanol).clamp(0.0, 100.0) : null;

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Badge de status da conexão Bluetooth OBD-II
                          GestureDetector(
                            onTap: _openConnect,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isConnected
                                      ? AppTheme.green.withValues(alpha: 0.35)
                                      : Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isConnected
                                        ? Icons.bluetooth_connected
                                        : Icons.bluetooth_disabled,
                                    size: 18,
                                    color: isConnected
                                        ? AppTheme.green
                                        : Colors.redAccent,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      isConnected
                                          ? 'Conectado a ${_obd.connectedName ?? "OBD-II"}'
                                          : 'OBD-II desconectado • Toque para conectar',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isConnected
                                            ? AppTheme.white
                                            : AppTheme.muted,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: AppTheme.muted,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Card Principal do Gauge Chart
                          Container(
                            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'MISTURA DE COMBUSTÍVEL',
                                  style: TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Gauge Chart (0 a 100%)
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 275,
                                    ),
                                    child: EthanolGaugeChart(
                                      percentage: ethanol,
                                      isLoading: isLoading,
                                    ),
                                  ),
                                ),

                                if (ethanol != null && gasoline != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.green.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _classifyFuelMix(ethanol),
                                      style: const TextStyle(
                                        color: AppTheme.green,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Resumo complementar Etanol vs Gasolina
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildMixStatTile(
                                          label: 'ETANOL',
                                          value: '${ethanol.toStringAsFixed(1)}%',
                                          accentColor: AppTheme.green,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildMixStatTile(
                                          label: 'GASOLINA',
                                          value: '${gasoline.toStringAsFixed(1)}%',
                                          accentColor: Colors.amber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else if (!isConnected) ...[
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Conecte ao scanner OBD-II na aba Veículo ou no botão abaixo para medir a porcentagem de etanol.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppTheme.muted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],

                                // Exibe aviso amigável se houver falha de comunicação com a ECU (ex: ignição desligada / NO DATA)
                                if (_obd.errorMessage != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.amber.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          color: Colors.amber,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _obd.errorMessage!,
                                            style: const TextStyle(
                                              color: Colors.amber,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Botão de ação rápida (Conectar ou Atualizar Leitura)
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isConnected
                                    ? AppTheme.surface
                                    : AppTheme.green,
                                foregroundColor: isConnected
                                    ? AppTheme.white
                                    : Colors.black,
                                side: isConnected
                                    ? BorderSide(
                                        color: AppTheme.green.withValues(alpha: 0.45),
                                      )
                                    : BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              onPressed: isConnected
                                  ? (isLoading ? null : _obd.refreshEthanol)
                                  : _openConnect,
                              icon: isConnected
                                  ? (isLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTheme.green,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.refresh,
                                          color: AppTheme.green,
                                          size: 19,
                                        ))
                                  : const Icon(Icons.bluetooth_searching, size: 19),
                              label: Text(
                                isConnected
                                    ? (_obd.isInitializing
                                        ? 'Inicializando ELM327...'
                                        : (_obd.isReading
                                            ? 'Atualizando leitura...'
                                            : 'Atualizar Leitura'))
                                    : 'Conectar Leitor OBD-II',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      // ---------------- Barra de Navegação Inferior Flutuante
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
        child: Container(
          height: 65,
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: AppTheme.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(icon: Icons.location_on, label: 'Postos', index: 0),
              _buildNavItem(
                icon: Icons.directions_car,
                label: 'Veículo',
                index: 1,
              ),
              _buildNavItem(icon: Icons.person, label: 'Perfil', index: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMixStatTile({
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para os itens da barra de navegação inferior flutuante
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = currentPageIndex == index;

    return GestureDetector(
      onTap: () {
        if (index == 0) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Local()),
          );
        } else if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Connect()),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Profile()),
          );
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? AppTheme.white : AppTheme.muted,
            size: 22,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.white : AppTheme.muted,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
