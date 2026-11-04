import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// ============================================================================
/// ESQUELETO: TELA DE LOCALIZAÇÃO DE POSTOS (APENAS O MAPA)
/// ============================================================================
///
/// Responsabilidade atual:
/// - Exibir unicamente a área do mapa em tela cheia (Google Maps).
/// - Sem carrosséis, sem filtros de busca ou elementos secundários adicionais.
class LocalScreen extends StatefulWidget {
  const LocalScreen({super.key});

  @override
  State<LocalScreen> createState() => _LocalScreenState();
}

class _LocalScreenState extends State<LocalScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // -------------------------------------------------------------------
          // ÁREA DO MAPA EM TELA CHEIA (PLACEHOLDER PARA GOOGLE_MAPS_FLUTTER)
          // -------------------------------------------------------------------
          // Aqui será renderizado o widget oficial:
          // GoogleMap(
          //   initialCameraPosition: CameraPosition(target: LatLng(-23.5505, -46.6333), zoom: 14),
          //   myLocationEnabled: true,
          //   myLocationButtonEnabled: false,
          //   onMapCreated: (controller) => _mapController = controller,
          // )
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF13151B), // Tom escuro simulando o mapa noturno
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceCard,
                      border: Border.all(
                        color: AppColors.obdCyan.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: AppColors.obdNeonShadow,
                    ),
                    child: const Icon(
                      Icons.map_rounded,
                      size: 38,
                      color: AppColors.obdCyan,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Visualização do Mapa',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Área reservada exclusivamente para o GoogleMap em tela cheia.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botão flutuante para voltar à Garagem
          Positioned(
            top: 12,
            left: 16,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
