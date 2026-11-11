import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/models/diary_entry.dart';
import '../../../core/models/refueling_sprint.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../fuel_dashboard/widgets/ethanol_gauge_chart.dart';
import '../../garage/controllers/garage_controller.dart';
import '../controllers/diary_controller.dart';
import '../widgets/ethanol_trend_chart.dart';
import '../widgets/register_refueling_sheet.dart';

/// ============================================================================
/// DIÁRIO / DASHBOARD DO VEÍCULO E SPRINTS DE ABASTECIMENTO
/// ============================================================================
///
/// Mostra, para cada carro da Garagem:
/// 1. As Sprints de Abastecimento (ciclo ativo em andamento + ciclos anteriores
///    concluídos), com tipo de combustível, litros, preço/L, valor pago e local.
/// 2. O comportamento dos indicadores lidos via OBD-II (Etanol %, RPM, STFT,
///    LTFT e gráfico de evolução) filtrado pela Sprint selecionada ou geral.
class DiaryScreen extends StatefulWidget {
  /// Veículo exibido ao abrir (por padrão, o veículo ativo da Garagem).
  final String? initialVehicleId;

  const DiaryScreen({super.key, this.initialVehicleId});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  String? _selectedVehicleId;

  /// ID da Sprint selecionada, ou `'__ALL__'` para ver todas as leituras juntas.
  /// Quando `null`, seleciona automaticamente a Sprint mais recente (ativa).
  String? _selectedSprintId;

  @override
  void initState() {
    super.initState();
    _selectedVehicleId =
        widget.initialVehicleId ?? GarageController.instance.activeVehicle?.id;
  }

  Future<void> _openRegisterRefueling(VehicleModel vehicle) async {
    final hasActive =
        DiaryController.instance.activeSprintFor(vehicle.id) != null;

    final newSprint = await showModalBottomSheet<RefuelingSprint>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RegisterRefuelingSheet(hasActiveSprint: hasActive),
    );

    if (newSprint == null || !mounted) return;

    await DiaryController.instance.startNewSprint(vehicle.id, newSprint);
    if (!mounted) return;

    setState(() {
      _selectedSprintId = newSprint.id;
    });

    final sprintCount =
        DiaryController.instance.sprintsFor(vehicle.id).length;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasActive
              ? 'Sprint anterior concluída! Sprint #$sprintCount iniciada.'
              : 'Sprint #$sprintCount iniciada com sucesso!',
        ),
        backgroundColor: AppColors.surfaceCard,
      ),
    );
  }

  Future<void> _openSprintPickerModal(
    List<RefuelingSprint> sprints,
    RefuelingSprint? currentSelected,
    bool showingAll,
  ) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Selecionar Sprint',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${sprints.length} ${sprints.length == 1 ? 'sprint' : 'sprints'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Opção de ver Todas as leituras juntas
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(ctx, '__ALL__'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: showingAll
                            ? AppColors.obdCyan.withValues(alpha: 0.14)
                            : AppColors.surfaceInput,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              showingAll ? AppColors.obdCyan : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.layers_rounded,
                            size: 18,
                            color: showingAll
                                ? AppColors.obdCyan
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Todas as leituras (Histórico Geral)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (showingAll)
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: AppColors.obdCyan,
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 10),

                  // Lista vertical de todas as Sprints (da mais recente/ativa para a mais antiga)
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: sprints.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final sprintIndex = sprints.length - 1 - idx;
                        final s = sprints[sprintIndex];
                        final sprintNumber = sprintIndex + 1;
                        final isSelected =
                            !showingAll && currentSelected?.id == s.id;
                        final accent = s.isActive
                            ? AppColors.ethanolNeon
                            : AppColors.obdCyan;

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(ctx, s.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent.withValues(alpha: 0.14)
                                  : AppColors.surfaceInput,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? accent : AppColors.border,
                                width: isSelected ? 1.4 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceCard,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    s.isActive
                                        ? Icons.bolt_rounded
                                        : Icons.history_rounded,
                                    size: 18,
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Sprint #$sprintNumber',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          if (s.isActive) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.ethanolNeon
                                                    .withValues(alpha: 0.18),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'ATUAL',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.ethanolNeon,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${s.displayFuelTitle} • ${_num(s.totalLiters)} L • R\$ ${_money(s.totalCost)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_dayLabel(s.startedAt)} às ${_hm(s.startedAt)}'
                                        '${s.location != null && s.location!.isNotEmpty ? ' • ${s.location}' : ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 20,
                                    color: accent,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (chosen == null || !mounted) return;
    setState(() => _selectedSprintId = chosen);
  }

  Future<void> _confirmDeleteSprint(
    VehicleModel vehicle,
    RefuelingSprint sprint,
    int sprintNumber,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          'Excluir Sprint #$sprintNumber?',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Deseja remover a Sprint #$sprintNumber (${sprint.fuelType.label} • ${_dayLabel(sprint.startedAt)})?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Excluir',
              style: TextStyle(
                color: AppColors.alertRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await DiaryController.instance.deleteSprint(vehicle.id, sprint.id);
    if (mounted && _selectedSprintId == sprint.id) {
      setState(() => _selectedSprintId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Diário e Abastecimentos'),
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
              (v) => v.id == _selectedVehicleId,
              orElse: () => vehicles.first,
            );

            final allEntries = DiaryController.instance.entriesFor(vehicle.id);
            final sprints = DiaryController.instance.sprintsFor(vehicle.id);
            final bool showingAll = _selectedSprintId == '__ALL__';

            // Determina qual Sprint está selecionada no momento
            RefuelingSprint? selectedSprint;
            if (sprints.isNotEmpty && !showingAll) {
              if (_selectedSprintId != null) {
                for (final s in sprints) {
                  if (s.id == _selectedSprintId) {
                    selectedSprint = s;
                    break;
                  }
                }
              }
              selectedSprint ??= sprints.last;
            }

            final int? selectedSprintNumber = selectedSprint != null
                ? sprints.indexOf(selectedSprint) + 1
                : null;

            final displayedEntries = selectedSprint != null
                ? DiaryController.instance.entriesForSprint(
                    vehicle.id,
                    selectedSprint,
                  )
                : allEntries;

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (vehicles.length > 1) ...[
                  _VehicleSelector(
                    vehicles: vehicles,
                    selectedId: vehicle.id,
                    onSelected: (id) => setState(() {
                      _selectedVehicleId = id;
                      _selectedSprintId = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                ],
                _VehicleHeader(
                  vehicle: vehicle,
                  last: allEntries.isEmpty ? null : allEntries.last,
                  count: allEntries.length,
                ),
                const SizedBox(height: 20),

                // =============================================================
                // SEÇÃO DE SPRINTS DE ABASTECIMENTO
                // =============================================================
                Row(
                  children: [
                    const Expanded(
                      child: _SectionTitle('SPRINTS DE ABASTECIMENTO'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor:
                            AppColors.ethanolNeon.withValues(alpha: 0.14),
                        foregroundColor: AppColors.ethanolNeon,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: AppColors.ethanolNeon.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      onPressed: () => _openRegisterRefueling(vehicle),
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 15,
                      ),
                      label: const Text(
                        'Abastecer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (sprints.isEmpty)
                  _EmptySprintsBanner(
                    onRegister: () => _openRegisterRefueling(vehicle),
                  )
                else ...[
                  _SprintPickerTile(
                    selectedSprint: selectedSprint,
                    sprintNumber: selectedSprintNumber,
                    totalSprints: sprints.length,
                    showingAll: showingAll,
                    onTap: () => _openSprintPickerModal(
                      sprints,
                      selectedSprint,
                      showingAll,
                    ),
                  ),
                  if (selectedSprint != null && selectedSprintNumber != null) ...[
                    const SizedBox(height: 10),
                    _SprintDetailCard(
                      sprint: selectedSprint,
                      sprintNumber: selectedSprintNumber,
                      readingsCount: displayedEntries.length,
                      onDelete: () => _confirmDeleteSprint(
                        vehicle,
                        selectedSprint!,
                        selectedSprintNumber,
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 22),

                if (displayedEntries.isEmpty)
                  _EmptyDiary(isFilteredBySprint: selectedSprint != null)
                else
                  ..._buildContent(
                    displayedEntries,
                    sprint: selectedSprint,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildContent(
    List<DiaryEntry> entries, {
    RefuelingSprint? sprint,
  }) {
    final last = entries.last;
    final scopeSuffix = sprint != null ? ' NA SPRINT' : '';

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
      _SectionTitle('ÚLTIMA LEITURA$scopeSuffix'),
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
      _SectionTitle('EVOLUÇÃO DO ETANOL$scopeSuffix'),
      const SizedBox(height: 10),
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Últimos ${chartValues.length} registros${sprint != null ? ' desta Sprint' : ''}',
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
      _SectionTitle('RESUMO$scopeSuffix'),
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
      _SectionTitle('HISTÓRICO DE LEITURAS$scopeSuffix'),
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
// COMPONENTES DE SPRINT DE ABASTECIMENTO
// =============================================================================

class _EmptySprintsBanner extends StatelessWidget {
  final VoidCallback onRegister;

  const _EmptySprintsBanner({required this.onRegister});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceInput,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_gas_station_rounded,
              color: AppColors.ethanolNeon,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nenhum abastecimento registrado',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Registre quando abastecer para iniciar uma Sprint e acompanhar como o carro reage a cada tanque.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Seletor compacto de Sprint (abre modal vertical com todas as Sprints ao tocar)
class _SprintPickerTile extends StatelessWidget {
  final RefuelingSprint? selectedSprint;
  final int? sprintNumber;
  final int totalSprints;
  final bool showingAll;
  final VoidCallback onTap;

  const _SprintPickerTile({
    required this.selectedSprint,
    required this.sprintNumber,
    required this.totalSprints,
    required this.showingAll,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = selectedSprint?.isActive == true && !showingAll;
    final accent = isCurrent ? AppColors.ethanolNeon : AppColors.obdCyan;

    final String title = showingAll || selectedSprint == null
        ? 'Todas as leituras ($totalSprints ${totalSprints == 1 ? 'sprint' : 'sprints'})'
        : isCurrent
            ? 'Sprint #$sprintNumber (Atual) • ${selectedSprint!.fuelType.label}'
            : 'Sprint #$sprintNumber • ${selectedSprint!.fuelType.label}';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent.withValues(alpha: 0.55),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              showingAll
                  ? Icons.layers_rounded
                  : isCurrent
                      ? Icons.bolt_rounded
                      : Icons.history_rounded,
              size: 18,
              color: accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceInput,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Trocar ($totalSprints)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SprintDetailCard extends StatelessWidget {
  final RefuelingSprint sprint;
  final int sprintNumber;
  final int readingsCount;
  final VoidCallback onDelete;

  const _SprintDetailCard({
    required this.sprint,
    required this.sprintNumber,
    required this.readingsCount,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = sprint.isActive;
    final badgeColor = isActive ? AppColors.ethanolNeon : AppColors.obdCyan;

    return _Card(
      borderColor: badgeColor.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: badgeColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        isActive
                            ? 'SPRINT #$sprintNumber • EM ANDAMENTO'
                            : 'SPRINT #$sprintNumber • CONCLUÍDA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Excluir Sprint',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            sprint.displayFuelTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (sprint.isMix) ...[
            const SizedBox(height: 4),
            Text(
              '1º: ${(sprint.primaryFuelType ?? FuelType.etanol).label} (${_num(sprint.liters)} L a R\$ ${_money(sprint.pricePerLiter)}/L)\n'
              '2º: ${sprint.secondaryFuelType!.label} (${_num(sprint.secondaryLiters!)} L a R\$ ${_money(sprint.secondaryPricePerLiter!)}/L)',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  'LITROS',
                  '${_num(sprint.totalLiters)} L',
                  AppColors.textPrimary,
                ),
              ),
              Expanded(
                child: _buildMiniStat(
                  sprint.isMix ? 'PREÇO MÉDIO/L' : 'PREÇO / LITRO',
                  'R\$ ${_money(sprint.averagePricePerLiter)}',
                  AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: _buildMiniStat(
                  'VALOR TOTAL',
                  'R\$ ${_money(sprint.totalCost)}',
                  AppColors.ethanolNeon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          if (sprint.location != null && sprint.location!.isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.obdCyan,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    sprint.location!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  sprint.endedAt == null
                      ? 'Início: ${_dayLabel(sprint.startedAt)} às ${_hm(sprint.startedAt)} • Ativa'
                      : '${_dayLabel(sprint.startedAt)} (${_hm(sprint.startedAt)}) → ${_dayLabel(sprint.endedAt!)} (${_hm(sprint.endedAt!)})',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$readingsCount leituras ECU',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// COMPONENTES GERAIS DO DIÁRIO
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
  final bool isFilteredBySprint;

  const _EmptyDiary({this.isFilteredBySprint = false});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          const Icon(
            Icons.hourglass_empty_rounded,
            size: 40,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            isFilteredBySprint
                ? 'Aguardando leituras nesta Sprint'
                : 'Ainda sem leituras',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isFilteredBySprint
                ? 'Conecte o leitor OBD-II e ande com o veículo. Os parâmetros desta Sprint serão registrados automaticamente.'
                : 'Conecte o leitor OBD-II a este carro. As leituras da ECU serão registradas aqui automaticamente.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
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
                    'ETANOL NO TANQUE (ECU)',
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

/// Formata valor monetário com 2 casas decimais e vírgula (ex.: 3,79).
String _money(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

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
