import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../gas_stations/screens/local_screen.dart';
import '../../profile/screens/profile_screen.dart';

/// ============================================================================
/// TELA HOME / PRINCIPAL (LIMPA COM A BARRA DE NAVEGAÇÃO DO APLICATIVO)
/// ============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Começa na aba central (Home / Veículo)
  int _currentIndex = 1;

  // As 3 abas do aplicativo
  final List<Widget> _screens = const [
    LocalScreen(),      // Aba 0: Esquerda (Postos / Mapa)
    CleanHomeView(),    // Aba 1: Centro (Tela Home Limpa)
    ProfileScreen(),    // Aba 2: Direita (Perfil)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      // Barra de navegação padrão do próprio aplicativo (BottomNavigationBar)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on_outlined),
            activeIcon: Icon(Icons.location_on_rounded),
            label: 'Postos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined),
            activeIcon: Icon(Icons.directions_car_rounded),
            label: 'Veículo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

/// Visualização central limpa da Home (sem sobrecarga de componentes)
class CleanHomeView extends StatelessWidget {
  const CleanHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('DELTAMIX'),
        centerTitle: true,
      ),
      body: const SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions_car_filled_rounded,
                size: 64,
                color: AppColors.ethanolNeon,
              ),
              SizedBox(height: 16),
              Text(
                'Tela Principal',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
