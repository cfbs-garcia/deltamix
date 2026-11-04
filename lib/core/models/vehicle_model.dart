/// Modelo de dados de um Veículo cadastrado no Deltamix.
class VehicleModel {
  final String id;
  final String model;
  final String plate;
  final String? nickname; // Opcional para o usuário (ex: "Meu Foguete", "Carro do Trabalho")
  final String? obdName;
  final String? obdMacAddress;
  final bool isObdConnected;
  final double ethanolPercentage;
  final double gasolinePercentage;

  VehicleModel({
    required this.id,
    required this.model,
    required this.plate,
    this.nickname,
    this.obdName,
    this.obdMacAddress,
    this.isObdConnected = false,
    this.ethanolPercentage = 78.0,
    double? gasolinePercentage,
  }) : gasolinePercentage = gasolinePercentage ?? (100.0 - ethanolPercentage).clamp(0.0, 100.0);

  /// Retorna o apelido se existir, senão retorna o modelo do carro
  String get displayName =>
      (nickname != null && nickname!.trim().isNotEmpty) ? nickname!.trim() : model;

  /// Retorna subtítulo contextual (ex: "Golf 1.4 TSI • BRA-2E19")
  String get displaySubtitle =>
      (nickname != null && nickname!.trim().isNotEmpty) ? '$model • $plate' : plate;

  VehicleModel copyWith({
    String? id,
    String? model,
    String? plate,
    String? nickname,
    String? obdName,
    String? obdMacAddress,
    bool? isObdConnected,
    double? ethanolPercentage,
    double? gasolinePercentage,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      model: model ?? this.model,
      plate: plate ?? this.plate,
      nickname: nickname ?? this.nickname,
      obdName: obdName ?? this.obdName,
      obdMacAddress: obdMacAddress ?? this.obdMacAddress,
      isObdConnected: isObdConnected ?? this.isObdConnected,
      ethanolPercentage: ethanolPercentage ?? this.ethanolPercentage,
      gasolinePercentage: gasolinePercentage ?? this.gasolinePercentage,
    );
  }
}
