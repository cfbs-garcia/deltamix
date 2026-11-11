import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Resultado da busca de localização do abastecimento.
class LocationResult {
  final String? label;
  final bool permissionDenied;
  final bool permanentlyDenied;
  final String? warningMessage;

  const LocationResult({
    this.label,
    this.permissionDenied = false,
    this.permanentlyDenied = false,
    this.warningMessage,
  });
}

/// ============================================================================
/// SERVIÇO DE LOCALIZAÇÃO DO ABASTECIMENTO
/// ============================================================================
///
/// Obtém a localização exata do aparelho (via GPS nativo no Android com
/// geocodificação reversa de alta precisão + OpenStreetMap zoom 18) para
/// preencher Rua, Nº, Bairro e Cidade de onde o motorista abasteceu.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const MethodChannel _channel = MethodChannel('deltamix/location');

  /// Solicita permissão de localização e retorna o endereço atual (Rua, Nº, Bairro e Cidade).
  Future<LocationResult> fetchCurrentLocation() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        // Solicita via permission_handler e também valida/solicita nativamente no MainActivity
        PermissionStatus status = await Permission.locationWhenInUse.status;
        if (!status.isGranted) {
          status = await Permission.locationWhenInUse.request();
        }

        final Map<dynamic, dynamic>? res =
            await _channel.invokeMapMethod('getCurrentLocation');

        if (res != null) {
          final String nativeAddress =
              (res['address'] as String?)?.trim() ?? '';
          final double? lat = (res['lat'] as num?)?.toDouble();
          final double? lon = (res['lon'] as num?)?.toDouble();

          if (lat != null && lon != null) {
            if (_isCompleteStreetAddress(nativeAddress) &&
                _hasHouseNumber(nativeAddress)) {
              return LocationResult(label: nativeAddress);
            }

            final String? osmAddress = await _reverseGeocodeOsm(lat, lon);
            final String best = _pickBestAddress(nativeAddress, osmAddress);
            if (best.isNotEmpty) {
              return LocationResult(label: best);
            }

            return LocationResult(
              label:
                  'GPS: ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
            );
          }

          if (nativeAddress.isNotEmpty) {
            return LocationResult(label: nativeAddress);
          }
        }
      } on PlatformException catch (e) {
        debugPrint('[LocationService] PlatformException no GPS: $e');
        final msg = (e.message ?? '').toLowerCase();
        if (e.code == 'PERMISSION_DENIED' ||
            msg.contains('permission') ||
            msg.contains('security')) {
          return const LocationResult(
            permissionDenied: true,
            permanentlyDenied: true,
            warningMessage:
                'Permissão de Localização não concedida no Android. Dê um Stop ⏹️ e Run ▶️ no app para o Android registrar a permissão de GPS no manifesto e toque em "Abrir Configurações".',
          );
        }
        if (e.code == 'DISABLED') {
          return const LocationResult(
            warningMessage:
                'O GPS do celular está desativado. Ative a Localização na barra superior do Android e tente novamente.',
          );
        }
        return LocationResult(
          warningMessage:
              'Não foi possível obter o sinal de GPS (${e.message ?? e.code}). Verifique se o GPS está ativo.',
        );
      } catch (e) {
        debugPrint('[LocationService] Aviso no canal nativo GPS: $e');
      }

      return const LocationResult(
        permissionDenied: true,
        permanentlyDenied: true,
        warningMessage:
            'Para puxar Rua, Nº e Bairro via GPS, pare o app (Stop ⏹️) e inicie novamente (Run ▶️) para aplicar a nova permissão de Localização no Android.',
      );
    }

    // Fallback apenas para testes em Desktop (Windows/macOS/Linux)
    final approx = await _networkApproximateLocationHttps();
    if (approx != null && approx.isNotEmpty) {
      return LocationResult(label: approx);
    }

    return const LocationResult(
      warningMessage:
          'Não foi possível obter a localização automaticamente. Digite o posto/local abaixo.',
    );
  }

  /// Verifica se o endereço já possui formato detalhado de rua + bairro + cidade
  /// (e não apenas "Região Metropolitana de ...").
  bool _isCompleteStreetAddress(String addr) {
    final trimmed = addr.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.toLowerCase().startsWith('região')) return false;
    return trimmed.contains(' - ') && trimmed.contains(',');
  }

  bool _hasHouseNumber(String addr) {
    return RegExp(r'\b\d+\b').hasMatch(addr);
  }

  /// Escolhe o endereço mais detalhado entre o Geocoder nativo do Android e o OpenStreetMap.
  String _pickBestAddress(String nativeAddr, String? osmAddr) {
    final cleanNative = nativeAddr
        .replaceAll('Região Metropolitana de ', '')
        .replaceAll('Região Geográfica Imediata de ', '')
        .trim();
    final cleanOsm = (osmAddr ?? '').trim();

    if (cleanOsm.isEmpty) return cleanNative;
    if (cleanNative.isEmpty ||
        nativeAddr.toLowerCase().startsWith('região')) {
      return cleanOsm;
    }

    final nativeScore = _scoreAddressDetail(cleanNative);
    final osmScore = _scoreAddressDetail(cleanOsm);

    return osmScore >= nativeScore ? cleanOsm : cleanNative;
  }

  int _scoreAddressDetail(String addr) {
    int score = 0;
    if (!addr.toLowerCase().startsWith('região')) score += 2;
    if (addr.contains(' - ')) score += 3; // Possui separador de bairro
    if (addr.contains(',')) score += 2; // Possui separador de número/cidade
    if (_hasHouseNumber(addr)) score += 3; // Possui número na rua
    return score;
  }

  /// Geocodificação reversa de alta precisão (zoom=18) retornando:
  /// "Rua X, Nº 123 - Bairro, Cidade"
  Future<String?> _reverseGeocodeOsm(double lat, double lon) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&zoom=18&addressdetails=1&accept-language=pt-BR',
      );
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'DeltamixApp/1.0');
      final resp = await req.close();
      if (resp.statusCode != 200) return null;

      final body = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>?;
      if (addr == null) return null;

      final String road = (addr['road'] ??
              addr['street'] ??
              addr['pedestrian'] ??
              addr['residential'] ??
              addr['highway'] ??
              '')
          .toString()
          .trim();

      final String houseNumber =
          (addr['house_number'] ?? addr['street_number'] ?? '')
              .toString()
              .trim();

      final String neighborhood = (addr['suburb'] ??
              addr['neighbourhood'] ??
              addr['quarter'] ??
              addr['city_district'] ??
              addr['borough'] ??
              '')
          .toString()
          .trim();

      final String city = (addr['city'] ??
              addr['town'] ??
              addr['village'] ??
              addr['municipality'] ??
              '')
          .toString()
          .trim()
          .replaceAll('Região Metropolitana de ', '')
          .replaceAll('Região Geográfica Imediata de ', '')
          .trim();

      // Se o ponto exato for um posto de combustível mapeado, inclui o nome
      final String category = (data['category'] ?? '').toString();
      final String type = (data['type'] ?? '').toString();
      final String poiName = (data['name'] ?? addr['amenity'] ?? '')
          .toString()
          .trim();
      final String gasStationPrefix =
          (category == 'amenity' && type == 'fuel' && poiName.isNotEmpty)
              ? '$poiName • '
              : '';

      if (road.isNotEmpty) {
        final String streetAndNumber =
            houseNumber.isNotEmpty ? '$road, Nº $houseNumber' : road;

        final List<String> tailParts = <String>[
          if (neighborhood.isNotEmpty &&
              neighborhood.toLowerCase() != road.toLowerCase())
            neighborhood,
          if (city.isNotEmpty) city,
        ];

        if (tailParts.isNotEmpty) {
          return '$gasStationPrefix$streetAndNumber - ${tailParts.join(', ')}';
        }
        return '$gasStationPrefix$streetAndNumber';
      }

      // Caso esteja em rodovia/área sem nome de rua mapeado
      final fallbackParts = <String>[
        if (neighborhood.isNotEmpty) neighborhood,
        if (city.isNotEmpty) city,
      ];
      return fallbackParts.isEmpty ? null : fallbackParts.join(', ');
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Obtém cidade/região via HTTPS seguro (usado apenas em Desktop sem GPS).
  Future<String?> _networkApproximateLocationHttps() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4);
    try {
      final uri = Uri.parse('https://ipwho.is/?lang=pt-BR');
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'DeltamixApp/1.0');
      final resp = await req.close();
      if (resp.statusCode != 200) return null;

      final body = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final city = (data['city'] as String?)?.trim() ?? '';
        final region = (data['region_code'] as String?)?.trim() ??
            (data['region'] as String?)?.trim() ??
            '';
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
