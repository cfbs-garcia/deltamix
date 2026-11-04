/// ============================================================================
/// MODELO DE LEITURA DE TELEMETRIA OBD-II
/// ============================================================================
///
/// Representa o resultado de uma leitura de etanol e dos parâmetros de
/// telemetria do motor (RPM, STFT e LTFT) enviados pela ECU do veículo.
class EthanolReadResult {
  final bool success;
  final double percentage;    // Porcentagem calculada de etanol (ex: 27.5%)
  final String rawResponse;   // Resposta hexadecimal bruta da ECU (ex: "41 52 46")
  final String? errorMessage; // Mensagem amigável caso ocorra erro (ex: NO DATA)

  EthanolReadResult({
    required this.success,
    this.percentage = 0.0,
    this.rawResponse = '',
    this.errorMessage,
  });
}
