/// ============================================================================
/// COMANDOS AT (ELM327) E PIDs OBD-II PADRÃO SAE J1979
/// ============================================================================
///
/// Centraliza todos os códigos de comando enviados via Bluetooth Serial (SPP)
/// para o scanner automotivo ELM327 e para a ECU do veículo.
abstract class ObdCommands {
  // ---------------------------------------------------------------------------
  // COMANDOS AT DE INICIALIZAÇÃO DO CHIP ELM327
  // ---------------------------------------------------------------------------

  /// Reseta o adaptador ELM327 para o estado inicial de fábrica.
  static const String reset = 'ATZ';

  /// Desativa o Eco dos comandos enviados (evita que o ELM327 repita a pergunta).
  static const String echoOff = 'ATE0';

  /// Desativa quebras de linha extras (\n), facilitando o parse das respostas.
  static const String linefeedsOff = 'ATL0';

  /// Define a busca automática do protocolo de comunicação do veículo
  /// (CAN 11/29 bits, ISO 9141-2, KWP2000, SAE J1850).
  static const String autoProtocol = 'ATSP0';

  // ---------------------------------------------------------------------------
  // COMANDOS OBD-II (MODE 01 - LEITURA DE DADOS EM TEMPO REAL DA ECU)
  // ---------------------------------------------------------------------------

  /// Mode 01 PID 52: Porcentagem de Etanol no Combustível (Ethanol Fuel %).
  /// Resposta esperada: "41 52 XX" -> Fórmula: (A * 100) / 255
  static const String ethanolFuelPercent = '01 52';

  /// Mode 01 PID 0C: Rotação do Motor (Engine RPM).
  /// Resposta esperada: "41 0C AA BB" -> Fórmula: ((A * 256) + B) / 4
  static const String engineRpm = '01 0C';

  /// Mode 01 PID 06: Short Term Fuel Trim - Banco 1 (STFT / Ajuste de Combustível a Curto Prazo).
  /// Resposta esperada: "41 06 XX" -> Fórmula: ((A - 128) * 100) / 128
  static const String shortTermFuelTrim = '01 06';

  /// Mode 01 PID 07: Long Term Fuel Trim - Banco 1 (LTFT / Ajuste de Combustível a Longo Prazo).
  /// Resposta esperada: "41 07 XX" -> Fórmula: ((A - 128) * 100) / 128
  static const String longTermFuelTrim = '01 07';
}
