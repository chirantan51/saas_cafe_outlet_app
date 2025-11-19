import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outlet_app/data/models/order_model.dart';

import 'package:outlet_app/data/models/outlet_customer.dart';
import 'package:outlet_app/providers/dashboard_refresh_provider.dart';
import 'package:outlet_app/providers/menu_provider.dart';
import 'package:outlet_app/services/customer_service.dart';
import 'package:outlet_app/services/order_service.dart' as order_service;
import 'package:outlet_app/utils/navigation_helpers.dart';

const String _deliveryTypeDelivery = 'delivery';
const String _deliveryTypeSelfPickup = 'pickup';
const String _deliveryTypeDineIn = 'dine_in';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({
    super.key,
    this.isEditMode = false,
    this.order,
  });

  // New: indicate whether screen is used to edit an existing order
  final bool isEditMode;

  // New: when isEditMode == true this holds the order to edit
  final OrderModel? order;

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
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

  static const _manualOrderMediums = ['StoreVisit', 'Call', 'WhatsApp'];
  static const _paymentMethodOptions = <_PaymentMethodOption>[
    _PaymentMethodOption(value: 'Cash', label: 'Cash'),
    _PaymentMethodOption(value: 'Online', label: 'Online'),
    _PaymentMethodOption(value: 'Card', label: 'Card'),
  ];
  static const _paymentStatuses = ['Pending', 'Paid', 'Redunded'];

  // Local copies for reuse in the state
  late bool _isEditMode;
  OrderModel? _editingOrder;

  @override
  void initState() {
    super.initState();
    // initialize edit mode and order if provided
    _isEditMode = widget.isEditMode;
    _editingOrder = widget.order;

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
            final itemMap = _normalizeExistingOrderItem(raw);
            if (itemMap == null) {
              continue;
            }

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
            print("error: [dkC] : " + error.toString());
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
        _selectedCustomer = widget.order != null
            ? getCustomerFromId(widget.order!.customer_id)
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

  Map<String, dynamic>? _normalizeExistingOrderItem(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw.cast<String, dynamic>());
    }
    if (raw is OrderItem) {
      return {
        'product_id': raw.productId,
        'product_name': raw.productName,
        'quantity': raw.quantity,
        'variant_id': raw.variantId,
        'variant_name': raw.variantName,
        'unit_price': raw.unitPrice ?? raw.price,
        'price': raw.price,
        'customizations': raw.customizations,
        'image': raw.variant?.image,
      };
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
      _goToStep(2);
      _fetchQuote();
      return;
    }

    _handleSubmit();
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

    OrderModel? order = widget.order;
    bool isEditMode = widget.isEditMode;

    // dart
    final OutletCustomer? maybeCustomer =
        isEditMode ? getCustomerFromId(widget.order!.customer_id) : null;
    final List<OutletCustomer> filtered_customers_list =
        (isEditMode == true && maybeCustomer != null)
            ? [maybeCustomer]
            : _filteredCustomers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create order'),
      ),
      body: SafeArea(
        child: Column(
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
                  _ItemsStep(
                    menuState: menuState,
                    items: _orderItems,
                    onAddProduct: _addProductWithDetails,
                    onUpdateItem: _updateOrderItemDetails,
                    onRemoveItem: _removeOrderItem,
                    onChangeQuantity: _changeQuantity,
                  ),
                  _MetadataStep(
                    selectedCustomer: _selectedCustomer,
                    selectedAddressId: _selectedAddressId,
                    selectedAddressSummary: _selectedAddressSummary,
                    deliveryType: _deliveryType,
                    orderItems: _orderItems,
                    manualOrderMediums: _manualOrderMediums,
                    paymentMethodOptions: _paymentMethodOptions,
                    paymentStatuses: _paymentStatuses,
                    selectedMedium: _selectedMedium,
                    selectedPaymentMethod: _selectedPaymentMethod,
                    selectedPaymentStatus: _selectedPaymentStatus,
                    onMediumChanged: _setManualOrderMedium,
                    onPaymentMethodChanged: _setPaymentMethod,
                    onPaymentStatusChanged: _setPaymentStatus,
                    quote: _quote,
                    quoteLoading: _quoteLoading,
                    quoteError: _quoteError,
                    onRefreshQuote: _fetchQuote,
                    commentsController: _orderCommentController,
                  ),
                ],
              ),
            ),
            SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: _isSubmitting ? null : _handleBack,
                      child: const Text('Back'),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        _isEditMode && _currentStep == 2
                            ? FilledButton(
                                onPressed: () {
                                  _isSubmitting ? null : _handleCancel("");
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : Text('Cancel'),
                              )
                            : Container(),
                        SizedBox(
                            width: _isEditMode && _currentStep == 2 ? 12 : 0),
                        Expanded(
                          child: FilledButton(
                            onPressed: _isSubmitting ? null : _handleNext,
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(_currentStep == 2
                                    ? _isEditMode
                                        ? 'Update Order'
                                        : 'Create order'
                                    : 'Next'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
                Text(
                  'Fulfilment',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _deliveryTypeDelivery,
                    _deliveryTypeDineIn,
                    _deliveryTypeSelfPickup
                  ].map((type) {
                    return ChoiceChip(
                      label: Text(labelFor(type)),
                      selected: deliveryType == type,
                      onSelected: (selected) {
                        if (selected) onDeliveryTypeChanged(type);
                      },
                    );
                  }).toList(),
                ),
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
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF54A079),
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

    // Wait for dialog animation to complete before disposing
    Future.delayed(const Duration(milliseconds: 300), () {
      searchController.dispose();
      customizationController.dispose();
    });
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

    // Wait for dialog animation to complete before disposing
    Future.delayed(const Duration(milliseconds: 300), () {
      customizationController.dispose();
    });
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
            border: Border.all(color: const Color(0xFF54A079)),
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
    _StepMeta(title: 'Items'),
    _StepMeta(title: 'Review'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF54A079);
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
                    fontWeight: FontWeight.w700,
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
    final color = const Color(0xFF54A079);
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
