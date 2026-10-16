import 'package:flutter/material.dart';

import 'app_styles.dart';
import 'device_card.dart'; // Importa o nosso novo componente separado

class Connect extends StatefulWidget {
  const Connect({super.key});

  @override
  State<Connect> createState() => _ConnectState();
}

class _ConnectState extends State<Connect> {
  bool isSearching = true;
  bool isConnected = false;
  String? selectedDeviceName;
  List<Map<String, String>> devices = [];

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  void _startScanning() {
    setState(() {
      isSearching = true;
      selectedDeviceName = null;
      devices = [];
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          isSearching = false;
          devices = [
            {'name': 'OBDII', 'sub': 'ELM327 v1.5'},
            {'name': 'OBD327-BT', 'sub': 'ELM327 v2.1'},
            {'name': 'HC-05', 'sub': 'Módulo genérico'},
          ];
        });
      }
    });
  }

  void _connectDevice() {
    if (selectedDeviceName == null) return;

    setState(() {
      isConnected = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Conectado a $selectedDeviceName!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canConnect = selectedDeviceName != null && !isConnected;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppTheme.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'DELTAMIX',
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (isConnected ? AppTheme.green : Colors.red)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isConnected ? 'CONECTADO' : 'DESCONECTADO',
                      style: TextStyle(
                        color: isConnected ? AppTheme.green : Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Card de Status / Radar
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.bluetooth,
                      color: isSearching
                          ? Colors.amber
                          : (isConnected ? AppTheme.green : Colors.red),
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isSearching
                          ? 'A procurar dispositivos...'
                          : (isConnected
                                ? 'Conectado a $selectedDeviceName'
                                : 'Desconectado'),
                      style: const TextStyle(
                        color: AppTheme.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Título da Lista
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'DISPOSITIVOS BLUETOOTH',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!isSearching)
                    TextButton.icon(
                      onPressed: _startScanning,
                      icon: const Icon(
                        Icons.refresh,
                        size: 14,
                        color: AppTheme.green,
                      ),
                      label: const Text(
                        'Atualizar',
                        style: TextStyle(color: AppTheme.green, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Lista de Dispositivos
              Expanded(
                child: isSearching
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.amber),
                      )
                    : devices.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum dispositivo encontrado',
                          style: TextStyle(color: AppTheme.muted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final dev = devices[index];
                          final name = dev['name']!;
                          return DeviceCard(
                            title: name,
                            subtitle: dev['sub']!,
                            isSelected: selectedDeviceName == name,
                            onTap: () =>
                                setState(() => selectedDeviceName = name),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),

              // Botão Conectar
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canConnect
                        ? AppTheme.green
                        : AppTheme.green.withOpacity(0.3),
                    foregroundColor: canConnect ? Colors.black : AppTheme.muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: canConnect ? _connectDevice : null,
                  child: Text(
                    isConnected ? 'Conectado' : 'Conectar',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
