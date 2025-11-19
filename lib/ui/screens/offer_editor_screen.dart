import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/offer_model.dart';
import '../../providers/menu_provider.dart';

class OfferEditorResult {
  const OfferEditorResult({required this.campaign, this.patch});

  final OfferCampaign campaign;
  final Map<String, dynamic>? patch;
}

class OfferEditorScreen extends ConsumerStatefulWidget {
  const OfferEditorScreen({super.key, this.initialCampaign});

  final OfferCampaign? initialCampaign;

  @override
  ConsumerState<OfferEditorScreen> createState() => _OfferEditorScreenState();
}

enum _FormStep { type, rules, details }

class _OfferEditorScreenState extends ConsumerState<OfferEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  int _stepIndex = 0;

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _minAmountController;
  late final TextEditingController _valueController;
  late final TextEditingController _priorityController;

  late String _offerType;
  bool _applyPerUnit = true;
  bool _isActive = false;
  DateTime? _startAt;
  DateTime? _endAt;
  TimeOfDay? _happyHourStart;
  TimeOfDay? _happyHourEnd;

  final Map<String, OfferRule> _productRules = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCampaign;
    _offerType = initial?.offerType ?? 'ITEM_FLAT';
    _applyPerUnit = initial?.applyPerUnit ?? true;
    _isActive = initial?.isActive ?? false;
    _startAt = initial?.startAt;
    _endAt = initial?.endAt;

    if (initial?.happyHourStart != null &&
        initial!.happyHourStart!.isNotEmpty) {
      _happyHourStart = _parseTime(initial.happyHourStart!);
    }
    if (initial?.happyHourEnd != null && initial!.happyHourEnd!.isNotEmpty) {
      _happyHourEnd = _parseTime(initial.happyHourEnd!);
    }

    _nameController = TextEditingController(text: initial?.name ?? '');
    _descriptionController =
        TextEditingController(text: initial?.description ?? '');
    _minAmountController = TextEditingController(
      text: initial?.minOrderAmount != null
          ? initial!.minOrderAmount!.toStringAsFixed(2)
          : '',
    );
    _valueController = TextEditingController(
      text: initial?.value != null ? initial!.value!.toStringAsFixed(2) : '',
    );
    _priorityController =
        TextEditingController(text: initial?.priority.toString() ?? '1');

    if (initial != null) {
      for (final rule in initial.rules) {
        _productRules[rule.productId] = rule;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _minAmountController.dispose();
    _valueController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuState = ref.watch(menuProvider);
    final steps = _steps;
    if (_stepIndex >= steps.length) {
      _stepIndex = steps.length - 1;
    }
    final displayStep = _stepIndex + 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.initialCampaign == null ? 'Create Offer' : 'Edit Offer'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Step $displayStep of ${steps.length}',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: SingleChildScrollView(
                      key: ValueKey(_currentStep),
                      padding: const EdgeInsets.only(bottom: 80),
                      child: _buildStepContent(menuState),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20, top: 8),
                  child: _buildNavigationRow(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_FormStep> get _steps => _requiresProductSelection(_offerType)
      ? const [_FormStep.type, _FormStep.rules, _FormStep.details]
      : const [_FormStep.type, _FormStep.details];

  _FormStep get _currentStep => _steps[_stepIndex];

  Widget _buildStepContent(MenuState menuState) {
    switch (_currentStep) {
      case _FormStep.type:
        return _buildTypeStep();
      case _FormStep.rules:
        return _buildRulesStep(menuState);
      case _FormStep.details:
        return _buildDetailsStep();
    }
  }

  Widget _buildTypeStep() {
    const highlight = Color(0xFF54A079);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select offer type',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Column(
          children: _offerTypeOptions.map((option) {
            final selected = option.value == _offerType;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    _offerType = option.value;
                    if (!_requiresProductSelection(option.value)) {
                      _productRules.clear();
                    }
                    _stepIndex = 0;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected ? highlight.withOpacity(0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? highlight : Colors.grey.shade300,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? const Color(0xFF1B5E3F)
                                        : null,
                                  ),
                            ),
                            if (selected && option.subtitle != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                option.subtitle!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRulesStep(MenuState menuState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose products',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          'Select items that qualify for this offer. Tap any item to configure the rule. Long press the selected item to remove it.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (menuState.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (menuState.items.isEmpty)
          const _InfoPlaceholder(
            icon: Icons.inventory_2_outlined,
            message: 'No products available. Add menu items first.',
          )
        else
          _CategorisedProductList(
            menuState: menuState,
            selectedRules: _productRules,
            onSelect: _onProductSelection,
            ruleSummaryBuilder: _ruleSummary,
          ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Offer details',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Offer name'),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Name required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(labelText: 'Description'),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DateField(
                label: 'Starts',
                value: _startAt,
                onChanged: (value) => setState(() => _startAt = value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateField(
                label: 'Ends',
                value: _endAt,
                onChanged: (value) => setState(() => _endAt = value),
              ),
            ),
          ],
        ),
        if (_offerType == 'HAPPY_HOUR') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TimeField(
                  label: 'Happy hour start',
                  value: _happyHourStart,
                  onChanged: (value) => setState(() => _happyHourStart = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeField(
                  label: 'Happy hour end',
                  value: _happyHourEnd,
                  onChanged: (value) => setState(() => _happyHourEnd = value),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _minAmountController,
                decoration:
                    const InputDecoration(labelText: 'Min order amount'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _valueController,
                decoration: InputDecoration(
                  labelText: _offerType == 'ORDER_PERCENTAGE'
                      ? 'Discount %'
                      : 'Discount value',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _priorityController,
          decoration: const InputDecoration(labelText: 'Priority'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Apply per unit'),
          subtitle:
              const Text('Use the discount value for every qualified unit'),
          value: _applyPerUnit,
          onChanged: (value) => setState(() => _applyPerUnit = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Active'),
          subtitle: const Text('Only one campaign can be active at a time.'),
          value: _isActive,
          onChanged: (value) => setState(() => _isActive = value),
        ),
      ],
    );
  }

  Widget _buildNavigationRow() {
    final isFirst = _stepIndex == 0;
    final isLast = _currentStep == _FormStep.details;

    return Row(
      children: [
        TextButton(
          onPressed: () {
            if (isFirst) {
              Navigator.pop(context);
            } else {
              setState(() => _stepIndex -= 1);
            }
          },
          child: Text(isFirst ? 'Cancel' : 'Back'),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _submitting ? null : _handleNext,
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isLast ? 'Save campaign' : 'Next'),
        ),
      ],
    );
  }

  void _handleNext() {
    switch (_currentStep) {
      case _FormStep.type:
        if (_requiresProductSelection(_offerType)) {
          setState(() => _stepIndex = 1);
        } else {
          setState(() => _stepIndex = _steps.length - 1);
        }
        break;
      case _FormStep.rules:
        if (_productRules.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select at least one product.')),
          );
          return;
        }
        setState(() => _stepIndex += 1);
        break;
      case _FormStep.details:
        _submit();
        break;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_startAt != null && _endAt != null && _startAt!.isAfter(_endAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start date must be before end date.')),
      );
      return;
    }
    if (_requiresProductSelection(_offerType) && _productRules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one rule.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final minAmount = double.tryParse(_minAmountController.text.trim());
      final value = double.tryParse(_valueController.text.trim());
      final priority = int.tryParse(_priorityController.text.trim()) ?? 1;

      final campaign = OfferCampaign(
        campaignId: widget.initialCampaign?.campaignId,
        outletId: widget.initialCampaign?.outletId,
        name: _nameController.text.trim(),
        offerType: _offerType,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        startAt: _startAt,
        endAt: _endAt,
        minOrderAmount: minAmount,
        value: value,
        applyPerUnit: _applyPerUnit,
        happyHourStart: _happyHourStart != null
            ? _formatTime(_happyHourStart!)
            : widget.initialCampaign?.happyHourStart,
        happyHourEnd: _happyHourEnd != null
            ? _formatTime(_happyHourEnd!)
            : widget.initialCampaign?.happyHourEnd,
        isActive: _isActive,
        priority: priority,
        rules: _productRules.values.toList(),
        createdAt: widget.initialCampaign?.createdAt,
        updatedAt: DateTime.now(),
      );

      if (!mounted) return;
      final patch = _buildPatchPayload(widget.initialCampaign, campaign);
      Navigator.pop(
        context,
        OfferEditorResult(
          campaign: campaign,
          patch: widget.initialCampaign == null ? null : patch,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _onProductSelection(
    Map<String, dynamic> product,
    bool shouldSelect,
  ) async {
    final productId = product['id'].toString();
    if (shouldSelect) {
      final rule =
          await _openRuleDialog(product, existing: _productRules[productId]);
      if (rule != null) {
        setState(() => _productRules[productId] = rule);
      }
    } else {
      setState(() => _productRules.remove(productId));
    }
  }

  Future<OfferRule?> _openRuleDialog(
    Map<String, dynamic> product, {
    OfferRule? existing,
  }) async {
    final name = (product['name'] ?? 'Product').toString();
    final productId = product['id'].toString();
    final minController =
        TextEditingController(text: existing?.minQuantity?.toString() ?? '');
    final freeController =
        TextEditingController(text: existing?.freeQuantity?.toString() ?? '');
    final overrideController =
        TextEditingController(text: existing?.overrideValue?.toString() ?? '');
    bool applyPerUnit = existing?.applyPerUnit ?? true;
    String? errorMessage;

    final result = await showDialog<OfferRule>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Configure $name'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: minController,
                  decoration:
                      const InputDecoration(labelText: 'Minimum quantity'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: freeController,
                  decoration: const InputDecoration(
                      labelText: 'Free quantity (optional)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: overrideController,
                  decoration: const InputDecoration(
                      labelText: 'Override value (optional)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Apply per unit'),
                  value: applyPerUnit,
                  onChanged: (value) => setState(() => applyPerUnit = value),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final minQuantity = int.tryParse(minController.text.trim());
                if (minQuantity == null || minQuantity <= 0) {
                  setState(() => errorMessage =
                      'Enter a valid minimum quantity greater than zero.');
                  return;
                }

                final freeText = freeController.text.trim();
                final freeQuantity =
                    freeText.isEmpty ? null : int.tryParse(freeText);
                if (freeText.isNotEmpty && freeQuantity == null) {
                  setState(() => errorMessage =
                      'Enter a valid number for free quantity or leave blank.');
                  return;
                }

                final overrideText = overrideController.text.trim();
                final overrideValue =
                    overrideText.isEmpty ? null : double.tryParse(overrideText);
                if (overrideText.isNotEmpty && overrideValue == null) {
                  setState(() => errorMessage =
                      'Enter a valid number for override value or leave blank.');
                  return;
                }

                Navigator.pop(
                  context,
                  OfferRule(
                    ruleId: existing?.ruleId,
                    productId: productId,
                    productName: name,
                    minQuantity: minQuantity,
                    freeQuantity: freeQuantity,
                    overrideValue: overrideValue,
                    overrideType: existing?.overrideType,
                    applyPerUnit: applyPerUnit,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    return result;
  }

  bool _requiresProductSelection(String type) {
    return type == 'ITEM_FLAT' || type == 'BUY_X_GET_Y';
  }

  TimeOfDay? _parseTime(String value) {
    if (value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _ruleSummary(OfferRule rule) {
    final parts = <String>[];
    if (rule.minQuantity != null) {
      parts.add('Min qty ${rule.minQuantity}');
    }
    if (rule.freeQuantity != null && rule.freeQuantity! > 0) {
      parts.add('Free ${rule.freeQuantity}');
    }
    if (rule.overrideValue != null) {
      parts.add('Override ₹${rule.overrideValue!.toStringAsFixed(0)}');
    }
    return parts.isEmpty ? 'Tap to configure rule' : parts.join(' · ');
  }

  String _formatTime(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }
}

class _OfferTypeOption {
  final String value;
  final String title;
  final String? subtitle;

  const _OfferTypeOption(this.value, this.title, [this.subtitle]);
}

const List<_OfferTypeOption> _offerTypeOptions = [
  _OfferTypeOption(
    'ITEM_FLAT',
    'Flat per item discount',
    'Specify eligible products and reduce their price by a flat amount.',
  ),
  _OfferTypeOption(
    'ORDER_FLAT',
    'Flat order discount',
    'Reduce the final bill by a fixed amount when criteria are met.',
  ),
  _OfferTypeOption(
    'ORDER_PERCENTAGE',
    'Order percentage discount',
    'Apply a percentage discount on qualifying orders.',
  ),
  _OfferTypeOption(
    'HAPPY_HOUR',
    'Happy hours discount',
    'Offer time-bound discounts during specific hours of the day.',
  ),
  _OfferTypeOption(
    'BUY_X_GET_Y',
    'Buy X get Y',
    'Reward customers with free items after buying a threshold quantity.',
  ),
];

class _CategorisedProductList extends StatelessWidget {
  const _CategorisedProductList({
    required this.menuState,
    required this.selectedRules,
    required this.onSelect,
    required this.ruleSummaryBuilder,
  });

  final MenuState menuState;
  final Map<String, OfferRule> selectedRules;
  final Future<void> Function(Map<String, dynamic>, bool) onSelect;
  final String Function(OfferRule) ruleSummaryBuilder;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> groupedItems = {};
    for (final item in menuState.items) {
      final categoryId = item['category_id']?.toString() ?? 'uncategorized';
      groupedItems.putIfAbsent(categoryId, () => []).add(item);
    }

    final visibleCategories = menuState.categories
        .where((cat) => cat['category_id'] != 'all')
        .where((cat) {
      final id = cat['category_id']?.toString();
      final items = groupedItems[id];
      return items != null && items.isNotEmpty;
    }).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visibleCategories.length,
      itemBuilder: (context, index) {
        final category = visibleCategories[index];
        final categoryId = category['category_id'].toString();
        final products = groupedItems[categoryId] ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                category['name']?.toString() ?? 'Category',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            ...products.map((item) {
              final productId = item['id'].toString();
              final name = (item['name'] ?? 'Product').toString();
              final selected = selectedRules.containsKey(productId);
              final rule = selectedRules[productId];
              return _ProductSelectTile(
                name: name,
                selected: selected,
                summary: rule == null
                    ? 'Tap to configure rule'
                    : ruleSummaryBuilder(rule),
                onSelect: () => onSelect(item, true),
                onRemove: selected ? () => onSelect(item, false) : null,
              );
            }),
          ],
        );
      },
    );
  }
}

class _InfoPlaceholder extends StatelessWidget {
  const _InfoPlaceholder({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey[500]),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ProductSelectTile extends StatelessWidget {
  const _ProductSelectTile({
    required this.name,
    required this.selected,
    required this.summary,
    required this.onSelect,
    this.onRemove,
  });

  final String name;
  final bool selected;
  final String summary;
  final VoidCallback onSelect;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final highlight = const Color(0xFF54A079);
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(14),
      onLongPress: selected && onRemove != null ? onRemove : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? highlight.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? highlight : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (selected && onRemove != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Long press to remove',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                    ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: selected
                  ? Icon(Icons.check_circle,
                      color: highlight, key: const ValueKey('selected'))
                  : Icon(
                      Icons.radio_button_unchecked,
                      color: Colors.grey.shade400,
                      key: const ValueKey('unselected'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('d MMM yyyy · HH:mm');
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final initialDate = value ?? now;
        final date = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 2),
        );
        if (date == null) return;
        final time = await showTimePicker(
          context: context,
          initialTime: value != null
              ? TimeOfDay.fromDateTime(value!)
              : TimeOfDay.fromDateTime(now),
        );
        if (time == null) {
          onChanged(DateTime(date.year, date.month, date.day));
          return;
        }
        final combined =
            DateTime(date.year, date.month, date.day, time.hour, time.minute);
        onChanged(combined);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
            value != null ? formatter.format(value!.toLocal()) : 'Select date'),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final result = await showTimePicker(
          context: context,
          initialTime: value ?? TimeOfDay.now(),
        );
        onChanged(result);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value != null ? value!.format(context) : 'Select time'),
      ),
    );
  }
}

Map<String, dynamic> _buildPatchPayload(
  OfferCampaign? initial,
  OfferCampaign updated,
) {
  final updatedMap = updated.toJson(includeIdentifiers: true);
  updatedMap.remove('campaign_id');
  _normalizeRulesList(updatedMap);

  if (initial == null) {
    return updatedMap;
  }

  final initialMap = initial.toJson(includeIdentifiers: true);
  initialMap.remove('campaign_id');
  _normalizeRulesList(initialMap);

  final diff = <String, dynamic>{};
  final keys = {...updatedMap.keys, ...initialMap.keys};
  for (final key in keys) {
    final newVal = updatedMap[key];
    final oldVal = initialMap[key];
    if (_deepEquals(newVal, oldVal)) continue;
    diff[key] = newVal;
  }
  return diff;
}

bool _deepEquals(dynamic a, dynamic b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return jsonEncode(a) == jsonEncode(b);
}

void _normalizeRulesList(Map<String, dynamic> map) {
  final rules = map['rules'];
  if (rules is List) {
    final sortable = List.of(rules);
    sortable.sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
    map['rules'] = sortable;
  }
}
