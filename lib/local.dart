import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'app_styles.dart';

class Local extends StatefulWidget {
  const Local({super.key});

  @override
  State<Local> createState() => _LocalState();
}

class _LocalState extends State<Local> {
  GoogleMapController? _mapController;

  // Localização inicial padrão (São Paulo como fallback enquanto o GPS calibra)
  LatLng _currentPosition = const LatLng(-23.550520, -46.633308);

  // Controla se ainda estamos obtendo o GPS em segundo plano (sem travar a tela)
  bool _isLocating = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Inicia a busca do GPS em segundo plano
    _fetchUserLocation();
  }

  /// Busca a posição do usuário de forma rápida e segura sem travar o mapa
  Future<void> _fetchUserLocation() async {
    try {
      // 1. Verifica se o GPS do celular está ligado
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _errorMessage = 'Ative o GPS do celular para ver sua posição.';
          });
        }
        return;
      }

      // 2. Checa e pede permissões de localização
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _isLocating = false;
              _errorMessage = 'Permissão de localização negada.';
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLocating = false;
            _errorMessage = 'Permissão de GPS bloqueada nas configurações.';
          });
        }
        return;
      }

      // 3. Pega a última posição conhecida em cache do Android (resposta instantânea em < 100ms)
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        _animateCameraTo(LatLng(lastKnown.latitude, lastKnown.longitude));
      }

      // 4. Busca a posição atual com timeout de 5s para NUNCA travar a tela infinitamente
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );

      if (mounted) {
        _animateCameraTo(LatLng(position.latitude, position.longitude));
        setState(() => _isLocating = false);
      }
    } catch (e) {
      // Se der timeout ou erro de satélite, não travamos o app: o mapa continua interativo
      debugPrint('[Maps] GPS demorou ou falhou: $e');
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  /// Move a visualização do mapa suavemente para as coordenadas
  void _animateCameraTo(LatLng target) {
    setState(() => _currentPosition = target);
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 15.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Postos Próximos',
          style: TextStyle(color: AppTheme.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      // O mapa agora carrega IMEDIATAMENTE, sem bloquear a tela toda com CircularProgressIndicator
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 15.0,
            ),
            myLocationEnabled: true,       // Pontinho azul do motorista
            myLocationButtonEnabled: true, // Botão de centralizar na localização
            zoomControlsEnabled: false,    // Visual mais limpo estilo moderno
            onMapCreated: (controller) {
              _mapController = controller;
              // Centraliza na posição inicial caso já tenhamos obtido antes do mapa renderizar
              controller.animateCamera(CameraUpdate.newLatLng(_currentPosition));
            },
          ),

          // Indicador discreto no topo enquanto o GPS calibra
          if (_isLocating)
            Positioned(
              top: 12,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(color: AppTheme.green, strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Localizando você...',
                        style: TextStyle(color: AppTheme.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Aviso se o GPS estiver desativado no aparelho
          if (_errorMessage != null)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber),
                ),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.amber, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
