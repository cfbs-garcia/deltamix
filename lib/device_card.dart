import 'package:flutter/material.dart';

import 'app_styles.dart';

/// Card visual customizado para listar os dispositivos Bluetooth pareados
class DeviceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Verifica se pelo nome parece ser um adaptador OBD/ELM
    final nameLower = title.toLowerCase();
    final isObd = nameLower.contains('obd') ||
        nameLower.contains('elm') ||
        nameLower.contains('vgate') ||
        nameLower.contains('scan');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.green : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Ícone do dispositivo (destaca se for OBD veicular)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isObd ? Icons.directions_car : Icons.memory,
                color: isSelected ? AppTheme.green : AppTheme.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Informações do Dispositivo (Nome e MAC)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected ? AppTheme.green : AppTheme.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isObd) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'OBD-II',
                            style: TextStyle(
                              color: AppTheme.green,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Indicador de seleção
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.green, size: 20)
            else
              const Icon(Icons.chevron_right, color: AppTheme.muted, size: 20),
          ],
        ),
      ),
    );
  }
}
