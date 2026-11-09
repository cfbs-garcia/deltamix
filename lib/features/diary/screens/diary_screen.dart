import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/models/diary_entry.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../fuel_dashboard/widgets/ethanol_gauge_chart.dart';
import '../../garage/controllers/garage_controller.dart';
import '../controllers/diary_controller.dart';
import '../widgets/ethanol_trend_chart.dart';

/// ============================================================================
/// DIÁRIO / DASHBOARD DO VEÍCULO
/// ============================================================================
///
/// Mostra, para cada carro da Garagem, as últimas informações coletadas pelo
/// scanner OBD-II: última leitura (etanol, RPM, STFT, LTFT), evolução da mistura,
/// um resumo e o histórico de registros agrupado por dia.
class DiaryScreen extends StatefulWidget {
  /// Veículo exibido ao abrir (por padrão, o veículo ativo da Garagem).
  final String? initialVehicleId;

  const DiaryScreen({super.key, this.initialVehicleId});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId =
        widget.initialVehicleId ?? GarageController.instance.activeVehicle?.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Diário do Veículo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            GarageController.instance,
            DiaryController.instance,
          ]),
          builder: (context, _) {
            if (GarageController.instance.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.ethanolNeon),
              );
            }
            final vehicles = GarageController.instance.vehicles;
            if (vehicles.isEmpty) return const _NoVehicles();

            final vehicle = vehicles.firstWhere(
              (v) => v.id == _selectedId,
              orElse: () => vehicles.first,
            );
            final entries = DiaryController.instance.entriesFor(vehicle.id);

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (vehicles.length > 1) ...[
                  _VehicleSelector(
                    vehicles: vehicles,
                    selectedId: vehicle.id,
                    onSelected: (id) => setState(() => _selectedId = id),
                  ),
                  const SizedBox(height: 16),
                ],
                _VehicleHeader(
                  vehicle: vehicle,
                  last: entries.isEmpty ? null : entries.last,
                  count: entries.length,
                ),
                const SizedBox(height: 20),
                if (entries.isEmpty)
                  const _EmptyDiary()
                else
                  ..._buildContent(entries),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildContent(List<DiaryEntry> entries) {
    final last = entries.last;

    // Valores para o gráfico (últimos 24 registros com etanol)
    final ethanolSeries = entries
        .where((e) => e.ethanolPercentage != null)
        .map((e) => e.ethanolPercentage!)
        .toList();
    final chartValues = ethanolSeries.length > 24
        ? ethanolSeries.sublist(ethanolSeries.length - 24)
        : ethanolSeries;

    // Resumo
    final avgEthanol = ethanolSeries.isEmpty
        ? null
        : ethanolSeries.reduce((a, b) => a + b) / ethanolSeries.length;
    final rpms = entries.where((e) => e.rpm != null).map((e) => e.rpm!);
    final maxRpm = rpms.isEmpty ? null : rpms.reduce((a, b) => a > b ? a : b);

    return [
      const _SectionTitle('ÚLTIMA LEITURA'),
      const SizedBox(height: 10),
      _LastReadingCard(entry: last),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _MetricTile(
              icon: Icons.speed_rounded,
              label: 'ROTAÇÃO',
              value: last.rpm == null ? '--' : _thousands(last.rpm!),
              unit: 'RPM',
              color: AppColors.obdCyan,
              caption: last.rpm == null
                  ? 'Sem dado'
                  : (last.rpm! < 1000 ? 'Marcha lenta' : 'Em uso'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _trimTile('STFT', 'Curto prazo', last.stft),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _trimTile('LTFT', 'Longo prazo', last.ltft),
          ),
        ],
      ),
      const SizedBox(height: 24),
      const _SectionTitle('EVOLUÇÃO DO ETANOL'),
      const SizedBox(height: 10),
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Últimos ${chartValues.length} registros',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            EthanolTrendChart(values: chartValues),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const _SectionTitle('RESUMO'),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _SummaryTile(
              label: 'Registros',
              value: '${entries.length}',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryTile(
              label: 'Etanol médio',
              value: avgEthanol == null ? '--' : '${_num(avgEthanol)}%',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryTile(
              label: 'RPM máximo',
              value: maxRpm == null ? '--' : _thousands(maxRpm),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      const _SectionTitle('HISTÓRICO'),
      const SizedBox(height: 10),
      ..._buildHistory(entries),
    ];
  }

  Widget _trimTile(String label, String caption, double? value) {
    final Color color = value == null ? AppColors.textMuted : _trimColor(value);
    return _MetricTile(
      icon: Icons.tune_rounded,
      label: label,
      value: value == null ? '--' : _num(value, signed: true),
      unit: '%',
      color: color,
      caption: value == null ? 'Sem dado' : '$caption • ${_trimLabel(value)}',
    );
  }

  /// Histórico do mais recente para o mais antigo, agrupado por dia.
  List<Widget> _buildHistory(List<DiaryEntry> entries) {
    const maxShown = 40;
    final recent = entries.reversed.take(maxShown).toList();
    final widgets = <Widget>[];
    String? currentDay;

    for (final e in recent) {
      final day = _dayLabel(e.timestamp);
      if (day != currentDay) {
        currentDay = day;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 14, bottom: 8),
            child: Text(
              day,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
      widgets.add(_HistoryRow(entry: e));
      widgets.add(const SizedBox(height: 8));
    }

    if (entries.length > maxShown) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Mostrando os $maxShown registros mais recentes de ${entries.length}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ),
      );
    }
    return widgets;
  }
}

// =============================================================================
// COMPONENTES
// =============================================================================

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow>? shadow;
  final Color? borderColor;

  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.shadow,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: shadow,
      ),
      child: child,
    );
  }
}

class _NoVehicles extends StatelessWidget {
  const _NoVehicles();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, size: 56, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text(
              'Nenhum veículo na garagem',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Cadastre um carro e conecte o leitor OBD-II para começar o diário.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDiary extends StatelessWidget {
  const _EmptyDiary();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          Icon(Icons.hourglass_empty_rounded,
              size: 40, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'Ainda sem leituras',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Conecte o leitor OBD-II a este carro. As leituras da ECU serão '
            'registradas aqui automaticamente.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _VehicleSelector extends StatelessWidget {
  final List<VehicleModel> vehicles;
  final String selectedId;
  final ValueChanged<String> onSelected;

  const _VehicleSelector({
    required this.vehicles,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: vehicles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final v = vehicles[i];
          final selected = v.id == selectedId;
          return GestureDetector(
            onTap: () => onSelected(v.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.ethanolNeon.withValues(alpha: 0.14)
                    : AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.ethanolNeon : AppColors.border,
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.directions_car_filled_rounded,
                    size: 16,
                    color: selected
                        ? AppColors.ethanolNeon
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    v.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VehicleHeader extends StatelessWidget {
  final VehicleModel vehicle;
  final DiaryEntry? last;
  final int count;

  const _VehicleHeader({
    required this.vehicle,
    required this.last,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceInput,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.directions_car_filled_rounded,
              color: AppColors.ethanolNeon,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        vehicle.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (vehicle.isDemo) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              AppColors.gasolineNeon.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                AppColors.gasolineNeon.withValues(alpha: 0.6),
                          ),
                        ),
                        child: const Text(
                          'EXEMPLO',
                          style: TextStyle(
                            color: AppColors.gasolineNeon,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  vehicle.displaySubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: last == null
                          ? AppColors.textMuted
                          : AppColors.obdCyan,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        last == null
                            ? 'Nenhuma leitura registrada'
                            : 'Última leitura ${_relative(last!.timestamp)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: last == null
                              ? AppColors.textMuted
                              : AppColors.obdCyan,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LastReadingCard extends StatelessWidget {
  final DiaryEntry entry;
  const _LastReadingCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final ethanol = entry.ethanolPercentage;
    final color = ethanol == null
        ? AppColors.textMuted
        : EthanolGaugeChart.colorForLevel(ethanol);
    final double? gasoline = ethanol == null ? null : 100.0 - ethanol;

    return _Card(
      borderColor: color.withValues(alpha: 0.35),
      shadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.12),
          blurRadius: 18,
          spreadRadius: 1,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ETANOL NO TANQUE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ethanol == null ? '--' : '${_num(ethanol)}%',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'GASOLINA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gasoline == null ? '--' : '${_num(gasoline)}%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gasolineNeon,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Barra de proporção etanol x gasolina
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: _flex(ethanol ?? 0),
                    child: Container(color: AppColors.ethanolNeon),
                  ),
                  Expanded(
                    flex: _flex(gasoline ?? 100),
                    child: Container(
                      color: AppColors.gasolineNeon.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_dayLabel(entry.timestamp)} às ${_hm(entry.timestamp)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final String caption;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textSecondary,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final DiaryEntry entry;
  const _HistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final ethanol = entry.ethanolPercentage;
    final dot = ethanol == null
        ? AppColors.textMuted
        : EthanolGaugeChart.colorForLevel(ethanol);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              _hm(entry.timestamp),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(
              ethanol == null ? '--' : '${_num(ethanol)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: dot,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'RPM ${entry.rpm == null ? '--' : _thousands(entry.rpm!)}'
              '  •  STFT ${entry.stft == null ? '--' : _num(entry.stft!, signed: true)}'
              '  •  LTFT ${entry.ltft == null ? '--' : _num(entry.ltft!, signed: true)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// FORMATAÇÃO
// =============================================================================

/// Peso (1 a 999) de um segmento da barra etanol x gasolina.
int _flex(double pct) => math.max(1, math.min(999, (pct * 10).round()));

/// Número com 1 casa decimal e vírgula (ex.: 72,5). Remove ",0" quando inteiro.
String _num(double v, {bool signed = false}) {
  var s = v.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  s = s.replaceAll('.', ',');
  if (signed && v > 0) s = '+$s';
  return s;
}

/// Inteiro com separador de milhar (ex.: 1.850).
String _thousands(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _two(int n) => n.toString().padLeft(2, '0');

String _hm(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

String _dayLabel(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hoje';
  if (diff == 1) return 'Ontem';
  return '${_two(t.day)}/${_two(t.month)}/${t.year}';
}

String _relative(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'agora há pouco';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours} h';
  return 'há ${diff.inDays} d';
}

/// Fuel trim: perto de 0% é saudável; acima de ±5% pede atenção; ±10% é alto.
Color _trimColor(double v) {
  final a = v.abs();
  if (a <= 5) return AppColors.ethanolNeon;
  if (a <= 10) return AppColors.gasolineNeon;
  return AppColors.alertRed;
}

String _trimLabel(double v) {
  final a = v.abs();
  if (a <= 5) return 'Normal';
  if (a <= 10) return 'Atenção';
  return 'Alto';
}
