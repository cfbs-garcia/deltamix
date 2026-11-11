import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/models/refueling_sprint.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';

/// ============================================================================
/// MODAL DE REGISTRO DE ABASTECIMENTO (INÍCIO DE NOVA SPRINT)
/// ============================================================================
///
/// Permite ao motorista registrar:
/// - Tipo de combustível: Etanol, Gasolina Comum, Aditivada, Premium ou Mistura (2 combustíveis).
/// - Quantidade de litros e preço por litro (individual ou dos 2 combustíveis na mistura).
/// - Localização do abastecimento (puxando pelo GPS do celular ou digitando manualmente).
class RegisterRefuelingSheet extends StatefulWidget {
  final bool hasActiveSprint;

  const RegisterRefuelingSheet({
    super.key,
    required this.hasActiveSprint,
  });

  @override
  State<RegisterRefuelingSheet> createState() => _RegisterRefuelingSheetState();
}

class _RegisterRefuelingSheetState extends State<RegisterRefuelingSheet> {
  FuelType _selectedType = FuelType.etanol;

  // Para quando o usuário escolhe "Mistura (2 Combustíveis)"
  FuelType _mixPrimaryType = FuelType.etanol;
  FuelType _mixSecondaryType = FuelType.gasolinaComum;

  final _liters1Controller = TextEditingController();
  final _price1Controller = TextEditingController();
  final _liters2Controller = TextEditingController();
  final _price2Controller = TextEditingController();
  final _locationController = TextEditingController();

  bool _isLoadingLocation = false;
  bool _showOpenSettingsButton = false;
  String? _errorText;

  static const List<FuelType> _singleFuelTypes = [
    FuelType.etanol,
    FuelType.gasolinaComum,
    FuelType.gasolinaAditivada,
    FuelType.gasolinaPremium,
  ];

  @override
  void dispose() {
    _liters1Controller.dispose();
    _price1Controller.dispose();
    _liters2Controller.dispose();
    _price2Controller.dispose();
    _locationController.dispose();
    super.dispose();
  }

  double _parseNum(String raw) {
    final cleaned = raw.trim().replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  bool get _isMix => _selectedType == FuelType.mistura;

  double get _l1 => _parseNum(_liters1Controller.text);
  double get _p1 => _parseNum(_price1Controller.text);
  double get _l2 => _isMix ? _parseNum(_liters2Controller.text) : 0.0;
  double get _p2 => _isMix ? _parseNum(_price2Controller.text) : 0.0;

  double get _totalLiters => _l1 + _l2;
  double get _totalCost => (_l1 * _p1) + (_l2 * _p2);

  Future<void> _fetchDeviceLocation() async {
    if (_isLoadingLocation) return;
    setState(() {
      _isLoadingLocation = true;
      _showOpenSettingsButton = false;
      _errorText = null;
    });

    try {
      final result = await LocationService.instance.fetchCurrentLocation();
      if (!mounted) return;

      if (result.label != null && result.label!.isNotEmpty) {
        final current = _locationController.text.trim();
        if (current.isEmpty) {
          _locationController.text = result.label!;
        } else if (!current.contains(result.label!)) {
          _locationController.text = '$current • ${result.label!}';
        }
      }

      if (result.permissionDenied &&
          (result.label == null || result.label!.isEmpty)) {
        setState(() {
          _showOpenSettingsButton = true;
          _errorText = result.warningMessage;
        });
      } else if (result.label == null || result.label!.isEmpty) {
        setState(() {
          _errorText = result.warningMessage ??
              'Não foi possível identificar o endereço automaticamente. Digite o local abaixo.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  void _submit() {
    setState(() => _errorText = null);

    if (_l1 <= 0) {
      setState(() {
        _errorText = _isMix
            ? 'Informe quantos litros foram abastecidos no Combustível 1.'
            : 'Informe a quantidade de litros abastecida.';
      });
      return;
    }
    if (_p1 <= 0) {
      setState(() {
        _errorText = _isMix
            ? 'Informe o preço por litro do Combustível 1.'
            : 'Informe o preço por litro do combustível.';
      });
      return;
    }

    if (_isMix) {
      if (_l2 <= 0) {
        setState(() {
          _errorText =
              'Informe quantos litros foram abastecidos no Combustível 2.';
        });
        return;
      }
      if (_p2 <= 0) {
        setState(() {
          _errorText = 'Informe o preço por litro do Combustível 2.';
        });
        return;
      }
    }

    final loc = _locationController.text.trim();
    final now = DateTime.now();

    final sprint = RefuelingSprint(
      id: now.millisecondsSinceEpoch.toString(),
      startedAt: now,
      endedAt: null,
      fuelType: _selectedType,
      liters: _l1,
      pricePerLiter: _p1,
      primaryFuelType: _isMix ? _mixPrimaryType : null,
      secondaryFuelType: _isMix ? _mixSecondaryType : null,
      secondaryLiters: _isMix ? _l2 : null,
      secondaryPricePerLiter: _isMix ? _p2 : null,
      location: loc.isEmpty ? null : loc,
    );

    Navigator.pop(context, sprint);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra superior do modal
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
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_gas_station_rounded,
                          color: AppColors.ethanolNeon,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Registrar Abastecimento',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              if (widget.hasActiveSprint) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.obdCyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.obdCyan.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.flag_circle_rounded,
                        color: AppColors.obdCyan,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ao salvar, a Sprint atual será encerrada e uma nova Sprint de monitoramento será iniciada.',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // 1. SELEÇÃO DO TIPO DE COMBUSTÍVEL
              const Text(
                'TIPO DE COMBUSTÍVEL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: FuelType.values.map((type) {
                  final selected = _selectedType == type;
                  return ChoiceChip(
                    label: Text('${type.emoji} ${type.label}'),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedType = type),
                    selectedColor:
                        AppColors.ethanolNeon.withValues(alpha: 0.18),
                    backgroundColor: AppColors.surfaceInput,
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.ethanolNeon
                          : AppColors.textSecondary,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: selected
                            ? AppColors.ethanolNeon
                            : AppColors.border,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 18),

              // 2. LITROS E PREÇO POR LITRO (SIMPLES OU MISTURA DE 2 COMBUSTÍVEIS)
              if (!_isMix) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildNumericField(
                        controller: _liters1Controller,
                        label: 'Litros (L)',
                        hint: 'Ex: 35,0',
                        icon: Icons.water_drop_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNumericField(
                        controller: _price1Controller,
                        label: 'Preço / Litro (R\$)',
                        hint: 'Ex: 3,89',
                        icon: Icons.attach_money_rounded,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                _buildMixBlock(
                  title: 'COMBUSTÍVEL 1 DA MISTURA',
                  selectedFuel: _mixPrimaryType,
                  onFuelChanged: (f) => setState(() => _mixPrimaryType = f),
                  litersCtrl: _liters1Controller,
                  priceCtrl: _price1Controller,
                ),
                const SizedBox(height: 12),
                _buildMixBlock(
                  title: 'COMBUSTÍVEL 2 DA MISTURA',
                  selectedFuel: _mixSecondaryType,
                  onFuelChanged: (f) => setState(() => _mixSecondaryType = f),
                  litersCtrl: _liters2Controller,
                  priceCtrl: _price2Controller,
                ),
              ],

              const SizedBox(height: 18),

              // 3. LOCALIZAÇÃO DO ABASTECIMENTO (BOTÃO ACIMA DA CAIXA DE DIGITAÇÃO)
              const Text(
                'LOCAL / POSTO DE COMBUSTÍVEL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ethanolNeon,
                  backgroundColor:
                      AppColors.ethanolNeon.withValues(alpha: 0.08),
                  side: BorderSide(
                    color: AppColors.ethanolNeon.withValues(alpha: 0.45),
                  ),
                  minimumSize: const Size.fromHeight(42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoadingLocation ? null : _fetchDeviceLocation,
                icon: _isLoadingLocation
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.ethanolNeon,
                        ),
                      )
                    : const Icon(
                        Icons.my_location_rounded,
                        size: 17,
                        color: AppColors.ethanolNeon,
                      ),
                label: Text(
                  _isLoadingLocation
                      ? 'Buscando localização...'
                      : 'Puxar localização atual do celular',
                  style: const TextStyle(
                    color: AppColors.ethanolNeon,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _locationController,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceInput,
                  hintText: 'Ex: Posto Shell • Av. Paulista (Opcional)',
                  hintStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                  ),
                  prefixIcon: const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.obdCyan,
                    size: 20,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),

              if (_showOpenSettingsButton) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => openAppSettings(),
                    icon: const Icon(
                      Icons.settings_outlined,
                      size: 16,
                      color: AppColors.obdCyan,
                    ),
                    label: const Text(
                      'Abrir Configurações do App para permitir GPS',
                      style: TextStyle(
                        color: AppColors.obdCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],

              // 4. RESUMO FINANCEIRO AUTOMÁTICO
              if (_totalLiters > 0 || _totalCost > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceInput,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.ethanolNeon.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL ABASTECIDO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_totalLiters.toStringAsFixed(1).replaceAll('.', ',')} L',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'VALOR TOTAL ESTIMADO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'R\$ ${_totalCost.toStringAsFixed(2).replaceAll('.', ',')}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ethanolNeon,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    color: AppColors.alertRed,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ethanolNeon,
                  foregroundColor: AppColors.textOnNeon,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                onPressed: _submit,
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: Text(
                  widget.hasActiveSprint
                      ? 'Concluir Anterior e Iniciar Nova Sprint'
                      : 'Iniciar Sprint de Abastecimento',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumericField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surfaceInput,
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        prefixIcon: Icon(icon, size: 18, color: AppColors.ethanolNeon),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }

  Widget _buildMixBlock({
    required String title,
    required FuelType selectedFuel,
    required ValueChanged<FuelType> onFuelChanged,
    required TextEditingController litersCtrl,
    required TextEditingController priceCtrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AppColors.obdCyan,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<FuelType>(
            initialValue: selectedFuel,
            dropdownColor: AppColors.surfaceCard,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceInput,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            items: _singleFuelTypes.map((f) {
              return DropdownMenuItem<FuelType>(
                value: f,
                child: Text('${f.emoji} ${f.label}'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) onFuelChanged(val);
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildNumericField(
                  controller: litersCtrl,
                  label: 'Litros (L)',
                  hint: 'Ex: 20,0',
                  icon: Icons.water_drop_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildNumericField(
                  controller: priceCtrl,
                  label: 'Preço / L (R\$)',
                  hint: 'Ex: 3,79',
                  icon: Icons.attach_money_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
