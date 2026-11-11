/// ============================================================================
/// REGISTRO DO DIÁRIO DO VEÍCULO
/// ============================================================================
///
/// Instantâneo (snapshot) dos sensores lidos da ECU via OBD-II em um momento.
/// Qualquer campo pode ser nulo caso a ECU não tenha respondido àquele PID.
/// Pode estar vinculado a uma [sprintId] (ciclo de abastecimento ativo no momento).
class DiaryEntry {
  final DateTime timestamp;
  final double? ethanolPercentage; // PID 01 52 (%)
  final int? rpm; // PID 01 0C
  final double? stft; // PID 01 06 (%)
  final double? ltft; // PID 01 07 (%)
  final String? sprintId; // ID da Sprint de Abastecimento ativa

  const DiaryEntry({
    required this.timestamp,
    this.ethanolPercentage,
    this.rpm,
    this.stft,
    this.ltft,
    this.sprintId,
  });

  bool get isEmpty =>
      ethanolPercentage == null && rpm == null && stft == null && ltft == null;
}
