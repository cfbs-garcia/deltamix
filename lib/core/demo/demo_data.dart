import 'dart:math';

import '../../features/diary/controllers/diary_controller.dart';
import '../../features/garage/controllers/garage_controller.dart';
import '../models/diary_entry.dart';
import '../models/vehicle_model.dart';

/// Coloque `false` para remover o carro de exemplo do app.
const bool kShowDemoVehicle = true;

/// ============================================================================
/// CARRO DE EXEMPLO (APENAS PARA VISUALIZAR O DESIGN DO DIÁRIO)
/// ============================================================================
///
/// Cria um veículo fictício com ~30 leituras em 3 dias (uma troca de gasolina
/// para etanol, para o gráfico ter uma história). Ele não recebe leituras
/// reais do scanner e pode ser excluído pela Garagem como qualquer outro carro.
class DemoData {
  DemoData._();

  static const String vehicleId = 'demo-vehicle';

  /// Adiciona o carro de exemplo (só na memória: nunca é gravado na nuvem).
  /// É chamado após o login, quando a conta ainda não tem carros próprios.
  static void seed() {
    if (!kShowDemoVehicle) return;
    final garage = GarageController.instance;
    if (garage.vehicles.any((v) => v.isDemo)) return;

    garage.addVehicle(
      VehicleModel(
        id: vehicleId,
        model: 'Honda Civic 2.0 Flex',
        plate: 'EXE-0001',
        nickname: 'Meu Civic',
        obdName: 'ELM327 (exemplo)',
        ethanolPercentage: 71.0,
        isDemo: true,
      ),
      select: garage.vehicles.isEmpty,
    );
    DiaryController.instance.addAll(vehicleId, _buildEntries());
  }

  static List<DiaryEntry> _buildEntries() {
    final rnd = Random(42);
    final now = DateTime.now();
    final entries = <DiaryEntry>[];

    double round1(double v) => (v * 10).roundToDouble() / 10;

    // [início da sessão, nº de leituras, etanol inicial, passo, LTFT base]
    final sessions = <List<Object>>[
      [now.subtract(const Duration(days: 2, hours: 3)), 9, 27.0, 0.05, 1.6],
      [now.subtract(const Duration(days: 1, hours: 1)), 11, 31.0, 3.2, -0.8],
      [now.subtract(const Duration(minutes: 55)), 11, 64.0, 0.7, 0.4],
    ];

    for (var s = 0; s < sessions.length; s++) {
      final start = sessions[s][0] as DateTime;
      final count = sessions[s][1] as int;
      final ethanol0 = sessions[s][2] as double;
      final step = sessions[s][3] as double;
      final ltftBase = sessions[s][4] as double;

      for (var i = 0; i < count; i++) {
        final ethanol =
            (ethanol0 + i * step + (rnd.nextDouble() - 0.5) * 1.2)
                .clamp(0.0, 100.0)
                .toDouble();
        final rpm = i == 0
            ? 780 + rnd.nextInt(120) // marcha lenta na partida
            : 1400 + rnd.nextInt(1800);
        var stft = (rnd.nextDouble() - 0.5) * 6; // -3 a +3
        if (s == 1 && i == 4) stft = 8.5; // um pico para mostrar o alerta
        final ltft = ltftBase + (rnd.nextDouble() - 0.5);

        entries.add(
          DiaryEntry(
            timestamp: start.add(Duration(minutes: i * 5)),
            ethanolPercentage: round1(ethanol),
            rpm: rpm,
            stft: round1(stft),
            ltft: round1(ltft),
          ),
        );
      }
    }
    return entries;
  }
}
