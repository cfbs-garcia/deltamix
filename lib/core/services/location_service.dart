import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// ============================================================================
/// SERVIÇO DE LOCALIZAÇÃO DO ABASTECIMENTO
/// ============================================================================
///
/// Obtém a localização atual do aparelho (via GPS nativo no Android com
/// geocodificação reversa ou fallback de rede) para preencher automaticamente
/// onde o motorista realizou o abastecimento.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const MethodChannel _channel = MethodChannel('deltamix/location');

  /// Solicita permissão de localização e retorna o endereço/local atual formatado.
  Future<String?> getCurrentLocationLabel() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.locationWhenInUse.request();
        if (!status.isGranted) {
          throw Exception('Permissão de localização negada no celular.');
        }

        final Map<dynamic, dynamic>? res =
            await _channel.invokeMapMethod('getCurrentLocation');
        if (res != null) {
          final String address = (res['address'] as String?)?.trim() ?? '';
          if (address.isNotEmpty) return address;

          final double? lat = (res['lat'] as num?)?.toDouble();
          final double? lon = (res['lon'] as num?)?.toDouble();
          if (lat != null && lon != null) {
            final reverse = await _reverseGeocodeOsm(lat, lon);
            if (reverse != null && reverse.isNotEmpty) return reverse;
            return 'GPS: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
          }
        }
      }

      // Fallback para Desktop / Emulador sem GPS: localização aproximada via rede
      return await _networkApproximateLocation();
    } on PlatformException catch (e) {
      // Caso o GPS do emulador não tenha sinal fixado, tenta localização de rede
      final fallback = await _networkApproximateLocation();
      if (fallback != null) return fallback;
      throw Exception(e.message ?? 'Não foi possível obter a localização.');
    }
  }

  Future<String?> _reverseGeocodeOsm(double lat, double lon) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&accept-language=pt-BR',
      );
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'DeltamixApp/1.0');
      final resp = await req.close();
      if (resp.statusCode != 200) return null;

      final body = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>?;
      if (addr == null) return null;

      final road = (addr['road'] ?? addr['pedestrian'] ?? '') as String;
      final suburb =
          (addr['suburb'] ?? addr['neighbourhood'] ?? addr['city_district'] ?? '')
              as String;
      final city =
          (addr['city'] ?? addr['town'] ?? addr['municipality'] ?? '') as String;

      final parts = <String>[
        if (road.isNotEmpty) road,
        if (suburb.isNotEmpty && suburb != road) suburb,
        if (city.isNotEmpty) city,
      ];
      return parts.isEmpty ? null : parts.join(' • ');
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  Future<String?> _networkApproximateLocation() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4);
    try {
      final uri = Uri.parse('http://ip-api.com/json/?fields=status,city,region');
      final req = await client.getUrl(uri);
      final resp = await req.close();
      if (resp.statusCode != 200) return null;

      final body = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (data['status'] == 'success') {
        final city = (data['city'] as String?) ?? '';
        final region = (data['region'] as String?) ?? '';
        if (city.isNotEmpty) {
          return region.isNotEmpty ? '$city - $region' : city;
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}
