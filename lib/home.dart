import 'package:flutter/material.dart';
import 'app_styles.dart';
import 'connect.dart';
import 'profile.dart';
import 'local.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int currentPageIndex = 1; // Começa na aba "Veículo" conforme o design

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                          color: AppTheme.green.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'DELTAMIX',
                    style: AppTheme.logo,
                  ),
                ],
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
            border: Border.all(color: AppTheme.white.withOpacity(0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(icon: Icons.location_on, label: 'Postos', index: 0),
              _buildNavItem(icon: Icons.directions_car, label: 'Veículo', index: 1),
              _buildNavItem(icon: Icons.person, label: 'Perfil', index: 2),
            ],
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para os itens da barra de navegação inferior flutuante
  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final isSelected = currentPageIndex == index;

    return GestureDetector(
      onTap: () {
        if (index == 0) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Local()),
          );
        } 
        else if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Connect()),
          );
        }
        else {
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