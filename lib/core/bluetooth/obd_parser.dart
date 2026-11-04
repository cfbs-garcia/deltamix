/// ============================================================================
/// DECODIFICADOR DE RESPOSTAS HEXADECIMAIS DA ECU (OBD-II PARSER)
/// ============================================================================
///
/// Responsável por validar o cabeçalho de resposta positiva da ECU ("41 + PID")
/// e aplicar as fórmulas matemáticas oficiais da norma SAE J1979.
abstract class ObdParser {
  /// Limpa espaços, quebras de linha e padroniza para letras maiúsculas.
  static String normalizeHex(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  /// Verifica se a resposta da ECU indica ausência de suporte ou ignição desligada.
  static bool isNoData(String cleanHex) => cleanHex.contains('NODATA');

  /// Verifica se houve falha de barramento ou comunicação com a ECU.
  static bool isConnectionError(String cleanHex) {
    return cleanHex.contains('UNABLETOCONNECT') ||
        cleanHex.contains('ERROR') ||
        cleanHex.contains('STOPPED') ||
        cleanHex.contains('BUSINIT');
  }

  // ---------------------------------------------------------------------------
  // 1. PARSE DE PORCENTAGEM DE ETANOL (PID 01 52 -> Cabeçalho "4152")
  // ---------------------------------------------------------------------------
  /// Fórmula Oficial SAE J1979:
  /// Porcentagem (%) = (Byte A * 100) / 255
  /// Exemplo: "41 52 46" -> 0x46 = 70 -> (70 * 100) / 255 = 27.5%
  static double? parseEthanolPercentage(String rawResponse) {
    final clean = normalizeHex(rawResponse);
    final index = clean.indexOf('4152');
    if (index != -1 && clean.length >= index + 6) {
      final hexA = clean.substring(index + 4, index + 6);
      final int? byteA = int.tryParse(hexA, radix: 16);
      if (byteA != null) {
        final pct = (byteA * 100.0) / 255.0;
        return double.parse(pct.clamp(0.0, 100.0).toStringAsFixed(1));
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 2. PARSE DE ROTAÇÃO DO MOTOR - RPM (PID 01 0C -> Cabeçalho "410C")
  // ---------------------------------------------------------------------------
  /// Fórmula Oficial SAE J1979:
  /// RPM = ((Byte A * 256) + Byte B) / 4
  /// Exemplo: "41 0C 0D 48" -> A=13, B=72 -> ((13 * 256) + 72) / 4 = 850 RPM
  static int? parseRpm(String rawResponse) {
    final clean = normalizeHex(rawResponse);
    final index = clean.indexOf('410C');
    if (index != -1 && clean.length >= index + 8) {
      final hexA = clean.substring(index + 4, index + 6);
      final hexB = clean.substring(index + 6, index + 8);
      final int? byteA = int.tryParse(hexA, radix: 16);
      final int? byteB = int.tryParse(hexB, radix: 16);
      if (byteA != null && byteB != null) {
        return (((byteA * 256) + byteB) / 4).round();
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 3. PARSE DE FUEL TRIM - STFT E LTFT (PID 01 06 / 01 07 -> "4106" / "4107")
  // ---------------------------------------------------------------------------
  /// Fórmula Oficial SAE J1979 para Ajustes de Combustível (Curto e Longo Prazo):
  /// Trim (%) = ((Byte A - 128) * 100) / 128
  /// Faixa válida: -100.0% (empobrecendo mistura) a +99.2% (enriquecendo mistura)
  /// Exemplo: "41 06 80" -> A=128 -> 0.0% | "41 07 95" -> A=149 -> +16.4%
  static double? parseFuelTrim(String rawResponse, {required String pidHex}) {
    final clean = normalizeHex(rawResponse);
    final header = '41${pidHex.toUpperCase()}';
    final index = clean.indexOf(header);
    if (index != -1 && clean.length >= index + 6) {
      final hexA = clean.substring(index + 4, index + 6);
      final int? byteA = int.tryParse(hexA, radix: 16);
      if (byteA != null) {
        final trim = ((byteA - 128) * 100.0) / 128.0;
        return double.parse(trim.toStringAsFixed(1));
      }
    }
    return null;
  }
}
