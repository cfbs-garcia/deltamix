import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../features/garage/screens/garage_screen.dart';
import '../features/gas_stations/screens/local_screen.dart';
import '../features/obd_connection/screens/add_vehicle_screen.dart';
import '../features/profile/screens/profile_screen.dart';

/// ============================================================================
/// 2. TELA PRINCIPAL (GARAGEM DE VEÍCULOS) COM BARRA INFERIOR (3 OPÇÕES)
/// ============================================================================
///
/// Conforme o diagrama da aplicação:
/// - Tela Principal: Garagem de Veículos
/// - Barra Inferior (3 Opções):
///   - Esquerda: Postos Próximos (Mapa)
///   - Centro (+): Cadastrar Veículo (Busca Bluetooth OBD)
///   - Direita: Perfil do Usuário
class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      // O corpo principal é a Garagem de Veículos
      body: const GarageScreen(),

      // Barra inferior com as 3 opções do diagrama
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // -------------------------------------------------------------
                // 1. ESQUERDA: POSTOS PRÓXIMOS (MAPA)
                // -------------------------------------------------------------
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LocalScreen()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.location_on_outlined, color: AppTheme.white, size: 24),
                          SizedBox(height: 4),
                          Text(
                            'Postos',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // -------------------------------------------------------------
                // 2. CENTRO (+): CADASTRAR VEÍCULO (BUSCA BLUETOOTH OBD)
                // -------------------------------------------------------------
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddVehicleScreen()),
                    );
                  },
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppTheme.green,
                      shape: BoxShape.circle,
                      boxShadow: AppColors.ethanolNeonShadow,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 32,
                      color: Colors.black,
                    ),
                  ),
                ),

                // -------------------------------------------------------------
                // 3. DIREITA: PERFIL DO USUÁRIO
                // -------------------------------------------------------------
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfileScreen()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.person_outline_rounded, color: AppTheme.white, size: 24),
                          SizedBox(height: 4),
                          Text(
                            'Perfil',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
