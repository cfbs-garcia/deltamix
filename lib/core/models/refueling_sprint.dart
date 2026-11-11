/// Tipos de combustível disponíveis para registro de abastecimento.
enum FuelType {
  etanol('Etanol', '🌿', 100.0),
  gasolinaComum('Gasolina Comum', '⛽', 27.0),
  gasolinaAditivada('Gasolina Aditivada', '⚡', 27.0),
  gasolinaPremium('Gasolina Premium', '🏆', 25.0),
  mistura('Mistura (2 Combustíveis)', '🧪', 50.0);

  final String label;
  final String emoji;

  /// Percentual médio de etanol esperado na bomba (E100 para Etanol, E27/E25 para Gasolina no Brasil)
  final double baseEthanolPct;

  const FuelType(this.label, this.emoji, this.baseEthanolPct);

  static FuelType fromCode(String? code) {
    for (final t in FuelType.values) {
      if (t.name == code) return t;
    }
    return FuelType.etanol;
  }
}

/// ============================================================================
/// SPRINT / CICLO DE ABASTECIMENTO DO VEÍCULO
/// ============================================================================
///
/// Representa um abastecimento realizado pelo motorista e o ciclo ("sprint")
/// de monitoramento OBD-II associado a esse tanque:
/// - Inicia em [startedAt] (momento do abastecimento).
/// - Enquanto [endedAt] for `null`, esta é a Sprint Ativa (em andamento), e
///   todas as novas leituras da ECU são associadas a ela.
/// - Quando o motorista registra um próximo abastecimento, [endedAt] é
///   preenchido e a Sprint passa para o histórico concluído.
class RefuelingSprint {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// Tipo selecionado (ou `FuelType.mistura` quando combina 2 combustíveis)
  final FuelType fuelType;

  /// Litros e preço por litro do combustível principal (ou único)
  final double liters;
  final double pricePerLiter;

  /// Quando `fuelType == FuelType.mistura`, define qual é o 1º e o 2º combustível
  final FuelType? primaryFuelType;
  final FuelType? secondaryFuelType;
  final double? secondaryLiters;
  final double? secondaryPricePerLiter;

  /// Local / posto de combustível (obtido via GPS do celular ou digitado pelo motorista)
  final String? location;

  const RefuelingSprint({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.fuelType,
    required this.liters,
    required this.pricePerLiter,
    this.primaryFuelType,
    this.secondaryFuelType,
    this.secondaryLiters,
    this.secondaryPricePerLiter,
    this.location,
  });

  /// Verdadeiro enquanto o motorista ainda está rodando com este abastecimento
  bool get isActive => endedAt == null;

  /// Verdadeiro quando o abastecimento foi feito misturando 2 combustíveis
  bool get isMix =>
      fuelType == FuelType.mistura &&
      secondaryFuelType != null &&
      (secondaryLiters ?? 0) > 0;

  /// Soma total de litros colocados no tanque neste abastecimento
  double get totalLiters => liters + (secondaryLiters ?? 0.0);

  /// Valor financeiro total pago no abastecimento (R$)
  double get totalCost =>
      (liters * pricePerLiter) +
      ((secondaryLiters ?? 0.0) * (secondaryPricePerLiter ?? 0.0));

  /// Preço médio ponderado por litro neste abastecimento (R$/L)
  double get averagePricePerLiter =>
      totalLiters > 0 ? totalCost / totalLiters : pricePerLiter;

  /// Estimativa teórica de % de etanol colocada na bomba neste abastecimento
  double get estimatedPumpEthanolPct {
    if (!isMix) return fuelType.baseEthanolPct;
    final f1 = primaryFuelType ?? FuelType.etanol;
    final f2 = secondaryFuelType ?? FuelType.gasolinaComum;
    final l2 = secondaryLiters ?? 0.0;
    final total = liters + l2;
    if (total <= 0) return f1.baseEthanolPct;
    return ((liters * f1.baseEthanolPct) + (l2 * f2.baseEthanolPct)) / total;
  }

  /// Título amigável do combustível (ex: "Etanol" ou "Mistura: Etanol + Gasolina Aditivada")
  String get displayFuelTitle {
    if (!isMix) return '${fuelType.emoji} ${fuelType.label}';
    final f1 = primaryFuelType ?? FuelType.etanol;
    final f2 = secondaryFuelType ?? FuelType.gasolinaComum;
    return '🧪 Mistura: ${f1.label} + ${f2.label}';
  }

  RefuelingSprint copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? endedAt,
    FuelType? fuelType,
    double? liters,
    double? pricePerLiter,
    FuelType? primaryFuelType,
    FuelType? secondaryFuelType,
    double? secondaryLiters,
    double? secondaryPricePerLiter,
    String? location,
  }) {
    return RefuelingSprint(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      fuelType: fuelType ?? this.fuelType,
      liters: liters ?? this.liters,
      pricePerLiter: pricePerLiter ?? this.pricePerLiter,
      primaryFuelType: primaryFuelType ?? this.primaryFuelType,
      secondaryFuelType: secondaryFuelType ?? this.secondaryFuelType,
      secondaryLiters: secondaryLiters ?? this.secondaryLiters,
      secondaryPricePerLiter:
          secondaryPricePerLiter ?? this.secondaryPricePerLiter,
      location: location ?? this.location,
    );
  }
}
