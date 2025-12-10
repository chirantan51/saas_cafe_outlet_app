import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:outlet_app/data/models/subscription_plan.dart';
import 'package:outlet_app/providers/menu_provider.dart';
import 'package:outlet_app/providers/subscription_plans_provider.dart';
import 'package:outlet_app/services/subscription_service.dart';

class CreateSubscriptionPlanScreen extends ConsumerStatefulWidget {
  const CreateSubscriptionPlanScreen({
    super.key,
    this.initialPlan,
    this.isEditMode = false,
  }) : assert(
          !isEditMode || initialPlan != null,
          'initialPlan is required in edit mode',
        );

  final SubscriptionPlan? initialPlan;
  final bool isEditMode;

  @override
  ConsumerState<CreateSubscriptionPlanScreen> createState() =>
      _CreateSubscriptionPlanScreenState();
}

class EditSubscriptionPlanScreen extends CreateSubscriptionPlanScreen {
  const EditSubscriptionPlanScreen({
    super.key,
    required SubscriptionPlan plan,
  }) : super(
          initialPlan: plan,
          isEditMode: true,
        );
}

class _CreateSubscriptionPlanScreenState
    extends ConsumerState<CreateSubscriptionPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _minDaysController = TextEditingController();
  final _dailyLimitController = TextEditingController();
  final _slotMinutesController = TextEditingController();
  final _capacityPerSlotController = TextEditingController();
  final _windowStartController = TextEditingController();
  final _windowEndController = TextEditingController();

  final List<_DiscountTier> _discountTiers = [];
  final List<DateTime> _holidayDates = [];

  String? _selectedProductId;
  String _vegType = 'Veg';
  bool _allowSundays = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.initialPlan;
    if (plan != null) {
      _seedFormFromPlan(plan);
    }
  }

  @override
  void dispose() {
    _minDaysController.dispose();
    _dailyLimitController.dispose();
    _slotMinutesController.dispose();
    _capacityPerSlotController.dispose();
    _windowStartController.dispose();
    _windowEndController.dispose();
    super.dispose();
  }

  void _seedFormFromPlan(SubscriptionPlan plan) {
    _selectedProductId = plan.productId.isNotEmpty ? plan.productId : null;
    _vegType = plan.vegType ?? _vegType;
    _allowSundays = plan.allowSundays ?? false;

    _minDaysController.text = _intToText(plan.minDays);
    _dailyLimitController.text = _intToText(plan.dailyQtyLimit);
    _slotMinutesController.text = _intToText(plan.slotMinutesOverride);
    _capacityPerSlotController.text =
        _intToText(plan.capacityPerSlotOverride);
    _windowStartController.text = _formatInitialTime(plan.windowStartOverride);
    _windowEndController.text = _formatInitialTime(plan.windowEndOverride);

    _discountTiers
      ..clear()
      ..addAll(
        plan.discountTiers
            .map(_discountTierFromPlan)
            .whereType<_DiscountTier>(),
      );

    _holidayDates
      ..clear()
      ..addAll(
        plan.holidaysList.map(_parseHolidayDate).whereType<DateTime>(),
      );
  }

  @override
  Widget build(BuildContext context) {
    final menuState = ref.watch(menuProvider);
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final theme = Theme.of(context);

    final products = menuState.items;
    final currentPlanProductId = widget.initialPlan?.productId;
    final subscribedProductIds = plansAsync.maybeWhen(
      data: (plans) => plans
          .map((plan) => plan.productId)
          .where((id) => id.isNotEmpty)
          .toSet(),
      orElse: () => <String>{},
    );

    final shouldResetSelection = !widget.isEditMode &&
        _selectedProductId != null &&
        subscribedProductIds.contains(_selectedProductId);

    if (shouldResetSelection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedProductId = null;
          });
        }
      });
    }

    final canKeepSelection = _selectedProductId != null &&
        (!subscribedProductIds.contains(_selectedProductId) ||
            (widget.isEditMode &&
                _selectedProductId == currentPlanProductId));
    final effectiveSelectedProductId =
        canKeepSelection ? _selectedProductId : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditMode
              ? 'Edit subscription plan'
              : 'Create subscription plan',
        ),
        actions: [
          if (widget.isEditMode && widget.initialPlan != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete plan',
              onPressed: _isSubmitting ? null : () => _showDeleteConfirmation(context),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : () => _handleSubmit(context),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.isEditMode ? 'Save changes' : 'Create plan'),
          ),
        ),
      ),
      body: SafeArea(
        child: menuState.isLoading && products.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ThemedSectionCard(
                        title: 'Product',
                        icon: Icons.shopping_bag_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select a product to attach to this plan.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Select product',
                                border: OutlineInputBorder(),
                              ),
                              value: effectiveSelectedProductId,
                              items: [
                                ..._missingProductFallbackItem(
                                  context,
                                  effectiveSelectedProductId,
                                  products,
                                ),
                                ...products
                                    .where((product) => product['id'] != null)
                                    .map((product) {
                                  final id = product['id'].toString();
                                  final name =
                                      product['name']?.toString() ?? 'Product';
                                  final isCurrentPlanProduct = widget.isEditMode &&
                                      id == currentPlanProductId;
                                  final isTaken =
                                      subscribedProductIds.contains(id) &&
                                          !isCurrentPlanProduct;
                                  return DropdownMenuItem<String>(
                                    value: id,
                                    enabled: !isTaken,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          fit: FlexFit.loose,
                                          child: Text(
                                            name,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                theme.textTheme.bodyMedium?.copyWith(
                                              color: isTaken
                                                  ? theme.disabledColor
                                                  : null,
                                              fontWeight: isTaken
                                                  ? FontWeight.w500
                                                  : FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (isTaken) const _SubscribedTag(),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (value) => setState(() {
                                if (value == null) {
                                  _selectedProductId = null;
                                } else {
                                  final isCurrentPlanProduct =
                                      widget.isEditMode &&
                                          value == currentPlanProductId;
                                  final isTaken =
                                      subscribedProductIds.contains(value) &&
                                          !isCurrentPlanProduct;
                                  if (!isTaken) {
                                    _selectedProductId = value;
                                  }
                                }
                              }),
                              validator: (value) => value == null
                                  ? 'Please select a product'
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            plansAsync.when(
                              loading: () => const LinearProgressIndicator(
                                minHeight: 4,
                              ),
                              error: (_, __) => Text(
                                'Unable to fetch existing subscriptions. Showing all products.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.orange[700],
                                ),
                              ),
                              data: (plans) {
                                if (plans.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  'Products already linked to a subscription are marked as subscribed and cannot be selected again.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.black54,
                                  ),
                                );
                              },
                            ),
                            if (!menuState.isLoading && products.isEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'No products found. Create a menu item before creating a subscription plan.',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: Colors.orange[700]),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ThemedSectionCard(
                        title: 'Configuration',
                        icon: Icons.tune,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _LabeledTextField(
                                    controller: _minDaysController,
                                    label: 'Minimum days',
                                    hint: 'Eg. 3',
                                    keyboardType: TextInputType.number,
                                    validator: _requireInt,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _LabeledTextField(
                                    controller: _dailyLimitController,
                                    label: 'Daily max quantity',
                                    hint: 'Eg. 50',
                                    keyboardType: TextInputType.number,
                                    validator: _requireInt,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Veg type',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _VegTypeSelector(
                              currentValue: _vegType,
                              onChanged: (value) =>
                                  setState(() => _vegType = value),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      Theme.of(context).primaryColor.withOpacity(0.12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Theme.of(context).primaryColor
                                        .withOpacity(0.12),
                                    child: Icon(
                                      Icons.wb_sunny_outlined,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Allow Sundays',
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: _allowSundays,
                                    activeColor: Theme.of(context).primaryColor,
                                    onChanged: (value) => setState(
                                      () => _allowSundays = value,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ThemedSectionCard(
                        title: 'Delivery time window',
                        icon: Icons.access_time,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Set the earliest and latest delivery times for plan orders.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _TimePickerField(
                                    controller: _windowStartController,
                                    label: 'Start time',
                                    hint: 'Eg. 09:00',
                                    onTap: () => _pickTime(
                                        context, _windowStartController),
                                    validator: _requireNotEmpty,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _TimePickerField(
                                    controller: _windowEndController,
                                    label: 'End time',
                                    hint: 'Eg. 21:00',
                                    onTap: () =>
                                        _pickTime(context, _windowEndController),
                                    validator: _requireNotEmpty,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _LabeledTextField(
                              controller: _slotMinutesController,
                              label: 'Slot minutes',
                              hint: 'Eg. 30',
                              keyboardType: TextInputType.number,
                              validator: _requireInt,
                            ),
                            const SizedBox(height: 16),
                            _LabeledTextField(
                              controller: _capacityPerSlotController,
                              label: 'Capacity per slot',
                              hint: 'Eg. 100',
                              keyboardType: TextInputType.number,
                              validator: _requireInt,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ThemedSectionCard(
                        title: 'Discount tiers',
                        icon: Icons.percent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Encourage longer commitments with tiered savings after specific days.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_discountTiers.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context).primaryColor
                                        .withOpacity(0.16),
                                  ),
                                  color: Theme.of(context).primaryColor
                                      .withOpacity(0.06),
                                ),
                                child: Text(
                                  'No tiers added yet. Add the days threshold and discount value to create one.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF1E3A2F),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (_discountTiers.isNotEmpty)
                              Column(
                                children: [
                                  for (int i = 0;
                                      i < _discountTiers.length;
                                      i++) ...[
                                    _DiscountTierTile(
                                      tier: _discountTiers[i],
                                      onRemove: () {
                                        setState(() {
                                          _discountTiers.removeAt(i);
                                        });
                                      },
                                    ),
                                    if (i != _discountTiers.length - 1)
                                      const SizedBox(height: 12),
                                  ],
                                ],
                              ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: _showAddDiscountTierDialog,
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Add tier'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Theme.of(context).primaryColor,
                                  side: BorderSide(
                                    color: Theme.of(context).primaryColor
                                        .withOpacity(0.4),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ThemedSectionCard(
                        title: 'Holidays',
                        icon: Icons.event_busy_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Block dates when this subscription cannot be delivered.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_holidayDates.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context).primaryColor
                                        .withOpacity(0.16),
                                  ),
                                  color: Theme.of(context).primaryColor
                                      .withOpacity(0.06),
                                ),
                                child: Text(
                                  'No blocked dates yet. Add holidays to prevent orders on those days.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF1E3A2F),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (_holidayDates.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final date in _holidayDates)
                                    Chip(
                                      label: Text(
                                        DateFormat('d MMM yyyy').format(date),
                                      ),
                                      backgroundColor: Theme.of(context).primaryColor
                                          .withOpacity(0.12),
                                      labelStyle:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: const Color(0xFF1E3A2F),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      deleteIconColor: Theme.of(context).primaryColor,
                                      onDeleted: () {
                                        setState(() {
                                          _holidayDates.remove(date);
                                        });
                                      },
                                    ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              children: [
                                ActionChip(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  avatar: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Add holiday',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onPressed: _pickHolidayDate,
                                ),
                                if (_holidayDates.isNotEmpty)
                                  ActionChip(
                                    backgroundColor:
                                        Theme.of(context).primaryColor.withOpacity(
                                      0.12,
                                    ),
                                    avatar: Icon(
                                      Icons.delete_sweep_outlined,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    label: Text(
                                      'Clear all (${_holidayDates.length})',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _holidayDates.clear();
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _missingProductFallbackItem(
    BuildContext context,
    String? selectedProductId,
    List<dynamic> products,
  ) {
    if (!widget.isEditMode ||
        selectedProductId == null ||
        widget.initialPlan == null) {
      return const [];
    }

    final existsInMenu = products.any(
      (product) => product['id']?.toString() == selectedProductId,
    );

    if (existsInMenu) return const [];

    final fallbackLabel =
        widget.initialPlan?.product?.name ?? 'Product $selectedProductId';

    return [
      DropdownMenuItem<String>(
        value: selectedProductId,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$fallbackLabel (unavailable)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 18,
            ),
          ],
        ),
      ),
    ];
  }

  Future<void> _showAddDiscountTierDialog() async {
    final formKey = GlobalKey<FormState>();
    String minDaysText = '';
    String valueText = '';
    String discountType = 'Flat';

    final newTier = await showDialog<_DiscountTier>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.12),
                    child: Icon(
                      Icons.percent,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add discount tier',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Minimum days',
                          hintText: 'Eg. 7',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final text = value?.trim();
                          if (text == null || text.isEmpty) {
                            return 'Enter the minimum number of days';
                          }
                          final parsed = int.tryParse(text);
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                        onSaved: (value) => minDaysText = value!.trim(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Discount value',
                          hintText: 'Eg. 10',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final text = value?.trim();
                          if (text == null || text.isEmpty) {
                            return 'Enter the discount value';
                          }
                          final parsed = double.tryParse(text);
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                        onSaved: (value) => valueText = value!.trim(),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: discountType,
                        decoration: const InputDecoration(
                          labelText: 'Discount type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Flat',
                            child: Text('Flat (₹ off)'),
                          ),
                          DropdownMenuItem(
                            value: 'Percent',
                            child: Text('Percent (% off)'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => discountType = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    formKey.currentState!.save();
                    final minDays = int.parse(minDaysText);
                    final value = double.parse(valueText);
                    Navigator.of(dialogContext).pop(
                      _DiscountTier(
                        minDays: minDays,
                        value: value,
                        discountType: discountType,
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (newTier != null) {
      setState(() {
        _discountTiers.add(newTier);
      });
    }
  }

  Future<void> _pickTime(
      BuildContext context, TextEditingController controller) async {
    final now = TimeOfDay.now();
    final initial = _parseTime(controller.text) ?? now;
    final time = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (time != null) {
      controller.text = time.format(context);
    }
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0].replaceAll(RegExp('[^0-9]'), ''));
    final minute = int.tryParse(parts[1].replaceAll(RegExp('[^0-9]'), ''));
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _pickHolidayDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (selected != null) {
      setState(() {
        _holidayDates.add(selected);
      });
    }
  }

  Future<void> _handleSubmit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final payload = _buildPayload();
      if (widget.isEditMode && widget.initialPlan != null) {
        await SubscriptionService.updatePlan(widget.initialPlan!.id, payload);
      } else {
        await SubscriptionService.createPlan(payload);
      }
      ref.invalidate(subscriptionPlansProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditMode
                ? 'Subscription plan updated'
                : 'Subscription plan created',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditMode
                ? 'Failed to update plan: $e'
                : 'Failed to create plan: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final productName = widget.initialPlan?.product?.name ?? 'this plan';

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.error.withOpacity(0.12),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delete Plan?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete the subscription plan for "$productName"?',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.error.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone. All associated data will be permanently removed.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && widget.initialPlan != null) {
      await _handleDelete(context);
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    setState(() => _isSubmitting = true);
    try {
      await SubscriptionService.deletePlan(widget.initialPlan!.id);

      ref.invalidate(subscriptionPlansProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription plan deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      String errorMessage = e.toString();
      // Remove "Exception: " prefix if present
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring('Exception: '.length);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Map<String, dynamic> _buildPayload() {
    TimeOfDay? parseTime(String value) => _parseTime(value);

    String formatTime(String value) {
      final time = parseTime(value);
      if (time == null) return value;
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    final discountTiers =
        _discountTiers.map((tier) => tier.toJson()).toList();

    final holidays =
        _holidayDates.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();

    return {
      "product_id": _selectedProductId,
      "is_subscribable": true,
      "min_days": int.parse(_minDaysController.text),
      "veg_type": _vegType,
      "allow_sundays": _allowSundays,
      "daily_qty_limit": int.parse(_dailyLimitController.text),
      "slot_minutes_override": int.parse(_slotMinutesController.text),
      "capacity_per_slot_override": int.parse(_capacityPerSlotController.text),
      "window_start_override": formatTime(_windowStartController.text),
      "window_end_override": formatTime(_windowEndController.text),
      "discount_tiers": discountTiers,
      "holidays_list": holidays,
    };
  }

  String? _requireInt(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    if (int.tryParse(value.trim()) == null) {
      return 'Enter a valid number';
    }
    return null;
  }

  String _intToText(int? value) => value == null ? '' : value.toString();

  String _formatInitialTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final segments = raw.split(':');
    if (segments.length < 2) return raw;
    final hour = int.tryParse(segments[0]);
    final minute = int.tryParse(segments[1]);
    if (hour == null || minute == null) return raw;
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  _DiscountTier? _discountTierFromPlan(SubscriptionDiscountTier tier) {
    final minDays = tier.qty;
    final percent = tier.percentOff;
    final flat = tier.flatOff;
    if (minDays == null) return null;

    if (flat != null) {
      return _DiscountTier(
        minDays: minDays,
        value: flat,
        discountType: 'Flat',
      );
    }

    if (percent != null) {
      return _DiscountTier(
        minDays: minDays,
        value: percent,
        discountType: 'Percent',
      );
    }

    return null;
  }

  DateTime? _parseHolidayDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String? _requireNotEmpty(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }
}

class _ThemedSectionCard extends StatelessWidget {
  const _ThemedSectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.08),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.12),
                child: Icon(
                  icon,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  const _LabeledTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
  }
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.controller,
    required this.label,
    required this.onTap,
    this.hint,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final VoidCallback onTap;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.schedule),
      ),
    );
  }
}

class _DiscountTier {
  const _DiscountTier({
    required this.minDays,
    required this.value,
    required this.discountType,
  });

  final int minDays;
  final double value;
  final String discountType;

  Map<String, dynamic> toJson() {
    return {
      "value": value,
      "min_days": minDays,
      "discount_type": discountType,
    };
  }
}

class _DiscountTierTile extends StatelessWidget {
  const _DiscountTierTile({required this.tier, required this.onRemove});

  final _DiscountTier tier;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedValue = tier.discountType == 'Flat'
        ? '₹${_formatNumber(tier.value)} off'
        : '${_formatNumber(tier.value)}% off';
    final typeLabel =
        tier.discountType == 'Flat' ? 'Flat discount' : 'Percent discount';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.14),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.12),
            child: Icon(
              Icons.percent,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Min ${tier.minDays} days',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E3A2F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedValue,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  typeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove tier',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
            color: theme.colorScheme.error.withOpacity(0.9),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
}

class _SubscribedTag extends StatelessWidget {
  const _SubscribedTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Subscribed',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}

class _VegTypeSelector extends StatelessWidget {
  const _VegTypeSelector({
    required this.currentValue,
    required this.onChanged,
  });

  final String currentValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildTile(theme, context, 'Veg', Icons.eco_outlined),
        const SizedBox(height: 10),
        _buildTile(theme, context, 'Non-Veg', Icons.restaurant_outlined),
        const SizedBox(height: 10),
        _buildTile(theme, context, 'Egg', Icons.egg_alt_outlined),
      ],
    );
  }

  Widget _buildTile(ThemeData theme, BuildContext context, String label, IconData icon) {
    final isSelected = currentValue == label;
    return InkWell(
      onTap: () => onChanged(label),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Theme.of(context).primaryColor.withOpacity(0.12),
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).primaryColor
                  .withOpacity(isSelected ? 0.2 : 0.12),
              child: Icon(
                icon,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E3A2F),
                ),
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
