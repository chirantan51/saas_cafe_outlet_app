import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outlet_app/data/models/order_model.dart';

import 'package:outlet_app/data/models/outlet_customer.dart';
import 'package:outlet_app/data/models/plan_subscription.dart';
import 'package:outlet_app/data/models/subscription_plan.dart';
import 'package:outlet_app/data/models/subscription_models.dart';
import 'package:outlet_app/providers/dashboard_refresh_provider.dart';
import 'package:outlet_app/providers/menu_provider.dart';
import 'package:outlet_app/services/customer_service.dart';
import 'package:outlet_app/services/order_service.dart' as order_service;
import 'package:outlet_app/services/subscription_service.dart';
import 'package:outlet_app/utils/navigation_helpers.dart';
import 'package:intl/intl.dart';

const String _deliveryTypeDelivery = 'delivery';
const String _deliveryTypeSelfPickup = 'pickup';
const String _deliveryTypeDineIn = 'dine_in';

class SubscriptionCreateSubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionCreateSubscriptionScreen({
    super.key,
    this.isEditMode = false,
    this.order,
    this.isRescheduleMode = false,
    this.existingSubscriptionId,
    this.existingDays,
    this.originalTotalQuantity,
    this.subscription,
    this.subscriptionPlan,
  });

  // New: indicate whether screen is used to edit an existing order
  final bool isEditMode;

  // New: when isEditMode == true this holds the order to edit
  final OrderModel? order;

  // Reschedule mode fields
  final bool isRescheduleMode;
  final int? existingSubscriptionId;
  final List<Map<String, dynamic>>?
      existingDays; // List of {date: DateTime, qty: int, id: int}
  final int? originalTotalQuantity;
  final PlanSubscription? subscription;

  // Subscription plan (passed from SubscriptionPlanDetailScreen)
  final SubscriptionPlan? subscriptionPlan;

  @override
  ConsumerState<SubscriptionCreateSubscriptionScreen> createState() =>
      _SubscriptionCreateSubscriptionScreenState();
}

class _SubscriptionCreateSubscriptionScreenState
    extends ConsumerState<SubscriptionCreateSubscriptionScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final TextEditingController _customerSearchController =
      TextEditingController();
  final TextEditingController _orderCommentController = TextEditingController();
  final ScrollController _customerScrollController = ScrollController();

  List<OutletCustomer> _customers = [];
  bool _customersLoading = false;
  String? _customersError;
  String _customerSearchQuery = '';
  OutletCustomer? _selectedCustomer;
  OutletCustomerAddress? _selectedAddress;
  String? _selectedAddressId;
  String? _manualAddressId;

  final List<_SelectedOrderItem> _orderItems = [];

  String _deliveryType = _deliveryTypeDelivery;

  String _selectedMedium = 'StoreVisit';
  String _selectedPaymentMethod = 'Cash';
  String _selectedPaymentStatus = 'Pending';
  bool _isSubmitting = false;
  order_service.ManualOrderQuote? _quote;
  bool _quoteLoading = false;
  String? _quoteError;

  // Calendar selection tracking
  int _totalDaysSelected = 0;
  int _totalUnitsSelected = 0;
  Map<DateTime, int> _selectedDatesWithQuantities = {};
  Map<DateTime, int> _originalSchedule =
      {}; // Store original schedule for edit mode
  String? _selectedTimeSlot;

  // Subscription plan data
  SubscriptionPlan? _subscriptionPlan;
  String? _productId;
  int? _minDays;

  static const _manualOrderMediums = ['StoreVisit', 'Call', 'WhatsApp'];
  static const _paymentMethodOptions = <_PaymentMethodOption>[
    _PaymentMethodOption(value: 'Cash', label: 'Cash on Delivery'),
    _PaymentMethodOption(value: 'Online', label: 'Online'),
    _PaymentMethodOption(value: 'Card', label: 'Card'),
  ];
  static const _paymentStatuses = ['Pending', 'Paid', 'Refunded'];

  // Local copies for reuse in the state
  late bool _isEditMode;
  OrderModel? _editingOrder;

  @override
  void initState() {
    super.initState();
    // initialize edit mode and order if provided
    _isEditMode = widget.isEditMode;
    _editingOrder = widget.order;

    //TODO Fix Issue:
    if (_isEditMode)
      _selectedTimeSlot = widget.subscription?.delivery_slot_label;

    // if (_isEditMode)
    //   _subscriptionPlan = widget.subscription;

    // If editing, prefill a few basic fields from the provided order.
    if (_isEditMode && _editingOrder != null) {
      _deliveryType = _editingOrder?.deliveryType ?? _deliveryType;
      // _orderCommentController.text = _editingOrder?.comments ?? '';
      _selectedPaymentMethod =
          _editingOrder?.paymentMethod ?? _selectedPaymentMethod;
      _selectedPaymentStatus =
          _editingOrder?.paymentStatus ?? _selectedPaymentStatus;

      // Note: mapping order.customer -> OutletCustomer or order.items -> _SelectedOrderItem
      // requires more detailed conversions and is intentionally left out here.
      // Populate those when you have the exact fields available / mapping logic.
    }

    if (_isEditMode && _editingOrder != null) {
      _deliveryType = _editingOrder?.deliveryType ?? _deliveryType;
      // _orderCommentController.text = _editingOrder?.comments ?? '';
      _selectedPaymentMethod =
          _editingOrder?.paymentMethod ?? _selectedPaymentMethod;
      _selectedPaymentStatus =
          _editingOrder?.paymentStatus ?? _selectedPaymentStatus;

      // Populate _orderItems when editing an existing order
      final items = _editingOrder!.items;
      if (items != null) {
        for (final raw in items) {
          try {
            final Map<String, dynamic> itemMap = raw is Map
                ? (raw as Map).cast<String, dynamic>()
                : {
                    'product_id':
                        (raw as dynamic).productId ?? (raw as dynamic).product,
                    'product_name':
                        (raw as dynamic).productName ?? (raw as dynamic).name,
                    'quantity': (raw as dynamic).quantity,
                    'variant_id': (raw as dynamic).variantId ??
                        (raw as dynamic).variant_id,
                    'variant_name': (raw as dynamic).variantName,
                    'unit_price':
                        (raw as dynamic).price ?? (raw as dynamic).price,
                    'customizations': (raw as dynamic).customizations,
                    'image': "",
                    //'image': (raw as dynamic).image ?? (raw as dynamic).displayImage,
                  };

            final productId = (itemMap['product_id'] ??
                    itemMap['product'] ??
                    itemMap['productId'])
                ?.toString();
            if (productId == null || productId.isEmpty) continue;

            final productName = (itemMap['product_name'] ??
                        itemMap['name'] ??
                        itemMap['productName'])
                    ?.toString() ??
                'Product';
            final quantity =
                int.tryParse(itemMap['quantity']?.toString() ?? '') ?? 1;
            final variantId = (itemMap['variant_id'] ??
                    itemMap['variantId'] ??
                    itemMap['variant'])
                ?.toString();
            final variantName =
                (itemMap['variant_name'] ?? itemMap['variantName'])?.toString();
            final unitPrice =
                double.tryParse(itemMap['unit_price']?.toString() ?? '') ??
                    double.tryParse(itemMap['price']?.toString() ?? '');

            String note = '';
            final cust = itemMap['customizations'];
            if (cust is String) {
              note = cust;
            } else if (cust is Iterable) {
              note =
                  cust.map((e) => e?.toString()).whereType<String>().join(', ');
            } else if (cust is Map) {
              note = cust.values
                  .map((e) => e?.toString())
                  .whereType<String>()
                  .join(', ');
            }

            final newItem = _SelectedOrderItem(
              productId: productId,
              productName: productName,
              unitPrice: unitPrice,
              imageUrl:
                  (itemMap['image'] ?? itemMap['display_image'])?.toString(),
              variantId: variantId,
              variantName: variantName,
            );
            newItem.quantityController.text = quantity.toString();
            newItem.customizationsController.text = note;
            _orderItems.add(newItem);
          } catch (error) {
            int test = 1;
            // ignore malformed item and continue
          }
        }
      }
    }

    _customerSearchController.addListener(() {
      final next = _customerSearchController.text.trim().toLowerCase();
      if (next != _customerSearchQuery) {
        setState(() => _customerSearchQuery = next);
        if (_customerScrollController.hasClients) {
          _customerScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
    });
    _loadCustomers();

    // Initialize reschedule mode or edit mode if applicable
    if ((widget.isRescheduleMode || _isEditMode) &&
        widget.existingDays != null) {
      final today = DateTime.now();
      final todayNormalized = DateTime(today.year, today.month, today.day);

      // Pre-populate selected dates with quantities (only upcoming days)
      for (final day in widget.existingDays!) {
        final date = day['date'] as DateTime?;
        final qty = day['qty'] as int?;
        if (date != null && qty != null && qty > 0) {
          final normalizedDate = DateTime(date.year, date.month, date.day);

          // Only include upcoming days (exclude today and past)
          if (normalizedDate.isAfter(todayNormalized)) {
            _selectedDatesWithQuantities[normalizedDate] = qty;
            _originalSchedule[normalizedDate] =
                qty; // Store original for comparison
          }
        }
      }
      _totalDaysSelected = _selectedDatesWithQuantities.length;
      _totalUnitsSelected = _selectedDatesWithQuantities.values
          .fold<int>(0, (sum, qty) => sum + qty);
    }

    // run after the first frame so widgets are built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // only when opened in edit mode and an order is provided
      if (_isEditMode && _editingOrder != null) {
        final maybeCustomer = getCustomerFromId(_editingOrder!.customer_id);
        if (maybeCustomer != null) {
          _onSelectCustomer(maybeCustomer);
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _customerSearchController.dispose();
    _orderCommentController.dispose();
    _customerScrollController.dispose();
    for (final item in _orderItems) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _customersLoading = true;
      _customersError = null;
    });
    try {
      final page = await CustomerService.fetchCustomers(page: 1);
      setState(() {
        _customers = page.results;
        _selectedCustomer = widget.subscription != null
            ? getCustomerFromId(widget.subscription!.customer.customer_id)
            : null;
        if (_selectedCustomer != null) {
          _handleNext();
        }
      });
    } catch (error) {
      setState(() {
        _customersError = error.toString();
      });
    } finally {
      setState(() => _customersLoading = false);
    }
  }

  Future<void> _handleCreateCustomer(BuildContext context) async {
    final created = await openCustomerCreateScreen(context);
    if (created == true && mounted) {
      await _loadCustomers();
      if (_customerScrollController.hasClients) {
        _customerScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _onSelectCustomer(OutletCustomer customer) {
    setState(() {
      _selectedCustomer = customer;
      _selectedAddress = null;
      _selectedAddressId = null;
      _manualAddressId = null;
      _quote = null;
      _quoteError = null;
      _quoteLoading = false;
    });
    if (!_isSelfPickup && !_isDineIn) {
      _handleAddressSelection(customer);
    }
  }

  Future<void> _handleAddressSelection(OutletCustomer customer) async {
    if (_isSelfPickup) {
      return;
    }
    final primaryAddress = customer.address;
    final collected = <OutletCustomerAddress>[];
    if (customer.addresses.isNotEmpty) {
      collected.addAll(customer.addresses);
    } else if (primaryAddress != null) {
      collected.add(primaryAddress);
    }

    final previousAddress = _selectedAddress;
    final previousAddressId = _selectedAddressId;
    final previousManualId = _manualAddressId;

    if (collected.isEmpty) {
      final manual = await _promptManualAddress();
      if (manual != null && manual.isNotEmpty) {
        setState(() {
          _manualAddressId = manual;
          _selectedAddressId = manual;
          _selectedAddress = null;
          _quote = null;
          _quoteError = null;
          _quoteLoading = false;
        });
      } else {
        setState(() {
          _manualAddressId = previousManualId;
          _selectedAddressId = previousAddressId;
          _selectedAddress = previousAddress;
          _quote = null;
          _quoteError = null;
          _quoteLoading = false;
        });
      }
      if (_currentStep == 2) {
        _fetchQuote();
      }
      return;
    }

    if (collected.length == 1) {
      setState(() {
        _selectedAddress = collected.first;
        _selectedAddressId = collected.first.id;
        _manualAddressId = null;
        _quote = null;
        _quoteError = null;
        _quoteLoading = false;
      });
      if (_currentStep == 2) {
        _fetchQuote();
      }
      return;
    }

    final selected = await showModalBottomSheet<OutletCustomerAddress>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Select delivery address',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: collected.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final addr = collected[index];
                    final summary = _formatAddress(addr);
                    return ListTile(
                      title: Text(
                        addr.label?.isNotEmpty == true
                            ? addr.label!
                            : 'Address ${index + 1}',
                      ),
                      subtitle:
                          Text(summary.isEmpty ? 'No address detail' : summary),
                      trailing: addr.isPrimary
                          ? const Chip(label: Text('Primary'))
                          : null,
                      onTap: () => Navigator.of(context).pop(addr),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedAddress = selected;
        _selectedAddressId = selected.id;
        _manualAddressId = null;
        _quote = null;
        _quoteError = null;
        _quoteLoading = false;
      });
    } else {
      setState(() {
        _selectedAddress = previousAddress;
        _selectedAddressId = previousAddressId;
        _manualAddressId = previousManualId;
        _quote = null;
        _quoteError = null;
        _quoteLoading = false;
      });
    }

    if (_currentStep == 2) {
      _fetchQuote();
    }
  }

  void _changeSelectedCustomerAddress() {
    final customer = _selectedCustomer;
    if (customer == null || _isSelfPickup) return;
    _handleAddressSelection(customer);
  }

  Future<String?> _promptManualAddress() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter address ID'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'e.g. addr_123',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Use'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return value;
  }

  String _formatAddress(OutletCustomerAddress addr) {
    final parts = <String?>[
      addr.address,
      addr.pinCode,
    ];
    return parts
        .where((part) => part != null && part!.trim().isNotEmpty)
        .map((part) => part!.trim())
        .join(', ');
  }

  bool get _isSelfPickup => _deliveryType == _deliveryTypeSelfPickup;

  bool get _isDineIn => _deliveryType == _deliveryTypeDineIn;

  String? get _selectedAddressSummary {
    if (_isSelfPickup) {
      return 'Pickup (no delivery address needed)';
    }
    if (_isDineIn) {
      return 'Dine-in (no delivery address needed)';
    }
    if (_selectedAddress != null) {
      final summary = _formatAddress(_selectedAddress!);
      final label = _selectedAddress!.label;
      final id = _selectedAddress!.id ?? '';
      if (label != null && label.isNotEmpty) {
        final detail = summary.isEmpty ? id : summary;
        return detail.isEmpty ? label : '$label ($detail)';
      }
      if (summary.isNotEmpty) return summary;
      return id.isEmpty ? null : id;
    }
    if (_manualAddressId != null && _manualAddressId!.isNotEmpty) {
      return 'Manual address: ${_manualAddressId!}';
    }
    return null;
  }

  void _removeOrderItem(_SelectedOrderItem item) {
    setState(() {
      _orderItems.remove(item);
      _quote = null;
      _quoteError = null;
      _quoteLoading = _currentStep == 2;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => item.dispose());
    if (_currentStep == 2) {
      _fetchQuote();
    }
  }

  void _changeQuantity(_SelectedOrderItem item, int delta) {
    final current = int.tryParse(item.quantityController.text) ?? 1;
    final next = current + delta;
    if (next <= 0) {
      _removeOrderItem(item);
    } else {
      setState(() {
        item.quantityController.text = next.toString();
        _quote = null;
        _quoteError = null;
        _quoteLoading = _currentStep == 2;
      });
      if (_currentStep == 2) {
        _fetchQuote();
      }
    }
  }

  List<Map<String, dynamic>> _buildItemsPayload() {
    return _orderItems.map((item) {
      final quantity = int.tryParse(item.quantityController.text) ?? 1;
      final customizations = item.customizations
          .map(
            (instruction) => {
              'quantity': 1,
              'instruction': instruction,
            },
          )
          .toList();
      return {
        'product': item.productId,
        'quantity': quantity,
        if (customizations.isNotEmpty) 'customizations': customizations,
        if ((item.variantId ?? '').isNotEmpty) 'variant_id': item.variantId,
      };
    }).toList();
  }

  Future<void> _fetchQuote() async {
    final customer = _selectedCustomer;
    final addressId = _selectedAddressId;
    final isDelivery = !_isSelfPickup && !_isDineIn;
    final hasAddress = addressId != null && addressId.isNotEmpty;

    if (customer == null ||
        _orderItems.isEmpty ||
        (isDelivery && !hasAddress)) {
      setState(() {
        _quote = null;
        _quoteError = null;
        _quoteLoading = false;
      });
      return;
    }

    final itemsPayload = _buildItemsPayload();
    final comments = _orderCommentController.text.trim();

    setState(() {
      _quoteLoading = true;
      _quoteError = null;
    });

    try {
      final quote = await order_service.fetchManualOrderQuote(
        customerId: customer.customerId,
        addressId: hasAddress ? addressId : null,
        deliveryType: _deliveryType,
        manualOrderMedium: _selectedMedium,
        paymentMethod: _selectedPaymentMethod,
        comments: comments.isEmpty ? null : comments,
        items: itemsPayload,
      );
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _quoteLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _quoteLoading = false;
        _quoteError = error.toString();
        _quote = null;
      });
    }
  }

  _SelectedOrderItem? _findOrderItem(
    String productId, {
    String? variantId,
  }) {
    for (final item in _orderItems) {
      final matchesProduct = item.productId == productId;
      final matchesVariant = (item.variantId ?? '') == (variantId ?? '');
      if (matchesProduct && matchesVariant) return item;
    }
    return null;
  }

  void _addProductWithDetails(
    Map<String, dynamic> product,
    int quantity,
    String? customization,
    Map<String, dynamic>? variant,
  ) {
    final productId = product['id']?.toString();
    if (productId == null || productId.isEmpty) return;
    if (quantity <= 0) return;

    final productName = product['name']?.toString() ?? 'Product';
    final variantId = variant?['variant_id']?.toString() ??
        variant?['id']?.toString() ??
        variant?['slug']?.toString();
    final variantName = variant?['name']?.toString();
    final variantPrice = double.tryParse(variant?['price']?.toString() ?? '');
    final price =
        variantPrice ?? double.tryParse(product['price']?.toString() ?? '');
    final imageUrl = product['display_image']?.toString();
    final note = (customization ?? '').trim();

    setState(() {
      final existing = _findOrderItem(productId, variantId: variantId);
      if (existing != null) {
        final current = int.tryParse(existing.quantityController.text) ?? 0;
        existing.quantityController.text = (current + quantity).toString();
        existing.customizationsController.text = note;
        if (variantId != null) {
          existing.variantId = variantId;
          existing.variantName = variantName;
        }
        if (price != null) {
          existing.unitPrice = price;
        }
      } else {
        final newItem = _SelectedOrderItem(
          productId: productId,
          productName: productName,
          unitPrice: price,
          imageUrl: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
          variantId: variantId,
          variantName: variantName,
        );
        newItem.quantityController.text = quantity.toString();
        newItem.customizationsController.text = note;
        _orderItems.add(newItem);
      }
      _quote = null;
      _quoteError = null;
      _quoteLoading = _currentStep == 2;
    });
    if (_currentStep == 2) {
      _fetchQuote();
    }
  }

  void _updateOrderItemDetails(
    _SelectedOrderItem item,
    int quantity,
    String? customization,
    Map<String, dynamic>? variant,
  ) {
    final trimmed = (customization ?? '').trim();
    if (quantity <= 0) {
      _removeOrderItem(item);
      return;
    }
    setState(() {
      item.quantityController.text = quantity.toString();
      item.customizationsController.text = trimmed;
      if (variant != null) {
        final newVariantId = variant['variant_id']?.toString() ??
            variant['id']?.toString() ??
            variant['slug']?.toString();
        item.variantId = newVariantId;
        item.variantName = variant['name']?.toString();
        final updatedPrice =
            double.tryParse(variant['price']?.toString() ?? '');
        if (updatedPrice != null) {
          item.unitPrice = updatedPrice;
        }
      }
      _quote = null;
      _quoteError = null;
      _quoteLoading = _currentStep == 2;
    });
    if (_currentStep == 2) {
      _fetchQuote();
    }
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _setDeliveryType(String value) {
    if (_deliveryType == value) return;
    setState(() {
      _deliveryType = value;
      if (_isSelfPickup || _isDineIn) {
        _selectedAddress = null;
        _selectedAddressId = null;
        _manualAddressId = null;
      }
      _quote = null;
      _quoteError = null;
      _quoteLoading = _currentStep == 2;
    });

    if (value == _deliveryTypeDelivery && _selectedCustomer != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleAddressSelection(_selectedCustomer!);
      });
    } else if (_currentStep == 2) {
      _fetchQuote();
    }
  }

  void _setManualOrderMedium(String value) {
    final shouldFetch = _currentStep == 2 && _selectedMedium != value;
    setState(() {
      _selectedMedium = value;
      if (shouldFetch) {
        _quote = null;
        _quoteError = null;
        _quoteLoading = false;
      }
    });
    if (shouldFetch) {
      _fetchQuote();
    }
  }

  void _setPaymentMethod(String value) {
    final shouldFetch = _currentStep == 2 && _selectedPaymentMethod != value;
    setState(() {
      _selectedPaymentMethod = value;
      if (shouldFetch) {
        _quote = null;
        _quoteError = null;
        _quoteLoading = false;
      }
    });
    if (shouldFetch) {
      _fetchQuote();
    }
  }

  void _setPaymentStatus(String value) {
    setState(() => _selectedPaymentStatus = value);
  }

  void _handleBack() {
    if (_currentStep == 0) return;
    _goToStep(_currentStep - 1);
  }

  void _handleCancel(String comment) async {
    bool retval = await order_service.cancelOrder(
      orderId: _editingOrder!.orderId,
      comment: comment,
    );

    if (!mounted) return;
    if (retval) {
      ref.read(dashboardRefreshProvider.notifier).state = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled successfully')),
      );
      Navigator.of(context).pop(false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to cancel the order')),
      );
    }
  }

  void _handleNext() {
    if (_currentStep == 0) {
      if (_selectedCustomer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a customer to continue')),
        );
        return;
      }
      if (!_isSelfPickup && !_isDineIn && (_selectedAddressId ?? '').isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a delivery address')),
        );
        return;
      }
      _goToStep(1);
      return;
    }

    if (_currentStep == 1) {
      // In reschedule mode, validate total units match original (upcoming days only)
      if ((widget.isRescheduleMode || _isEditMode) &&
          _upcomingDaysOriginalTotal > 0) {
        if (_totalUnitsSelected != _upcomingDaysOriginalTotal) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Total units must match original upcoming days ($_upcomingDaysOriginalTotal). Current: $_totalUnitsSelected',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      // In create mode, check minimum dates
      if (!widget.isRescheduleMode && _totalUnitsSelected < _minDays!) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least 5 dates to continue')),
        );
        return;
      }

      _showTimeSlotSelectionDialog();

      // // In reschedule mode, skip time slot selection and go directly to review
      // if (widget.isRescheduleMode) {
      //   _goToStep(2);
      // } else {
      //   _showTimeSlotSelectionDialog();
      // }
      return;
    }

    if (_currentStep == 2) {
      if (_orderItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one product to continue')),
        );
        return;
      }
      for (final item in _orderItems) {
        final quantity = int.tryParse(item.quantityController.text) ?? 0;
        if (quantity <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Quantity for ${item.productName} must be at least 1')),
          );
          return;
        }
      }
      setState(() {
        _quote = null;
        _quoteError = null;
        _quoteLoading = false;
      });
      _goToStep(3);
      _fetchQuote();
      return;
    }

    _handleSubmit();
  }

  void _handleCreateSubscription() async {
    // Validate all required data
    if (!widget.isRescheduleMode && _subscriptionPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription plan not found')),
      );
      return;
    }

    if (!widget.isRescheduleMode && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    if (_selectedDatesWithQuantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select delivery dates')),
      );
      return;
    }

    // In reschedule/edit mode, validate total quantity matches original (upcoming days only)
    if ((widget.isRescheduleMode || _isEditMode) &&
        _upcomingDaysOriginalTotal > 0) {
      final currentTotal = _selectedDatesWithQuantities.values
          .fold<int>(0, (sum, qty) => sum + qty);
      if (currentTotal != _upcomingDaysOriginalTotal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Total quantity must match original upcoming days ($_upcomingDaysOriginalTotal). Current: $currentTotal',
            ),
          ),
        );
        return;
      }
    }

    if (!widget.isRescheduleMode && _selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }

    if (!widget.isRescheduleMode &&
        (_selectedAddressId == null || _selectedAddressId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final dateFormat = DateFormat('yyyy-MM-dd');
    final List<Map<String, dynamic>> daysPayload = [
      for (final entry in _selectedDatesWithQuantities.entries)
        {
          'date': dateFormat.format(entry.key),
          'qty': entry.value,
        }
    ];

    Map<String, String> quoteSlotAssignments = const <String, String>{};

    if (!widget.isRescheduleMode) {
      try {
        quoteSlotAssignments = await _fetchSlotAssignments(
          productId: _subscriptionPlan!.productId,
          customerId: _selectedCustomer!.customerId,
          addressId: _selectedAddressId!,
          days: daysPayload,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch slot assignments: $e')),
        );
        return;
      }
    }

    try {
      // Prepare days array with date, qty, and slot_start
      final List<Map<String, dynamic>> createDays = [];

      for (final entry in _selectedDatesWithQuantities.entries) {
        final dateStr = dateFormat.format(entry.key);
        final dayData = <String, dynamic>{
          'date': dateStr,
          'qty': entry.value,
        };

        if (!widget.isRescheduleMode) {
          final assignedSlot = quoteSlotAssignments[dateStr];
          if (assignedSlot != null && assignedSlot.isNotEmpty) {
            dayData['slot_start'] = assignedSlot;
          } else if (_selectedTimeSlot != null) {
            final fallback =
                _convertTimeSlotToISODateTime(entry.key, _selectedTimeSlot!);
            if (fallback != null) {
              dayData['slot_start'] = fallback;
            }
          }
        }

        createDays.add(dayData);
      }

      // Call the appropriate API based on mode
      if (widget.isRescheduleMode && widget.existingSubscriptionId != null) {
        await SubscriptionService.updateSubscriptionSchedule(
          subscriptionId: widget.existingSubscriptionId!,
          days: createDays,
        );
      } else {
        await SubscriptionService.createSubscription(
          productId: _subscriptionPlan!.productId,
          customerId: _selectedCustomer!.customerId,
          addressId: _selectedAddressId!,
          days: createDays,
          paymentMethod: _selectedPaymentMethod,
          paymentStatus: _selectedPaymentStatus,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isRescheduleMode
                ? 'Subscription rescheduled successfully!'
                : 'Subscription created successfully!',
          ),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );

      // Navigate back to manage-subscriptions screen
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/manage-subscriptions',
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create subscription: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<Map<String, String>> _fetchSlotAssignments({
    required String productId,
    required String customerId,
    required String addressId,
    required List<Map<String, dynamic>> days,
  }) async {
    final quote = await SubscriptionService.fetchSubscriptionQuote(
      productId: productId,
      customerId: customerId,
      addressId: addressId,
      days: days,
      paymentMethod: _selectedPaymentMethod,
      paymentStatus: _selectedPaymentStatus,
    );

    final assignments = <String, String>{};
    for (final perDay in quote.perDay) {
      if (perDay.slotStart.isNotEmpty) {
        assignments[perDay.date] = perDay.slotStart;
      }
    }

    if (assignments.length < days.length) {
      throw Exception('Quote did not return slots for all days');
    }

    return assignments;
  }

  Future<void> _handleUpdateSubscription({
    required int subscriptionId,
    required Map<DateTime, int> newSchedule,
    Map<DateTime, int>? originalSchedule,
    String? slotLabel,
  }) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Build the days array
      final List<Map<String, dynamic>> updateDays = [];
      final dateFormat = DateFormat('yyyy-MM-dd');

      // Track all dates from both schedules
      final allDates = <DateTime>{
        ...newSchedule.keys,
        if (originalSchedule != null) ...originalSchedule.keys,
      };

      for (final date in allDates) {
        final newQty = newSchedule[date] ?? 0;
        final originalQty = originalSchedule?[date] ?? 0;

        // Only include dates that have changed or are being added/removed
        if (newQty != originalQty) {
          updateDays.add({
            'date': dateFormat.format(date),
            'qty': newQty, // qty > 0 upserts, qty = 0 deletes
          });
        }
      }

      // Call the API
      await SubscriptionService.updateSubscription(
        subscriptionId: subscriptionId,
        days: updateDays,
        slotLabel: slotLabel,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Subscription updated successfully!'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );

      // Navigate back
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update subscription: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String? _convertTimeSlotToISODateTime(DateTime date, String timeSlot) {
    // Convert "12:00 PM - 12:30 PM" to ISO datetime like "2024-06-20T08:00:00Z"
    try {
      // Extract start time from slot (format: "HH:MM AM/PM - HH:MM AM/PM")
      final parts = timeSlot.split(' - ');
      if (parts.isEmpty) return null;

      final timeParts = parts[0].trim().split(' ');
      if (timeParts.length != 2) return null;

      final timeComponents = timeParts[0].split(':');
      if (timeComponents.length != 2) return null;

      int hour = int.parse(timeComponents[0]);
      final minute = int.parse(timeComponents[1]);
      final period = timeParts[1].toUpperCase();

      // Convert to 24-hour format
      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }

      // Create DateTime with the date and time
      final dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
        0,
      );

      // Convert to UTC and format as ISO string
      return dateTime.toUtc().toIso8601String();
    } catch (e) {
      return null;
    }
  }

  List<String> _generateTimeSlots({
    required String startTimeStr,
    required String endTimeStr,
    required int slotDurationMinutes,
  }) {
    final List<String> slots = [];

    // Parse start time (format: "HH:mm:ss")
    final startParts = startTimeStr.split(':');
    final startHour = int.parse(startParts[0]);
    final startMinute = int.parse(startParts[1]);

    // Parse end time (format: "HH:mm:ss")
    final endParts = endTimeStr.split(':');
    final endHour = int.parse(endParts[0]);
    final endMinute = int.parse(endParts[1]);

    final baseDate = DateTime(2025, 1, 1);
    final startTime = DateTime(
        baseDate.year, baseDate.month, baseDate.day, startHour, startMinute);
    final endTime = DateTime(
        baseDate.year, baseDate.month, baseDate.day, endHour, endMinute);

    DateTime current = startTime;
    while (current.isBefore(endTime)) {
      final slotEnd = current.add(Duration(minutes: slotDurationMinutes));
      if (slotEnd.isAfter(endTime)) break;

      final startStr = _formatTime(current);
      final endStr = _formatTime(slotEnd);
      slots.add('$startStr - $endStr');

      current = slotEnd;
    }

    return slots;
  }

  List<DateTime> _parseHolidayDates(List<String> holidayStrings) {
    final List<DateTime> holidays = [];
    for (final dateStr in holidayStrings) {
      try {
        final date = DateTime.parse(dateStr);
        holidays.add(DateTime(date.year, date.month, date.day));
      } catch (e) {
        // Ignore invalid date strings
        debugPrint('Failed to parse holiday date: $dateStr');
      }
    }
    return holidays;
  }

  // Calculate total units from upcoming days only (for edit mode)
  int get _upcomingDaysOriginalTotal {
    if (!widget.isRescheduleMode && !_isEditMode) return 0;
    return _originalSchedule.values.fold<int>(0, (sum, qty) => sum + qty);
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  void _showTimeSlotSelectionDialog() {
    // Get time slot configuration from subscription plan or use defaults
    final startTime = _subscriptionPlan?.windowStartOverride ?? '08:00:00';
    final endTime = _subscriptionPlan?.windowEndOverride ?? '20:00:00';
    final slotDuration = _subscriptionPlan?.slotMinutesOverride ?? 60;

    final timeSlots = _generateTimeSlots(
      startTimeStr: startTime,
      endTimeStr: endTime,
      slotDurationMinutes: slotDuration,
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Delivery Time Slot',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose your preferred delivery time',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: timeSlots.length,
                itemBuilder: (context, index) {
                  final theme = Theme.of(context);
                  final slot = timeSlots[index];
                  final isSelected = _selectedTimeSlot == slot;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    //elevation: isSelected ? .5 : 0,
                    color: isSelected ? theme.primaryColor.withOpacity(0.1) : null,
                    child: ListTile(
                      leading: Icon(
                        Icons.access_time,
                        color: isSelected ? theme.primaryColor : Colors.grey,
                      ),
                      title: Text(
                        slot,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? theme.primaryColor : Colors.black,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: theme.primaryColor)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedTimeSlot = slot;
                        });
                        Navigator.pop(context);
                        _goToStep(2);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_selectedCustomer == null) return;
    final addressId = _selectedAddressId ?? '';
    if (!_isSelfPickup && !_isDineIn && addressId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select address before submitting')),
      );
      return;
    }

    final itemsPayload = _buildItemsPayload();
    final comments = _orderCommentController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      if (_isEditMode) {
        await order_service.updateDineInOrder(
          orderId: _editingOrder!.orderId,
          customerId: _selectedCustomer!.customerId,
          deliveryType: _deliveryType,
          items: itemsPayload,
        );
      } else {
        await order_service.createManualOrder(
          customerId: _selectedCustomer!.customerId,
          addressId: addressId.isEmpty ? null : addressId,
          deliveryType: _deliveryType,
          manualOrderMedium: _selectedMedium,
          paymentMethod: _selectedPaymentMethod,
          paymentStatus: _selectedPaymentStatus,
          items: itemsPayload,
          comments: comments.isEmpty ? null : comments,
        );
      }
      if (!mounted) return;
      ref.read(dashboardRefreshProvider.notifier).state = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_isEditMode
                ? 'Order updated successfully'
                : 'Order created successfully')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuState = ref.watch(menuProvider);
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    // Initialize subscription plan from widget or route arguments
    if (_subscriptionPlan == null && widget.subscriptionPlan != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _subscriptionPlan = widget.subscriptionPlan;
          _productId = widget.subscriptionPlan?.productId;
          _minDays = widget.subscriptionPlan?.minDays;
        });
      });
    }

    // Extract route arguments for subscription plan (fallback)
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _subscriptionPlan == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _subscriptionPlan = args['plan'] as SubscriptionPlan?;
          _productId = args['product_id']?.toString();
          _minDays = args['min_days'] as int?;
        });
      });
    }

    OrderModel? order = widget.order;
    bool isEditMode = widget.isEditMode;

    // dart
    final OutletCustomer? maybeCustomer = isEditMode
        ? getCustomerFromId(widget.subscription!.customer.customer_id)
        : null;
    final List<OutletCustomer> filtered_customers_list =
        (isEditMode == true && maybeCustomer != null)
            ? [maybeCustomer]
            : _filteredCustomers;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isRescheduleMode
            ? 'Reschedule Subscription'
            : 'Create Subscription'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                if (!keyboardVisible) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _StepIndicator(currentStep: _currentStep),
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _CustomerSelectionStep(
                        isEditMode: isEditMode,
                        isLoading: _customersLoading,
                        errorMessage: _customersError,
                        customers: filtered_customers_list,
                        selectedCustomer: _selectedCustomer,
                        selectedAddressSummary: _selectedAddressSummary,
                        deliveryType: _deliveryType,
                        onSelectCustomer: _onSelectCustomer,
                        onDeliveryTypeChanged: _setDeliveryType,
                        onChangeAddress: _changeSelectedCustomerAddress,
                        onRetry: _loadCustomers,
                        searchController: _customerSearchController,
                        scrollController: _customerScrollController,
                        onCreateCustomer: () => _handleCreateCustomer(context),
                      ),
                      CalendarDateSelector(
                        minimumDatesToSelect: _minDays ?? 5,
                        onSelectionChanged:
                            (totalDays, totalUnits, selectedDates) {
                          setState(() {
                            _totalDaysSelected = totalDays;
                            _totalUnitsSelected = totalUnits;
                            _selectedDatesWithQuantities = selectedDates;
                          });
                        },
                        maxDaysFromToday: 45, // Show 90 days ahead
                        sundayAllowed: _subscriptionPlan?.allowSundays ?? false,
                        listOfHolidays: _parseHolidayDates(
                            _subscriptionPlan?.holidaysList ?? []),
                        initialSelections: _selectedDatesWithQuantities,
                        isRescheduleMode: widget.isRescheduleMode,
                        originalTotalQuantity: _upcomingDaysOriginalTotal,
                      ),
                      // Step 2: Review
                      _ReviewStep(
                        subscriptionPlan: _subscriptionPlan,
                        selectedCustomer: _selectedCustomer,
                        selectedAddress: _selectedAddress,
                        selectedDatesWithQuantities:
                            _selectedDatesWithQuantities,
                        selectedTimeSlot: _selectedTimeSlot,
                        onCreateSubscription: _handleCreateSubscription,
                        isSubmitting: _isSubmitting,
                        isRescheduleMode: widget.isRescheduleMode,
                        originalTotalQuantity: widget.originalTotalQuantity,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Floating action buttons for Step 0 and 1
            if (_currentStep <= 2 && !keyboardVisible)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    if (_currentStep > 0)
                      Opacity(
                        opacity: 0.85,
                        child: FloatingActionButton(
                          heroTag: 'back_fab',
                          onPressed: _isSubmitting ? null : _handleBack,
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          child: const Icon(Icons.arrow_back),
                        ),
                      )
                    else
                      const SizedBox(width: 56), // Placeholder for alignment

                    // Next button
                    Builder(
                      builder: (context) {
                        // Determine if button should be disabled
                        bool isDisabled = false;
                        Color? buttonColor;

                        if (_isSubmitting) {
                          isDisabled = true;
                        } else if (_currentStep == 1) {
                          // In reschedule/edit mode, check if total units match (upcoming days only)
                          if ((widget.isRescheduleMode || _isEditMode) &&
                              _upcomingDaysOriginalTotal > 0) {
                            if (_totalUnitsSelected !=
                                _upcomingDaysOriginalTotal) {
                              isDisabled = true;
                              buttonColor = Colors.grey;
                            }
                          }
                          // In create mode, check minimum dates
                          else if (!widget.isRescheduleMode &&
                              !_isEditMode &&
                              _totalDaysSelected < _minDays!) {
                            isDisabled = true;
                            buttonColor = Colors.grey;
                          }
                        }

                        return Opacity(
                          opacity: 0.85,
                          child: FloatingActionButton.extended(
                            heroTag: 'next_fab',
                            onPressed: isDisabled
                                ? null
                                : _currentStep == 2
                                    ? (_isEditMode
                                        ? () => _handleUpdateSubscription(
                                              subscriptionId: widget
                                                  .existingSubscriptionId!,
                                              newSchedule:
                                                  _selectedDatesWithQuantities,
                                              originalSchedule:
                                                  _originalSchedule,
                                              slotLabel: _selectedTimeSlot,
                                            )
                                        : _handleCreateSubscription)
                                    : _handleNext,
                            backgroundColor:
                                buttonColor ?? Theme.of(context).primaryColor,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward),
                            label: Text(
                              _isSubmitting
                                  ? 'Loading...'
                                  : _currentStep == 2
                                      ? (_isEditMode || widget.isRescheduleMode
                                          ? 'Update'
                                          : 'Create')
                                      : 'Next',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

            // Original bottom navigation for Step 2
            // if (_currentStep == 2)
            //   Positioned(
            //     left: 0,
            //     right: 0,
            //     bottom: 0,
            //     child: SafeArea(
            //       minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            //       child: Row(
            //         children: [
            //           if (_currentStep > 0)
            //             OutlinedButton(
            //               onPressed: _isSubmitting ? null : _handleBack,
            //               child: const Text('Back'),
            //             ),
            //           if (_currentStep > 0) const SizedBox(width: 12),
            //           Expanded(
            //             child: Row(
            //               children: [
            //                 if (_isEditMode && _currentStep == 2)
            //                   FilledButton(
            //                     onPressed: () {
            //                       _isSubmitting ? null : _handleCancel("");
            //                     },
            //                     style: FilledButton.styleFrom(
            //                       backgroundColor: Colors.red,
            //                     ),
            //                     child: _isSubmitting
            //                         ? const SizedBox(
            //                             height: 18,
            //                             width: 18,
            //                             child: CircularProgressIndicator(
            //                                 strokeWidth: 2),
            //                           )
            //                         : const Text('Cancel'),
            //                   ),
            //                 if (_isEditMode && _currentStep == 2)
            //                   const SizedBox(width: 12),
            //                 Expanded(
            //                   child: FilledButton(
            //                     onPressed: _isSubmitting
            //                         ? null
            //                         : _handleCreateSubscription,
            //                     child: _isSubmitting
            //                         ? const SizedBox(
            //                             height: 18,
            //                             width: 18,
            //                             child: CircularProgressIndicator(
            //                                 strokeWidth: 2),
            //                           )
            //                         : Text('Create Subscription'),
            //                   ),
            //                 ),
            //               ],
            //             ),
            //           ),
            //         ],
            //       ),
            //     ),
            //   ),
          ],
        ),
      ),
    );
  }

  OutletCustomer? getCustomerFromId(String customerId) {
    try {
      return _customers
          .firstWhere((customer) => customer.customerId == customerId);
    } on StateError {
      // No matching customer found in the list
      return null;
    }
  }

  List<OutletCustomer> get _filteredCustomers {
    if (_customerSearchQuery.isEmpty) return _customers;
    return _customers.where((customer) {
      final name = customer.name.toLowerCase();
      final mobile = customer.mobile?.toLowerCase() ?? '';
      final email = customer.email?.toLowerCase() ?? '';
      final address = customer.address;
      final addressText = [
        address?.label,
        address?.address,
        address?.pinCode,
      ]
          .where((value) => value != null && value!.trim().isNotEmpty)
          .map((value) => value!.toLowerCase())
          .join(' ');
      return name.contains(_customerSearchQuery) ||
          mobile.contains(_customerSearchQuery) ||
          email.contains(_customerSearchQuery) ||
          addressText.contains(_customerSearchQuery);
    }).toList();
  }
}

//////////

class CalendarDateSelector extends StatefulWidget {
  final int minimumDatesToSelect;
  final Function(int totalDays, int totalUnits,
      Map<DateTime, int> selectedDatesWithQuantities) onSelectionChanged;
  final int? maxDaysFromToday;
  final bool sundayAllowed;
  final List<DateTime> listOfHolidays;
  final Map<DateTime, int>? initialSelections;
  final bool isRescheduleMode;
  final int? originalTotalQuantity;

  const CalendarDateSelector({
    Key? key,
    this.minimumDatesToSelect = 1,
    required this.onSelectionChanged,
    this.maxDaysFromToday,
    this.sundayAllowed = true,
    this.listOfHolidays = const [],
    this.initialSelections,
    this.isRescheduleMode = false,
    this.originalTotalQuantity,
  }) : super(key: key);

  @override
  State<CalendarDateSelector> createState() => _CalendarDateSelectorState();
}

class _CalendarDateSelectorState extends State<CalendarDateSelector>
    with SingleTickerProviderStateMixin {
  DateTime _currentMonth = DateTime.now();
  final Map<DateTime, int> _dateQuantities = {};
  DateTime? _lastSelectedDate;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Restore initial selections if provided
    if (widget.initialSelections != null &&
        widget.initialSelections!.isNotEmpty) {
      _dateQuantities.addAll(widget.initialSelections!);
      // Set the last selected date to the most recent date in the selections
      _lastSelectedDate =
          widget.initialSelections!.keys.reduce((a, b) => a.isAfter(b) ? a : b);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isDateSelectable(DateTime date) {
    final normalized = _normalizeDate(date);
    final today = _normalizeDate(DateTime.now());

    // Check if date is today or in the past
    if (normalized.isBefore(today) || normalized == today) {
      return false;
    }

    // Check if date exceeds max days from today
    if (widget.maxDaysFromToday != null) {
      final maxDate = today.add(Duration(days: widget.maxDaysFromToday!));
      if (normalized.isAfter(maxDate)) {
        return false;
      }
    }

    // Check if Sunday is allowed
    if (!widget.sundayAllowed && normalized.weekday == DateTime.sunday) {
      return false;
    }

    // Check if date is a holiday
    for (final holiday in widget.listOfHolidays) {
      if (_normalizeDate(holiday) == normalized) {
        return false;
      }
    }

    return true;
  }

  void _notifySelectionChanged() {
    final totalDays = _dateQuantities.length;
    final totalUnits =
        _dateQuantities.values.fold<int>(0, (sum, qty) => sum + qty);
    widget.onSelectionChanged(
        totalDays, totalUnits, Map<DateTime, int>.from(_dateQuantities));
  }

  bool _canGoToPreviousMonth() {
    final today = DateTime.now();
    final currentMonthStart =
        DateTime(_currentMonth.year, _currentMonth.month, 1);
    final todayMonthStart = DateTime(today.year, today.month, 1);
    return currentMonthStart.isAfter(todayMonthStart);
  }

  bool _canGoToNextMonth() {
    if (widget.maxDaysFromToday == null) return true;

    final today = DateTime.now();
    final maxDate = today.add(Duration(days: widget.maxDaysFromToday!));
    final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    final maxMonthStart = DateTime(maxDate.year, maxDate.month, 1);

    return nextMonth.isBefore(maxMonthStart) ||
        nextMonth.isAtSameMomentAs(maxMonthStart);
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final List<DateTime> days = [];

    for (int i = 1; i <= lastDay.day; i++) {
      days.add(DateTime(month.year, month.month, i));
    }

    return days;
  }

  int _getWeekdayOfFirstDay(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    // weekday: Monday=1, Sunday=7
    // Convert to grid offset where Monday=0, Sunday=6
    return firstDay.weekday - 1;
  }

  void _changeMonth(bool isNext) {
    if (isNext && !_canGoToNextMonth()) return;
    if (!isNext && !_canGoToPreviousMonth()) return;

    setState(() {
      _slideAnimation = Tween<Offset>(
        begin: Offset(isNext ? 1.0 : -1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ));

      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + (isNext ? 1 : -1),
      );
    });

    _animationController.forward(from: 0.0);
  }

  void _selectDate(DateTime date) {
    if (!_isDateSelectable(date)) return;

    setState(() {
      final normalized = _normalizeDate(date);
      _lastSelectedDate = normalized;
      if (!_dateQuantities.containsKey(normalized)) {
        _dateQuantities[normalized] = 1;
      }
      _notifySelectionChanged();
    });
  }

  void _updateQuantity(int delta) {
    if (_lastSelectedDate == null) return;
    setState(() {
      final currentQty = _dateQuantities[_lastSelectedDate] ?? 1;
      final newQty = (currentQty + delta).clamp(0, 99);
      if (newQty == 0) {
        _dateQuantities.remove(_lastSelectedDate);
        _lastSelectedDate = null;
      } else {
        _dateQuantities[_lastSelectedDate!] = newQty;
      }
      _notifySelectionChanged();
    });
  }

  void _removeDate(DateTime date) {
    setState(() {
      _dateQuantities.remove(date);
      if (_lastSelectedDate == date) {
        _lastSelectedDate = null;
      }
      _notifySelectionChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = _normalizeDate(DateTime.now());
    final daysInMonth = _getDaysInMonth(_currentMonth);
    final firstDayWeekday = _getWeekdayOfFirstDay(_currentMonth);

    return SingleChildScrollView(
      controller: _scrollController,
      child: Padding(
        padding: const EdgeInsets.only(
            bottom: 100.0), // Add padding for floating button
        child: Column(
          children: [
            // Month navigation
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _canGoToPreviousMonth()
                        ? () => _changeMonth(false)
                        : null,
                  ),
                  Text(
                    '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed:
                        _canGoToNextMonth() ? () => _changeMonth(true) : null,
                  ),
                ],
              ),
            ),

            // Selection info
            if (widget.minimumDatesToSelect > 0)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Builder(
                  builder: (context) {
                    final theme = Theme.of(context);
                    final totalDays = _dateQuantities.length;
                    final totalUnits = _dateQuantities.values
                        .fold<int>(0, (sum, qty) => sum + qty);
                    final meetsMinimum =
                        totalDays >= widget.minimumDatesToSelect;

                    // Check if in reschedule mode and units don't match
                    final bool unitsMatch = !widget.isRescheduleMode ||
                        widget.originalTotalQuantity == null ||
                        totalUnits == widget.originalTotalQuantity;

                    return Column(
                      children: [
                        Text(
                          meetsMinimum
                              ? 'Days: $totalDays, Units: $totalUnits'
                              : 'Select at least ${widget.minimumDatesToSelect} days (Days: $totalDays, Units: $totalUnits)',
                          style: TextStyle(
                            fontSize: 14,
                            color: meetsMinimum
                                ? theme.primaryColor
                                : Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (widget.isRescheduleMode &&
                            widget.originalTotalQuantity != null &&
                            !unitsMatch) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.shade300,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Total units must be ${widget.originalTotalQuantity} to match original subscription',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange.shade900,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),

            // Calendar grid with swipe gesture
            GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity! < 0) {
                  // Swipe left - next month
                  _changeMonth(true);
                } else if (details.primaryVelocity! > 0) {
                  // Swipe right - previous month
                  _changeMonth(false);
                }
              },
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      // Weekday headers (Monday to Sunday)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                            .map((day) => SizedBox(
                                  width: 40,
                                  child: Center(
                                    child: Text(
                                      day,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 8),

                      // Calendar days
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: firstDayWeekday + daysInMonth.length,
                        itemBuilder: (context, index) {
                          if (index < firstDayWeekday) {
                            return const SizedBox.shrink();
                          }

                          final theme = Theme.of(context);
                          final dayIndex = index - firstDayWeekday;
                          final date = daysInMonth[dayIndex];
                          final normalized = _normalizeDate(date);
                          final isToday = normalized == today;
                          final isSelected =
                              _dateQuantities.containsKey(normalized);
                          final quantity = _dateQuantities[normalized];
                          final isLastSelected =
                              _lastSelectedDate == normalized;
                          final isSelectable = _isDateSelectable(date);

                          return GestureDetector(
                            onTap:
                                isSelectable ? () => _selectDate(date) : null,
                            child: Opacity(
                              opacity: isSelectable ? 1.0 : 0.3,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? theme.primaryColor
                                        : isLastSelected
                                            ? Colors.orange
                                            : Colors.transparent,
                                    width: isSelected
                                        ? 2
                                        : (isLastSelected ? 3 : 2),
                                  ),
                                ),
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${date.day}',
                                              style: TextStyle(
                                                color: isSelected
                                                    ? theme.primaryColor
                                                    : Colors.black,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (isSelected && quantity != null)
                                              Text(
                                                'x$quantity',
                                                style: TextStyle(
                                                  color: theme.primaryColor.withValues(alpha: 0.9),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                          ],
                                        ),
                                        // Small orange circle indicator for today
                                        if (isToday)
                                          Positioned(
                                            top: -2,
                                            right: -2,
                                            child: Container(
                                              width: 6,
                                              height: 6,
                                              decoration: const BoxDecoration(
                                                color: Colors.orange,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),

            // Quantity selector for last selected date
            _lastSelectedDate == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Select a date to set quantity',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final theme = Theme.of(context);
                      return Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
                            title: Text(
                              '${_lastSelectedDate!.day} ${_getMonthName(_lastSelectedDate!.month)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              _getDayName(_lastSelectedDate!.weekday),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            trailing: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: theme.primaryColor.withValues(alpha: 0.5), width: 1.5),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: const BorderRadius.horizontal(
                                          left: Radius.circular(30)),
                                      onTap: () => _updateQuantity(-1),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.remove,
                                          color: theme.primaryColor,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    constraints: const BoxConstraints(minWidth: 40),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withValues(alpha: 0.1),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${_dateQuantities[_lastSelectedDate] ?? 1}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: const BorderRadius.horizontal(
                                          right: Radius.circular(30)),
                                      onTap: () => _updateQuantity(1),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.add,
                                          color: theme.primaryColor,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }
}

// Example usage:
// Scaffold(
//   appBar: AppBar(title: const Text('Select Meal Pack Dates')),
//   body: const CalendarDateSelector(),
// )

//////////

class CalendarDateSelector2 extends StatefulWidget {
  const CalendarDateSelector2({Key? key}) : super(key: key);

  @override
  State<CalendarDateSelector2> createState() => _CalendarDateSelectorState2();
}

class _CalendarDateSelectorState2 extends State<CalendarDateSelector2> {
  DateTime _currentMonth = DateTime.now();
  final Set<DateTime> _selectedDates = {};
  final Map<DateTime, int> _dateQuantities = {};

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final List<DateTime> days = [];

    for (int i = 1; i <= lastDay.day; i++) {
      days.add(DateTime(month.year, month.month, i));
    }

    return days;
  }

  int _getWeekdayOfFirstDay(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    return firstDay.weekday % 7; // Convert to 0-6 (Sun-Sat)
  }

  void _toggleDateSelection(DateTime date) {
    setState(() {
      final normalized = _normalizeDate(date);
      if (_selectedDates.contains(normalized)) {
        _selectedDates.remove(normalized);
        _dateQuantities.remove(normalized);
      } else {
        _selectedDates.add(normalized);
        _dateQuantities[normalized] = 1;
      }
    });
  }

  void _updateQuantity(DateTime date, int delta) {
    setState(() {
      final normalized = _normalizeDate(date);
      final currentQty = _dateQuantities[normalized] ?? 1;
      final newQty = (currentQty + delta).clamp(1, 99);
      _dateQuantities[normalized] = newQty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = _normalizeDate(DateTime.now());
    final daysInMonth = _getDaysInMonth(_currentMonth);
    final firstDayWeekday = _getWeekdayOfFirstDay(_currentMonth);

    return Column(
      children: [
        // Month navigation
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _currentMonth =
                        DateTime(_currentMonth.year, _currentMonth.month - 1);
                  });
                },
              ),
              Text(
                '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _currentMonth =
                        DateTime(_currentMonth.year, _currentMonth.month + 1);
                  });
                },
              ),
            ],
          ),
        ),

        // Calendar grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              // Weekday headers (Monday to Sunday)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .map((day) => SizedBox(
                          width: 40,
                          child: Center(
                            child: Text(
                              day,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),

              // Calendar days
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: firstDayWeekday + daysInMonth.length,
                itemBuilder: (context, index) {
                  if (index < firstDayWeekday) {
                    return const SizedBox.shrink();
                  }

                  final dayIndex = index - firstDayWeekday;
                  final date = daysInMonth[dayIndex];
                  final normalized = _normalizeDate(date);
                  final isToday = normalized == today;
                  final isSelected = _selectedDates.contains(normalized);

                  return GestureDetector(
                    onTap: () => _toggleDateSelection(date),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blue
                            : isToday
                                ? Colors.blue.shade50
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday
                            ? Border.all(color: Colors.blue, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? Colors.blue
                                    : Colors.black,
                            fontWeight: isToday || isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        const Divider(),

        // Selected dates with quantity
        Expanded(
          child: _selectedDates.isEmpty
              ? const Center(
                  child: Text(
                    'No dates selected',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _selectedDates.length,
                  itemBuilder: (context, index) {
                    final sortedDates = _selectedDates.toList()
                      ..sort((a, b) => a.compareTo(b));
                    final date = sortedDates[index];
                    final quantity = _dateQuantities[date] ?? 1;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatDate(date),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    _getDayOfWeek(date),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: quantity > 1
                                      ? () => _updateQuantity(date, -1)
                                      : null,
                                  color: Colors.blue,
                                ),
                                Container(
                                  width: 40,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$quantity',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => _updateQuantity(date, 1),
                                  color: Colors.blue,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_getMonthName(date.month)} ${date.year}';
  }

  String _getDayOfWeek(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[date.weekday - 1];
  }
}

class _CustomerSelectionStep extends StatelessWidget {
  const _CustomerSelectionStep({
    this.isEditMode = false,
    required this.isLoading,
    required this.errorMessage,
    required this.customers,
    required this.selectedCustomer,
    required this.selectedAddressSummary,
    required this.deliveryType,
    required this.onSelectCustomer,
    required this.onDeliveryTypeChanged,
    required this.onRetry,
    required this.searchController,
    required this.scrollController,
    required this.onChangeAddress,
    required this.onCreateCustomer,
  });

  final bool isEditMode;
  final bool isLoading;
  final String? errorMessage;
  final List<OutletCustomer> customers;
  final OutletCustomer? selectedCustomer;
  final String? selectedAddressSummary;
  final String deliveryType;
  final void Function(OutletCustomer) onSelectCustomer;
  final ValueChanged<String> onDeliveryTypeChanged;
  final VoidCallback onChangeAddress;
  final VoidCallback onRetry;
  final TextEditingController searchController;
  final ScrollController scrollController;
  final Future<void> Function() onCreateCustomer;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(errorMessage!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    String labelFor(String type) => type == _deliveryTypeSelfPickup
        ? 'Pickup'
        : type == _deliveryTypeDineIn
            ? 'Dine in'
            : 'Delivery';

    final theme = Theme.of(context);

    return CustomScrollView(
      controller: scrollController,
      primary: false,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                const SizedBox(height: 16),
                isEditMode
                    ? Container()
                    : TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Search customers',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (customers.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No customers found'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async => onCreateCustomer(),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Create New'),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final customer = customers[index];
                  final isSelected =
                      selectedCustomer?.customerId == customer.customerId;
                  final fulfilmentText = selectedAddressSummary ??
                      (deliveryType == _deliveryTypeDelivery
                          ? 'No delivery address selected'
                          : 'Pickup/Dine-in :: no delivery address required');

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == customers.length - 1 ? 0 : 12,
                    ),
                    child: Card(
                      color: isSelected
                          ? theme.primaryColorLight
                          : theme.cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => onSelectCustomer(customer),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      customer.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                ],
                              ),
                              if (customer.mobile?.isNotEmpty ?? false) ...[
                                const SizedBox(height: 6),
                                Text('Mobile: ${customer.mobile}'),
                              ],
                              if (customer.email?.isNotEmpty ?? false) ...[
                                const SizedBox(height: 6),
                                Text('Email: ${customer.email}'),
                              ],
                              if (isSelected) ...[
                                const SizedBox(height: 12),
                                Text(
                                  fulfilmentText,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (deliveryType == _deliveryTypeDelivery) ...[
                                  const SizedBox(height: 8),
                                  FilledButton.icon(
                                    onPressed: onChangeAddress,
                                    icon: const Icon(
                                      Icons.location_on_outlined,
                                    ),
                                    label: Text(
                                      selectedAddressSummary == null
                                          ? 'Select address'
                                          : 'Change address',
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: customers.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _MetadataItemRow extends StatelessWidget {
  const _MetadataItemRow({
    required this.item,
    this.quoteLine,
  });

  final _SelectedOrderItem item;
  final order_service.ManualOrderQuoteLine? quoteLine;

  String _formatCurrency(double value) {
    final trimmed = value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '₹$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quantity =
        quoteLine?.quantity ?? int.tryParse(item.quantityController.text) ?? 0;
    final double? unitPrice = quoteLine?.unitPrice ?? item.unitPrice;
    final double? totalPrice = quoteLine?.lineTotalAfterDiscount ??
        (unitPrice != null ? unitPrice * quantity : null);
    String customization = item.customizationsController.text.trim();
    if (quoteLine != null && quoteLine!.customizations.isNotEmpty) {
      final instructions = quoteLine!.customizations
          .map((entry) => entry['instruction']?.toString().trim())
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toList();
      if (instructions.isNotEmpty) {
        customization = instructions.join(', ');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quoteLine?.productName ?? item.productName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if ((item.variantName ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Variant: ${item.variantName!}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (unitPrice != null)
              Text(
                '${_formatCurrency(unitPrice)} x $quantity',
                style: theme.textTheme.bodySmall,
              )
            else
              Text(
                'x $quantity',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(width: 12),
            Text(
              totalPrice != null ? _formatCurrency(totalPrice) : '--',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (customization.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Customization: $customization',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuoteItemRow extends StatelessWidget {
  const _QuoteItemRow({required this.line});

  final order_service.ManualOrderQuoteLine line;

  String _formatCurrency(double value) {
    final trimmed = value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '₹$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quantity = line.quantity;
    final unitPrice = line.unitPrice;
    final totalPrice = line.lineTotalAfterDiscount;
    final variantName = (line.variantName ?? '').trim();
    final customizations = line.customizations
        .map((entry) => entry['instruction']?.toString().trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.productName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (variantName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Variant: $variantName',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '${_formatCurrency(unitPrice)} x $quantity',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(width: 12),
            Text(
              _formatCurrency(totalPrice),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (customizations.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Customization: ${customizations.join(', ')}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuoteSummaryCard extends StatelessWidget {
  const _QuoteSummaryCard({
    required this.quote,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
  });

  final order_service.ManualOrderQuote? quote;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;

  String _formatCurrency(double value) {
    final trimmed = value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '₹$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: const [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Calculating quote...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unable to fetch quote',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                error!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (quote == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quote unavailable',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Add products and select a customer address to calculate totals.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildRow(String label, double value, {bool emphasize = false}) {
      final textStyle = emphasize
          ? Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontWeight: FontWeight.w700)
          : Theme.of(context).textTheme.bodyMedium;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: emphasize
                    ? Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700)
                    : Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              _formatCurrency(value),
              style: textStyle,
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Quote summary',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh quote',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (quote!.offer != null) ...[
              if (quote!.offer!.name != null)
                Text(
                  quote!.offer!.name!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                )
              else
                Text(
                  'Offer applied',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              if (quote!.offer!.description != null)
                Text(
                  quote!.offer!.description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withOpacity(0.7)),
                ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 4),
            buildRow('Gross Total', quote!.grossTotal),
            buildRow('Taxable Value', quote!.taxableValue),
            buildRow('GST (Food)', quote!.gstFood),
            buildRow('GST (Delivery)', quote!.gstDelivery),
            buildRow('GST Total', quote!.gstTotal),
            if (quote!.discountAmount > 0)
              buildRow('Discount', quote!.discountAmount),
            buildRow('Delivery Charges', quote!.deliveryCharges),
            buildRow('Net Total', quote!.netTotal),
            const Divider(height: 20),
            buildRow('Grand Total', quote!.grandTotal, emphasize: true),
          ],
        ),
      ),
    );
  }
}

class _ItemsStep extends StatefulWidget {
  const _ItemsStep({
    required this.menuState,
    required this.items,
    required this.onAddProduct,
    required this.onUpdateItem,
    required this.onRemoveItem,
    required this.onChangeQuantity,
  });

  final MenuState menuState;
  final List<_SelectedOrderItem> items;
  final void Function(
    Map<String, dynamic> product,
    int quantity,
    String? customization,
    Map<String, dynamic>? variant,
  ) onAddProduct;
  final void Function(
    _SelectedOrderItem item,
    int quantity,
    String? customization,
    Map<String, dynamic>? variant,
  ) onUpdateItem;
  final void Function(_SelectedOrderItem) onRemoveItem;
  final void Function(_SelectedOrderItem, int) onChangeQuantity;

  @override
  State<_ItemsStep> createState() => _ItemsStepState();
}

class _ItemsStepState extends State<_ItemsStep> {
  List<Map<String, dynamic>> get _menuProducts =>
      widget.menuState.items.whereType<Map<String, dynamic>>().toList();

  Map<String, dynamic>? _findProductById(String productId) {
    for (final product in _menuProducts) {
      if (product['id']?.toString() == productId) {
        return product;
      }
    }
    return null;
  }

  bool _isCustomizable(Map<String, dynamic>? product) {
    if (product == null) return false;
    final value = product['customizable'];
    if (value is bool) return value;
    if (value is num) return value == 1;
    return value?.toString() == '1';
  }

  List<Map<String, dynamic>> _variantsOf(Map<String, dynamic>? product) {
    final variants = product?['variants'];
    if (variants is List) {
      return variants
          .whereType<Map>()
          .map((variant) => variant.cast<String, dynamic>())
          .toList();
    }
    return const [];
  }

  Map<String, dynamic>? _firstActiveVariant(
      List<Map<String, dynamic>> variants) {
    for (final variant in variants) {
      final isActiveRaw = variant['is_active'];
      final isActive = isActiveRaw is bool
          ? isActiveRaw
          : isActiveRaw == null
              ? true
              : isActiveRaw.toString() == '1' ||
                  isActiveRaw.toString().toLowerCase() == 'true';
      if (isActive) {
        return variant;
      }
    }
    return variants.isEmpty ? null : variants.first;
  }

  Map<String, dynamic>? _variantById(
    List<Map<String, dynamic>> variants,
    String? variantId,
  ) {
    if (variantId == null) return null;
    for (final variant in variants) {
      if (variant['variant_id']?.toString() == variantId) {
        return variant;
      }
    }
    return null;
  }

  double? _parsePrice(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Future<void> _handleAddProduct() async {
    final products = _menuProducts;
    if (products.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No products available')),
        );
      }
      return;
    }
    final result = await _showAddProductDialog(products);
    if (result != null) {
      widget.onAddProduct(
        result.product,
        result.quantity,
        result.customization,
        result.variant,
      );
    }
  }

  Future<void> _handleEditItem(_SelectedOrderItem item) async {
    final product = _findProductById(item.productId);
    final result = await _showEditItemDialog(item, product);
    if (result != null) {
      widget.onUpdateItem(
        item,
        result.quantity,
        result.customization,
        result.variant,
      );
    }
  }

  Future<_ProductSelectionResult?> _showAddProductDialog(
    List<Map<String, dynamic>> products,
  ) async {
    final searchController = TextEditingController();
    final customizationController = TextEditingController();
    Map<String, dynamic>? selected;
    Map<String, dynamic>? selectedVariant;
    int quantity = 1;

    final result = await showDialog<_ProductSelectionResult>(
      context: context,
      builder: (dialogContext) {
        final mediaSize = MediaQuery.of(dialogContext).size;
        final maxWidth = mediaSize.width * 0.9;
        final maxHeight = mediaSize.height * 0.9;
        final minWidth = math.min(420.0, maxWidth);
        final minHeight = math.min(480.0, maxHeight);

        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minWidth,
              maxWidth: math.max(minWidth, maxWidth),
              minHeight: minHeight,
              maxHeight: math.max(minHeight, maxHeight),
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final query = searchController.text.trim().toLowerCase();
                final filtered = query.isEmpty
                    ? products
                    : products.where((product) {
                        final name =
                            product['name']?.toString().toLowerCase() ?? '';
                        final description =
                            product['description']?.toString().toLowerCase() ??
                                '';
                        return name.contains(query) ||
                            description.contains(query);
                      }).toList();

                final selectedVariants = _variantsOf(selected);
                final requiresVariantSelection = selectedVariants.isNotEmpty;
                final showCustomization = _isCustomizable(selected) ||
                    customizationController.text.trim().isNotEmpty;
                String variantIdentifier(Map<String, dynamic> variant) {
                  return variant['variant_id']?.toString() ??
                      variant['id']?.toString() ??
                      variant['slug']?.toString() ??
                      variant['name']?.toString() ??
                      '';
                }

                final currentVariantId = selectedVariant == null
                    ? null
                    : variantIdentifier(selectedVariant!);
                final selectedUnitPrice = selectedVariant != null
                    ? _parsePrice(selectedVariant?['price'])
                    : _parsePrice(selected?['price']);

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add product',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: searchController,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  hintText:
                                      'Search products by name or description',
                                ),
                                onChanged: (_) => setModalState(() {}),
                              ),
                              const SizedBox(height: 12),
                              Material(
                                color: Colors.transparent,
                                child: filtered.isEmpty
                                    ? const _EmptyState(
                                        icon: Icons.search_off_outlined,
                                        message:
                                            'No products match your search.',
                                      )
                                    : ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minHeight: 120,
                                          maxHeight: 220,
                                        ),
                                        child: ListView.separated(
                                          shrinkWrap: true,
                                          itemCount: filtered.length,
                                          separatorBuilder: (_, __) =>
                                              const Divider(height: 0),
                                          itemBuilder: (context, index) {
                                            final product = filtered[index];
                                            final productId =
                                                product['id']?.toString() ?? '';
                                            final isSelected = selected !=
                                                    null &&
                                                selected!['id']?.toString() ==
                                                    productId;
                                            final price = product['price'];
                                            final subtitleParts = <String>[];
                                            if (price != null) {
                                              final priceStr = price is num
                                                  ? price.toStringAsFixed(2)
                                                  : price.toString();
                                              subtitleParts.add('₹$priceStr');
                                            }
                                            final size =
                                                product['size']?.toString();
                                            if (size != null &&
                                                size.trim().isNotEmpty) {
                                              subtitleParts.add(size.trim());
                                            }
                                            return ListTile(
                                              selected: isSelected,
                                              selectedTileColor:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withOpacity(0.08),
                                              title: Text(
                                                product['name']?.toString() ??
                                                    'Product',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600),
                                              ),
                                              subtitle: subtitleParts.isEmpty
                                                  ? null
                                                  : Text(subtitleParts
                                                      .join(' - ')),
                                              onTap: () {
                                                FocusManager
                                                    .instance.primaryFocus
                                                    ?.unfocus();
                                                setModalState(() {
                                                  selected = product;
                                                  quantity = 1;
                                                  customizationController
                                                      .clear();
                                                  final variants =
                                                      _variantsOf(product);
                                                  selectedVariant =
                                                      _firstActiveVariant(
                                                          variants);
                                                });
                                              },
                                            );
                                          },
                                        ),
                                      ),
                              ),
                              if (selected != null &&
                                  selectedVariants.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxHeight: 220),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Choose a variant',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 8),
                                        ...selectedVariants.map((variant) {
                                          final variantId =
                                              variantIdentifier(variant);
                                          final priceLabel =
                                              _parsePrice(variant['price'])
                                                  ?.toStringAsFixed(2);
                                          final description =
                                              variant['description']
                                                  ?.toString();
                                          final subtitleParts = <String>[];
                                          if (priceLabel != null) {
                                            subtitleParts.add('₹$priceLabel');
                                          }
                                          if (description != null &&
                                              description.trim().isNotEmpty) {
                                            subtitleParts
                                                .add(description.trim());
                                          }
                                          return RadioListTile<String>(
                                            value: variantId,
                                            groupValue: currentVariantId,
                                            title: Text(
                                              variant['name']?.toString() ??
                                                  'Variant',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600),
                                            ),
                                            subtitle: subtitleParts.isEmpty
                                                ? null
                                                : Text(
                                                    subtitleParts.join(' · ')),
                                            onChanged: (value) {
                                              if (value == null) return;
                                              setModalState(() {
                                                selectedVariant = variant;
                                              });
                                            },
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              if (selected != null) ...[
                                const SizedBox(height: 16),
                                _QuantityRow(
                                  quantity: quantity,
                                  onIncrement: () =>
                                      setModalState(() => quantity += 1),
                                  onDecrement: () {
                                    if (quantity > 1) {
                                      setModalState(() => quantity -= 1);
                                    }
                                  },
                                ),
                                if (selectedUnitPrice != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Unit price: ₹${selectedUnitPrice.toStringAsFixed(2)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                                if (showCustomization) ...[
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: customizationController,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Customization notes (optional)',
                                      hintText: 'E.g. No onions, extra spicy',
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: selected == null ||
                                    (requiresVariantSelection &&
                                        selectedVariant == null)
                                ? null
                                : () {
                                    Navigator.of(dialogContext).pop(
                                      _ProductSelectionResult(
                                        product: selected!,
                                        quantity: quantity,
                                        customization: customizationController
                                                .text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : customizationController.text
                                                .trim(),
                                        variant: selectedVariant,
                                      ),
                                    );
                                  },
                            child: const Text('Add item'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    // dispose controllers now that the dialog has closed
    searchController.dispose();
    customizationController.dispose();
    return result;
  }

  Future<_ItemEditResult?> _showEditItemDialog(
    _SelectedOrderItem item,
    Map<String, dynamic>? product,
  ) async {
    final customizationController = TextEditingController(
      text: item.customizationsController.text,
    );
    int quantity = int.tryParse(item.quantityController.text) ?? 1;
    final variants = _variantsOf(product);
    Map<String, dynamic>? selectedVariant = variants.isEmpty
        ? null
        : _variantById(variants, item.variantId) ??
            _firstActiveVariant(variants);

    final result = await showDialog<_ItemEditResult>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 360),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final requiresVariantSelection = variants.isNotEmpty;
                final showCustomization = _isCustomizable(product) ||
                    customizationController.text.trim().isNotEmpty;
                final selectedUnitPrice = selectedVariant != null
                    ? _parsePrice(selectedVariant?['price'])
                    : _parsePrice(product?['price']);
                String variantIdentifier(Map<String, dynamic> variant) {
                  return variant['variant_id']?.toString() ??
                      variant['id']?.toString() ??
                      variant['slug']?.toString() ??
                      variant['name']?.toString() ??
                      '';
                }

                final currentVariantId = selectedVariant == null
                    ? null
                    : variantIdentifier(selectedVariant!);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit ${item.productName}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (requiresVariantSelection) ...[
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choose a variant',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                ...variants.map((variant) {
                                  final variantId = variantIdentifier(variant);
                                  final priceLabel =
                                      _parsePrice(variant['price'])
                                          ?.toStringAsFixed(2);
                                  final description =
                                      variant['description']?.toString();
                                  final subtitleParts = <String>[];
                                  if (priceLabel != null) {
                                    subtitleParts.add('₹$priceLabel');
                                  }
                                  if (description != null &&
                                      description.trim().isNotEmpty) {
                                    subtitleParts.add(description.trim());
                                  }
                                  return RadioListTile<String>(
                                    value: variantId,
                                    groupValue: currentVariantId,
                                    title: Text(
                                      variant['name']?.toString() ?? 'Variant',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: subtitleParts.isEmpty
                                        ? null
                                        : Text(subtitleParts.join(' · ')),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setModalState(() {
                                        selectedVariant = variant;
                                      });
                                    },
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _QuantityRow(
                        quantity: quantity,
                        onIncrement: () => setModalState(() => quantity += 1),
                        onDecrement: () => setModalState(() {
                          if (quantity > 1) quantity -= 1;
                        }),
                      ),
                      if (selectedUnitPrice != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Unit price: ₹${selectedUnitPrice.toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                      if (showCustomization) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: customizationController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Customization notes (optional)',
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: requiresVariantSelection &&
                                    selectedVariant == null
                                ? null
                                : () {
                                    Navigator.of(dialogContext).pop(
                                      _ItemEditResult(
                                        quantity: quantity,
                                        customization: customizationController
                                                .text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : customizationController.text
                                                .trim(),
                                        variant: selectedVariant,
                                      ),
                                    );
                                  },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    // dispose the temporary controller now that the edit dialog has closed
    customizationController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Order items',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed:
                    widget.menuState.isLoading ? null : _handleAddProduct,
                icon: const Icon(Icons.add),
                label: const Text('Add product'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: widget.menuState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : widget.items.isEmpty
                    ? const _EmptyState(
                        icon: Icons.shopping_bag_outlined,
                        message:
                            'No items added yet.\nTap "Add product" to start building the order.',
                      )
                    : ListView.separated(
                        itemCount: widget.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = widget.items[index];
                          return _OrderItemTile(
                            item: item,
                            onIncrement: () => widget.onChangeQuantity(item, 1),
                            onDecrement: () =>
                                widget.onChangeQuantity(item, -1),
                            onRemove: () => widget.onRemoveItem(item),
                            onEdit: () => _handleEditItem(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _QuantityRow extends StatelessWidget {
  const _QuantityRow({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'Quantity',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Theme.of(context).primaryColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QuantityIconButton(
                icon: Icons.remove,
                onPressed: quantity > 1 ? onDecrement : null,
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Text(
                  '$quantity',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E3A2F),
                  ),
                ),
              ),
              _QuantityIconButton(
                icon: Icons.add,
                onPressed: onIncrement,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuantityIconButton extends StatelessWidget {
  const _QuantityIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 36,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _ProductSelectionResult {
  const _ProductSelectionResult({
    required this.product,
    required this.quantity,
    this.customization,
    this.variant,
  });

  final Map<String, dynamic> product;
  final int quantity;
  final String? customization;
  final Map<String, dynamic>? variant;
}

class _ItemEditResult {
  const _ItemEditResult({
    required this.quantity,
    this.customization,
    this.variant,
  });

  final int quantity;
  final String? customization;
  final Map<String, dynamic>? variant;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xFF9CA3AF)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final int currentStep;

  static const List<_StepMeta> _steps = [
    _StepMeta(title: 'Customer'),
    _StepMeta(title: 'Schedule'),
    _StepMeta(title: 'Review'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).primaryColor;
    final muted = const Color(0xFFE5E7EB);
    final theme = Theme.of(context);

    return Row(
      children: [
        for (int index = 0; index < _steps.length; index++) ...[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (index != 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index <= currentStep ? accent : muted,
                        ),
                      ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: index == currentStep
                            ? accent
                            : (index < currentStep
                                ? accent.withOpacity(0.2)
                                : Colors.white),
                        border: Border.all(
                          color: index <= currentStep ? accent : muted,
                        ),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: index == currentStep
                              ? Colors.white
                              : (index < currentStep
                                  ? accent
                                  : theme.textTheme.labelLarge?.color),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (index != _steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index < currentStep ? accent : muted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _steps[index].title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: index <= currentStep
                        ? accent
                        : theme.textTheme.labelLarge?.color,
                  ),
                ),
                if (_steps[index].subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _steps[index].subtitle!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (index != _steps.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _StepMeta {
  const _StepMeta({required this.title, this.subtitle});

  final String title;
  final String? subtitle;
}

class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onEdit,
  });

  final _SelectedOrderItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quantity = int.tryParse(item.quantityController.text) ?? 1;
    final customization = item.customizationsController.text.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Card(
          margin: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (item.variantName != null &&
                              item.variantName!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Variant: ${item.variantName!}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                          if (item.unitPrice != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '₹${item.unitPrice!.toStringAsFixed(2)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _QuantityChip(
                      quantity: quantity,
                      onIncrement: onIncrement,
                      onDecrement: onDecrement,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Remove item',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onRemove,
                    ),
                  ],
                ),
                if (customization.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Customization: $customization',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantityChip extends StatelessWidget {
  const _QuantityChip({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
        color: color.withOpacity(0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: onDecrement,
            splashRadius: 18,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              '$quantity',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E3A2F),
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: onIncrement,
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodOption {
  const _PaymentMethodOption({required this.value, required this.label});

  final String value;
  final String label;
}

class _MetadataStep extends StatelessWidget {
  const _MetadataStep({
    required this.selectedCustomer,
    required this.selectedAddressId,
    this.selectedAddressSummary,
    required this.deliveryType,
    required this.orderItems,
    required this.manualOrderMediums,
    required this.paymentMethodOptions,
    required this.paymentStatuses,
    required this.selectedMedium,
    required this.selectedPaymentMethod,
    required this.selectedPaymentStatus,
    required this.onMediumChanged,
    required this.onPaymentMethodChanged,
    required this.onPaymentStatusChanged,
    required this.quote,
    required this.quoteLoading,
    required this.quoteError,
    required this.onRefreshQuote,
    required this.commentsController,
  });

  final OutletCustomer? selectedCustomer;
  final String? selectedAddressId;
  final String? selectedAddressSummary;
  final String deliveryType;
  final List<_SelectedOrderItem> orderItems;
  final List<String> manualOrderMediums;
  final List<_PaymentMethodOption> paymentMethodOptions;
  final List<String> paymentStatuses;
  final String selectedMedium;
  final String selectedPaymentMethod;
  final String selectedPaymentStatus;
  final ValueChanged<String> onMediumChanged;
  final ValueChanged<String> onPaymentMethodChanged;
  final ValueChanged<String> onPaymentStatusChanged;
  final order_service.ManualOrderQuote? quote;
  final bool quoteLoading;
  final String? quoteError;
  final VoidCallback onRefreshQuote;
  final TextEditingController commentsController;

  @override
  Widget build(BuildContext context) {
    final isSelfPickup = deliveryType == _deliveryTypeSelfPickup;
    final isDineIn = deliveryType == _deliveryTypeDineIn;
    String fulfilmentLabel() => isSelfPickup
        ? 'Pickup'
        : isDineIn
            ? 'Dine in'
            : 'Delivery';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (selectedCustomer != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedCustomer!.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  if (selectedCustomer!.mobile != null)
                    Text('Mobile: ${selectedCustomer!.mobile}'),
                  Text('Fulfilment: ${fulfilmentLabel()}'),
                  if (!isSelfPickup)
                    Text(
                      selectedAddressSummary != null
                          ? 'Address: $selectedAddressSummary'
                          : 'No delivery address selected',
                    )
                  else if (selectedAddressSummary != null)
                    Text(selectedAddressSummary!),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Items',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (quote != null && quote!.items.isNotEmpty)
                  Column(
                    children: [
                      for (final line in quote!.items) ...[
                        _QuoteItemRow(line: line),
                        if (line != quote!.items.last)
                          const Divider(height: 18),
                      ],
                    ],
                  )
                else if (orderItems.isEmpty)
                  const Text('No items added')
                else
                  Column(
                    children: [
                      for (final item in orderItems) ...[
                        _MetadataItemRow(
                          item: item,
                          quoteLine: null,
                        ),
                        if (item != orderItems.last) const Divider(height: 18),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _QuoteSummaryCard(
          quote: quote,
          isLoading: quoteLoading,
          error: quoteError,
          onRefresh: onRefreshQuote,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: commentsController,
          decoration: const InputDecoration(
            labelText: 'Order notes (optional)',
            hintText: 'Driver instructions, kitchen notes, etc.',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: selectedMedium,
          items: manualOrderMediums
              .map((medium) => DropdownMenuItem(
                    value: medium,
                    child: Text(medium),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) onMediumChanged(value);
          },
          decoration: const InputDecoration(labelText: 'Order medium'),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: selectedPaymentMethod,
          items: paymentMethodOptions
              .map((option) => DropdownMenuItem(
                    value: option.value,
                    child: Text(option.label),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) onPaymentMethodChanged(value);
          },
          decoration: const InputDecoration(labelText: 'Payment method'),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: selectedPaymentStatus,
          items: paymentStatuses
              .map((status) => DropdownMenuItem(
                    value: status,
                    child: Text(status),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) onPaymentStatusChanged(value);
          },
          decoration: const InputDecoration(labelText: 'Payment status'),
        ),
      ],
    );
  }
}

class _SelectedOrderItem {
  _SelectedOrderItem({
    required this.productId,
    required this.productName,
    this.unitPrice,
    this.imageUrl,
    this.variantId,
    this.variantName,
  })  : quantityController = TextEditingController(text: '1'),
        customizationsController = TextEditingController();

  final String productId;
  final String productName;
  double? unitPrice;
  final String? imageUrl;
  String? variantId;
  String? variantName;
  final TextEditingController quantityController;
  final TextEditingController customizationsController;

  List<String> get customizations => customizationsController.text
      .split(RegExp(r'[\n,]'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();

  void dispose() {
    quantityController.dispose();
    customizationsController.dispose();
  }
}

// Review Step Widget
class _ReviewStep extends StatefulWidget {
  const _ReviewStep({
    required this.subscriptionPlan,
    required this.selectedCustomer,
    required this.selectedAddress,
    required this.selectedDatesWithQuantities,
    required this.selectedTimeSlot,
    required this.onCreateSubscription,
    required this.isSubmitting,
    this.isRescheduleMode = false,
    this.originalTotalQuantity,
  });

  final SubscriptionPlan? subscriptionPlan;
  final OutletCustomer? selectedCustomer;
  final OutletCustomerAddress? selectedAddress;
  final Map<DateTime, int> selectedDatesWithQuantities;
  final String? selectedTimeSlot;
  final VoidCallback onCreateSubscription;
  final bool isSubmitting;
  final bool isRescheduleMode;
  final int? originalTotalQuantity;

  @override
  State<_ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<_ReviewStep> {
  SubscriptionQuoteResponse? _quoteResponse;
  bool _isLoadingQuote = false;
  String? _quoteError;

  @override
  void initState() {
    super.initState();
    // Only fetch quote for create mode, not reschedule
    if (!widget.isRescheduleMode) {
      _fetchQuote();
    }
  }

  Future<void> _fetchQuote() async {
    if (widget.subscriptionPlan == null ||
        widget.selectedAddress == null ||
        widget.selectedCustomer == null ||
        widget.selectedDatesWithQuantities.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingQuote = true;
      _quoteError = null;
    });

    try {
      // Build dates array in format: [{date: "YYYY-MM-DD", qty: 1}, ...]
      final dateFormat = DateFormat('yyyy-MM-dd');
      final dates = widget.selectedDatesWithQuantities.entries
          .map((entry) => {
                'date': dateFormat.format(entry.key),
                'qty': entry.value,
              })
          .toList();

      final quote = await SubscriptionService.getSubscriptionQuote(
        productId: widget.subscriptionPlan!.productId,
        addressId: widget.selectedAddress!.id.toString(),
        customerId: widget.selectedCustomer!.customerId.toString(),
        dates: dates,
      );

      setState(() {
        _quoteResponse = quote;
        _isLoadingQuote = false;
      });
    } catch (e) {
      setState(() {
        _quoteError = e.toString();
        _isLoadingQuote = false;
      });
    }
  }

  double _calculateSubtotal() {
    if (_quoteResponse != null) {
      return _quoteResponse!.summary.grossTotalPaise / 100.0;
    }

    // Fallback to local calculation for reschedule mode
    if (widget.subscriptionPlan?.product?.price == null) return 0.0;
    final pricePerUnit =
        double.tryParse(widget.subscriptionPlan!.product!.price!) ?? 0.0;
    final totalUnits = widget.selectedDatesWithQuantities.values
        .fold<int>(0, (sum, qty) => sum + qty);
    return pricePerUnit * totalUnits;
  }

  double _calculateDiscount() {
    if (_quoteResponse != null) {
      return _quoteResponse!.summary.discountPaise / 100.0;
    }

    // Fallback to local calculation for reschedule mode
    final subtotal = _calculateSubtotal();
    final totalDays = widget.selectedDatesWithQuantities.length;

    if (widget.subscriptionPlan?.discountTiers.isEmpty ?? true) return 0.0;

    SubscriptionDiscountTier? applicableTier;
    for (final tier in widget.subscriptionPlan!.discountTiers) {
      if (tier.qty != null && totalDays >= tier.qty!) {
        applicableTier = tier;
      }
    }

    if (applicableTier == null) return 0.0;

    double discount = 0.0;
    if (applicableTier.percentOff != null) {
      discount = subtotal * (applicableTier.percentOff! / 100);
    }
    if (applicableTier.flatOff != null) {
      discount += applicableTier.flatOff! * totalDays;
    }

    return discount;
  }

  double _calculateNetTotal() {
    if (_quoteResponse != null) {
      return _quoteResponse!.summary.netTotalPaise / 100.0;
    }
    return _calculateSubtotal() - _calculateDiscount();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy');
    final dayFormat = DateFormat('EEEE');
    final subtotal = _calculateSubtotal();
    final discount = _calculateDiscount();
    final netTotal = _calculateNetTotal();

    // Sort dates chronologically
    final sortedDates = widget.selectedDatesWithQuantities.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reschedule Mode Summary
          if (widget.isRescheduleMode && widget.originalTotalQuantity != null)
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You must maintain the original total quantity of ${widget.originalTotalQuantity} units',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (widget.isRescheduleMode && widget.originalTotalQuantity != null)
            const SizedBox(height: 16),

          // Product/Plan Information (only show in create mode)
          if (!widget.isRescheduleMode)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscription Plan',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.subscriptionPlan?.product?.name ?? 'Unknown Product',
                      style: theme.textTheme.titleLarge,
                    ),
                    if (widget.subscriptionPlan?.product?.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.subscriptionPlan!.product!.description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Price per unit: ',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          '₹${widget.subscriptionPlan?.product?.price ?? '0'}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E3A2F),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Customer Information (only show in create mode)
          if (!widget.isRescheduleMode)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.selectedCustomer?.name ?? 'No customer selected',
                      style: theme.textTheme.titleSmall,
                    ),
                    if (widget.selectedCustomer?.mobile != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.selectedCustomer!.mobile!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Delivery Address',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.selectedAddress?.address ?? 'No address selected',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (widget.selectedAddress?.pinCode != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Pin: ${widget.selectedAddress!.pinCode}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),

          if (!widget.isRescheduleMode) const SizedBox(height: 16),

          // Time Slot (only show in create mode)
          if (!widget.isRescheduleMode && widget.selectedTimeSlot != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Delivery Time: ${widget.selectedTimeSlot}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Selected Dates & Quantities
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subscription Schedule',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${sortedDates.length} days selected',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  // List of dates with quantities
                  ...sortedDates.map((date) {
                    final quantity = widget.selectedDatesWithQuantities[date] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateFormat.format(date),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  dayFormat.format(date),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.primaryColor.withValues(alpha: 0.15),
                                  theme.primaryColor.withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.primaryColor.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.close,
                                  size: 14,
                                  color: theme.primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$quantity',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Price Breakdown (only show in create mode)
          if (!widget.isRescheduleMode)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _isLoadingQuote
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _quoteError != null
                        ? Column(
                            children: [
                              Text(
                                'Error loading quote',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _quoteError!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.red[700],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _PriceRow(
                                label: 'Subtotal',
                                value: '₹${subtotal.toStringAsFixed(2)}',
                              ),
                              if (discount > 0) ...[
                                const SizedBox(height: 8),
                                _PriceRow(
                                  label: 'Discount',
                                  value: '- ₹${discount.toStringAsFixed(2)}',
                                  valueColor: theme.primaryColor,
                                ),
                              ],
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 12),
                              _PriceRow(
                                label: 'Net Total',
                                value: '₹${netTotal.toStringAsFixed(2)}',
                                labelStyle: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                valueStyle: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E3A2F),
                                ),
                              ),
                            ],
                          ),
              ),
            ),

          const SizedBox(height: 24),

          // // Create/Update Subscription Button
          // SizedBox(
          //   width: double.infinity,
          //   height: 50,
          //   child: FilledButton(
          //     onPressed: isSubmitting ? null : onCreateSubscription,
          //     style: FilledButton.styleFrom(
          //       backgroundColor: const Color(0xFF1E3A2F),
          //     ),
          //     child: isSubmitting
          //         ? const SizedBox(
          //             height: 20,
          //             width: 20,
          //             child: CircularProgressIndicator(
          //               strokeWidth: 2,
          //               color: Colors.white,
          //             ),
          //           )
          //         : Text(
          //             isRescheduleMode ? 'Update Schedule' : 'Create Subscription',
          //             style: const TextStyle(
          //               fontSize: 16,
          //               fontWeight: FontWeight.w600,
          //             ),
          //           ),
          //   ),
          // ),

          const SizedBox(height: 80), // Extra space at bottom
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
    this.valueColor,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: labelStyle ?? theme.textTheme.bodyMedium,
        ),
        Text(
          value,
          style: valueStyle ??
              theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
        ),
      ],
    );
  }
}
