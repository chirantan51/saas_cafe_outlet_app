import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:outlet_app/providers/auth_provider.dart';
import 'package:outlet_app/providers/recent_orders_provider.dart';
import 'package:outlet_app/services/order_service.dart';
import 'package:outlet_app/ui/screens/edit_dine_in_order_screen.dart';
import 'package:outlet_app/ui/widgets/order_stage_stepper.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/order_model.dart';

class OrderDetailDialog extends ConsumerStatefulWidget {
  const OrderDetailDialog({super.key, required this.order});

  final OrderModel order;

  @override
  ConsumerState<OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends ConsumerState<OrderDetailDialog> {
  static const List<String> _defaultPaymentStatuses = [
    'Pending',
    'Paid',
    'Refunded'
  ];
  static const List<String> _defaultPaymentMethods = ['Cash', 'Online', 'Card'];

  late final List<String> _paymentStatuses;
  late final List<String> _paymentMethods;
  late String _initialPaymentStatus;
  late String _initialPaymentMethod;
  late String _selectedPaymentStatus;
  late String _selectedPaymentMethod;
  bool _updatingPayment = false;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _paymentStatuses = List<String>.from(_defaultPaymentStatuses);
    _paymentMethods = List<String>.from(_defaultPaymentMethods);

    if (widget.order.paymentStatus.isNotEmpty &&
        !_paymentStatuses.contains(widget.order.paymentStatus)) {
      _paymentStatuses.insert(0, widget.order.paymentStatus);
    }
    final initialMethod = widget.order.paymentMethod;
    if (initialMethod != null &&
        initialMethod.isNotEmpty &&
        !_paymentMethods.contains(initialMethod)) {
      _paymentMethods.insert(0, initialMethod);
    }

    _selectedPaymentStatus = widget.order.paymentStatus.isNotEmpty
        ? widget.order.paymentStatus
        : _paymentStatuses.first;
    _selectedPaymentMethod = initialMethod?.isNotEmpty == true
        ? initialMethod!
        : _paymentMethods.first;

    _initialPaymentStatus = _selectedPaymentStatus;
    _initialPaymentMethod = _selectedPaymentMethod;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  bool get _isCancelled => widget.order.status.toLowerCase() == 'cancelled';

  @override
  Widget build(BuildContext context) {
    final authToken = ref.watch(authProvider).authToken;
    final order = widget.order;

    return Dialog.fullscreen(
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Order Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Customer: ${order.customer} (${order.customerMobile})',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              final telUrl =
                                  Uri.parse('tel:${order.customerMobile}');
                              if (await canLaunchUrl(telUrl)) {
                                await launchUrl(telUrl);
                              }
                            },
                            icon: Icon(
                              Icons.phone,
                              size: 22,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Delivery Address:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(order.deliveryAddress ?? '-'),
                      const SizedBox(height: 20),
                      const Text(
                        'Items:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        itemCount: order.items.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final item = order.items[index];
                          final unitPrice = item.unitPrice ?? item.price;
                          final lineTotal = item.lineTotalAfterDiscount ??
                              unitPrice * item.quantity;
                          final variantName = (item.variantName ?? '').trim();
                          final instructions = item.customizations
                              .map((entry) =>
                                  entry['instruction']?.toString().trim())
                              .whereType<String>()
                              .where((text) => text.isNotEmpty)
                              .toList();

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (variantName.isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 2),
                                              child: Text(
                                                '- $variantName',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[800],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'x ${item.quantity}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${unitPrice.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        Text(
                                          '₹${lineTotal.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (instructions.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'Instructions: ${instructions.join(', ')}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const Divider(height: 24),
                      _buildSummaryRow(
                        label: 'Gross Total',
                        value: order.grossTotal,
                      ),
                      _buildSummaryRow(
                        label: 'Delivery Charges',
                        value: order.deliveryCharges,
                      ),
                      _buildSummaryRow(
                        label: 'Net Total',
                        value: order.netTotal,
                        highlight: true,
                      ),
                      const Divider(height: 28),
                      Row(
                        children: [
                          const Text(
                            'Status: ',
                            style: TextStyle(fontSize: 15),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(order.status)
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              order.status,
                              style: TextStyle(
                                color: _getStatusColor(order.status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Placed at: ${DateFormat('dd MMM, hh:mm a').format(order.placedAt)}',
                      ),
                      const SizedBox(height: 24),
                      _buildPaymentSection(context, authToken, ref),
                      const SizedBox(height: 24),
                      _buildOrderActionArea(context, ref, authToken, order),
                      if (!_isCancelled &&
                          (order.deliveryType?.toLowerCase() == 'dine_in')) ...[
                        const SizedBox(height: 16),
                        _buildEditDineInButton(context, ref),
                      ],
                      if (!_isCancelled) ...[
                        const SizedBox(height: 16),
                        _buildCancellationButton(context, ref, authToken),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required double value,
    bool highlight = false,
  }) {
    final style = TextStyle(
      fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
      fontSize: highlight ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style)),
          Text('₹${value.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(
    BuildContext context,
    String? authToken,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final order = widget.order;

    if (_isCancelled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Status: ${order.paymentStatus}',
            style: theme.textTheme.bodyMedium,
          ),
          if (order.paymentMethod != null && order.paymentMethod!.isNotEmpty)
            Text(
              'Payment Method: ${order.paymentMethod!}',
              style: theme.textTheme.bodyMedium,
            ),
        ],
      );
    }

    final bool changed = _selectedPaymentStatus != _initialPaymentStatus ||
        _selectedPaymentMethod != _initialPaymentMethod;

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Details',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                final bool canShowSideBySide = width >= 560;

                Widget buildStatusField() => DropdownButtonFormField<String>(
                      value: _selectedPaymentStatus,
                      isExpanded: true,
                      items: _paymentStatuses
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedPaymentStatus = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Payment Status',
                        border: OutlineInputBorder(),
                      ),
                    );

                Widget buildMethodField() => DropdownButtonFormField<String>(
                      value: _selectedPaymentMethod,
                      isExpanded: true,
                      items: _paymentMethods
                          .map(
                            (method) => DropdownMenuItem(
                              value: method,
                              child: Text(method),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedPaymentMethod = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                      ),
                    );

                if (canShowSideBySide) {
                  final double fieldWidth = (width - 16) / 2;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      SizedBox(width: fieldWidth, child: buildStatusField()),
                      SizedBox(width: fieldWidth, child: buildMethodField()),
                    ],
                  );
                }

                return Column(
                  children: [
                    SizedBox(width: double.infinity, child: buildStatusField()),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: buildMethodField()),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: !_updatingPayment && changed
                    ? () => _handlePaymentUpdate(context, ref, authToken)
                    : null,
                icon: _updatingPayment
                    ? SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.onPrimary),
                        ),
                      )
                    : const Icon(Icons.save_alt),
                label: Text(_updatingPayment ? 'Updating…' : 'Update Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePaymentUpdate(
    BuildContext context,
    WidgetRef ref,
    String? authToken,
  ) async {
    if (authToken == null || authToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to update payment: missing token.')),
      );
      return;
    }

    setState(() => _updatingPayment = true);

    final success = await updateOrderPayment(
      orderId: widget.order.orderId,
      paymentStatus: _selectedPaymentStatus,
      paymentMethod: _selectedPaymentMethod,
      authToken: authToken,
    );

    if (!mounted) return;

    setState(() {
      _updatingPayment = false;
      if (success) {
        _initialPaymentStatus = _selectedPaymentStatus;
        _initialPaymentMethod = _selectedPaymentMethod;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Payment details updated.' : 'Failed to update payment.',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      ref.invalidate(recentOrdersProvider);
    }
  }

  Widget _buildOrderActionArea(
    BuildContext context,
    WidgetRef ref,
    String? authToken,
    OrderModel order,
  ) {
    Future<void> handleStatusUpdate(String newStatus, String successMsg) async {
      final success = await updateOrderStatus(
        orderId: order.orderId,
        newStatus: newStatus,
        authToken: authToken ?? '',
      );

      if (!context.mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? successMsg : 'Failed to update status.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      ref.invalidate(recentOrdersProvider);
    }

    switch (order.status.toLowerCase()) {
      case 'pending':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () =>
                  handleStatusUpdate('Accepted', 'Order Accepted!'),
              icon: const Icon(Icons.check),
              label: const Text('Accept'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                minimumSize: const Size(110, 40),
                textStyle: const TextStyle(fontSize: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () =>
                  handleStatusUpdate('Rejected', 'Order Rejected!'),
              icon: const Icon(Icons.close),
              label: const Text('Reject'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                minimumSize: const Size(110, 40),
                textStyle: const TextStyle(fontSize: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      default:
        return OrderStageStepper(
          stages: const ['Preparing', 'Ready', 'Delivering', 'Delivered'],
          currentStage: order.status,
          onStageChange: (newStatus) =>
              handleStatusUpdate(newStatus, 'Updated to $newStatus!'),
        );
    }
  }

  Widget _buildEditDineInButton(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          side: BorderSide(color: theme.colorScheme.primary),
        ),
        icon: const Icon(Icons.restaurant_menu_outlined),
        label: const Text('Edit Items'),
        onPressed: () async {
          //await _openEditDineInOrder(context, ref);
        },
      ),
    );
  }

  Widget _buildCancellationButton(
    BuildContext context,
    WidgetRef ref,
    String? authToken,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent),
        ),
        icon: _isCancelling
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cancel_outlined),
        label: Text(_isCancelling ? 'Cancelling…' : 'Cancel Order'),
        onPressed: _isCancelling
            ? null
            : () async {
                final comment = await _promptCancellationComment(context);
                if (comment == null || comment.isEmpty) return;
                await _handleCancelOrder(context, ref, authToken, comment);
              },
      ),
    );
  }

  Future<String?> _promptCancellationComment(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Please provide a reason or note for cancelling this order.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'E.g. Plan changed, money refunded…',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                final comment = controller.text.trim();
                if (comment.isEmpty) return;
                Navigator.of(dialogContext).pop(comment);
              },
              child: const Text('Cancel order'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleCancelOrder(
    BuildContext context,
    WidgetRef ref,
    String? authToken,
    String comment,
  ) async {
    if (authToken == null || authToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to cancel order: missing token.')),
      );
      return;
    }

    setState(() => _isCancelling = true);

    final success = await cancelOrder(
      orderId: widget.order.orderId,
      comment: comment,
    );

    if (!mounted) return;

    setState(() => _isCancelling = false);

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Order cancelled.' : 'Failed to cancel order.'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      ref.invalidate(recentOrdersProvider);
    }
  }

  // Future<void> _openEditDineInOrder(BuildContext context, WidgetRef ref) async {
  //   final updated = await Navigator.of(context).push<bool>(
  //     MaterialPageRoute(
  //       builder: (_) => EditDineInOrderScreen(order: widget.order),
  //     ),
  //   );

  //   if (updated == true && mounted) {
  //     ref.invalidate(recentOrdersProvider);
  //     Navigator.of(context).pop();
  //   }
  // }
}
