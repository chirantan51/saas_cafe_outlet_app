import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:outlet_app/data/models/plan_subscription.dart';
import 'package:outlet_app/data/models/subscription_detail.dart';
import 'package:outlet_app/data/models/subscription_plan.dart';
import 'package:outlet_app/providers/subscription_detail_provider.dart';
import 'package:outlet_app/services/subscription_service.dart';
import 'package:outlet_app/ui/screens/subscription_create_subscription.dart';
class SubscriptionSubscriptionDetailScreen extends ConsumerWidget {
  const SubscriptionSubscriptionDetailScreen({
    super.key,
    required this.subscriptionId,
    this.preview,
    this.plan,
  });
  final int subscriptionId;
  final PlanSubscription? preview;
  final SubscriptionPlan? plan;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(subscriptionDetailProvider(subscriptionId));
    return Scaffold(
      appBar: AppBar(
        title: Text(preview?.customer.name ?? 'Subscription #$subscriptionId'),
      ),
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorBody(
            message: error.toString(),
            onRetry: () =>
                ref.refresh(subscriptionDetailProvider(subscriptionId).future),
          ),
          data: (detail) => _DetailBody(detail: detail, preview: preview, plan: plan),
        ),
      ),
    );
  }
}
class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail, this.preview, this.plan});
  final SubscriptionDetail detail;
  final PlanSubscription? preview;
  final SubscriptionPlan? plan;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.primaryColor;
    final deliveredRatio =
        detail.totalUnits > 0 ? detail.unitsDelivered / detail.totalUnits : 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card(
          //   shape:
          //       RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          //   child: Padding(
          //     padding: const EdgeInsets.all(20),
          //     child: Column(
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: [
          //         Row(
          //           children: [
          //             Expanded(
          //               child: Column(
          //                 crossAxisAlignment: CrossAxisAlignment.start,
          //                 children: [
          //                   Text(
          //                     detail.productName ?? 'Subscription',
          //                     style: theme.textTheme.titleLarge?.copyWith(
          //                       fontWeight: FontWeight.w700,
          //                     ),
          //                   ),
          //                   const SizedBox(height: 4),
          //                   Text(
          //                     '#${detail.id}',
          //                     style: theme.textTheme.bodySmall?.copyWith(
          //                       color: Colors.black54,
          //                     ),
          //                   ),
          //                 ],
          //               ),
          //             ),
          //             Container(
          //               padding: const EdgeInsets.symmetric(
          //                   horizontal: 12, vertical: 6),
          //               decoration: BoxDecoration(
          //                 color: accent.withOpacity(0.12),
          //                 borderRadius: BorderRadius.circular(16),
          //               ),
          //               child: Text(
          //                 detail.status,
          //                 style: TextStyle(
          //                   color: accent,
          //                   fontWeight: FontWeight.w600,
          //                 ),
          //               ),
          //             ),
          //           ],
          //         ),
          //         const SizedBox(height: 16),
          //         _InfoRow(
          //           icon: Icons.person_outline,
          //           label: 'Customer',
          //           value: preview?.customer.name ?? '—',
          //         ),
          //         _InfoRow(
          //           icon: Icons.phone_outlined,
          //           label: 'Mobile',
          //           value: preview?.customer.mobile ?? 'Not available',
          //         ),
          //         _InfoRow(
          //           icon: Icons.date_range_outlined,
          //           label: 'Plan window',
          //           value:
          //               '${_formatDate(detail.startDate)} – ${_formatDate(detail.endDate)}',
          //         ),
          //         _InfoRow(
          //           icon: Icons.payments_outlined,
          //           label: 'Billing',
          //           value: detail.billingType ?? 'Not specified',
          //         ),
          //         _InfoRow(
          //           icon: Icons.timer_outlined,
          //           label: 'Min days',
          //           value: detail.minDays != null
          //               ? '${detail.minDays}'
          //               : 'Flexible',
          //         ),
          //         const SizedBox(height: 20),
          //         Text('Delivery progress', style: theme.textTheme.bodySmall),
          //         const SizedBox(height: 8),
          //         Row(
          //           children: [
          //             Expanded(
          //               child: ClipRRect(
          //                 borderRadius: BorderRadius.circular(6),
          //                 child: LinearProgressIndicator(
          //                   value: deliveredRatio.clamp(0, 1),
          //                   minHeight: 8,
          //                   backgroundColor: Colors.grey.shade300,
          //                   valueColor: AlwaysStoppedAnimation<Color>(
          //                       theme.primaryColor),
          //                 ),
          //               ),
          //             ),
          //             const SizedBox(width: 12),
          //             Text(
          //               '${detail.unitsDelivered} / ${detail.totalUnits}',
          //               style: theme.textTheme.bodyMedium?.copyWith(
          //                 fontWeight: FontWeight.w600,
          //               ),
          //             ),
          //           ],
          //         ),
          //         if (detail.remainingUnits > 0)
          //           Padding(
          //             padding: const EdgeInsets.only(top: 4),
          //             child: Text(
          //               '${detail.remainingUnits} deliveries remaining',
          //               style: theme.textTheme.bodySmall?.copyWith(
          //                 color: Colors.black54,
          //               ),
          //             ),
          //           ),
          //       ],
          //     ),
          //   ),
          // ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MetricChip(
                label: 'Unit price',
                value: _formatCurrency(detail.unitPricePaise),
              ),
              const SizedBox(width: 8),
              _MetricChip(
                label: 'Total value',
                value: _formatCurrency(detail.totalPaise),
              ),
              const SizedBox(width: 8),
              _MetricChip(
                label: 'Paid',
                value: _formatCurrency(detail.paidPaise),
                color: detail.isPaidInFull ? accent : null,
              ),
            ],
          ),
          // if (detail.itemsIncluded.isNotEmpty) ...[
          //   const SizedBox(height: 16),
          //   _DetailInfoCard(
          //     title: 'Included items',
          //     children: [
          //       Wrap(
          //         spacing: 8,
          //         runSpacing: 8,
          //         children: detail.itemsIncluded
          //             .map(
          //               (item) => Chip(
          //                 label: Text(item),
          //                 backgroundColor: Colors.grey.shade200,
          //               ),
          //             )
          //             .toList(),
          //       ),
          //     ],
          //   ),
          // ],
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: detail.days.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery schedule',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        const Text('No deliveries scheduled yet.'),
                      ],
                    ),
                  )
                : ExpansionTile(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery schedule',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${detail.days.length} Days',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    initiallyExpanded: false,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          children: detail.days
                              .map((day) => _DeliveryDayTile(day: day))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          _SubscriptionActionButtons(
            subscriptionId: detail.id,
            status: detail.status,
            detail: detail,
            preview: preview,
            plan: plan,
          ),
        ],
      ),
    );
  }
}

class _DeliveryDayTile extends StatelessWidget {
  const _DeliveryDayTile({required this.day});
  final SubscriptionDeliveryDay day;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = _formatDate(day.date);
    final hasAddons = day.addons.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  day.status,
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.fastfood_outlined,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('${day.quantity} unit(s)', style: theme.textTheme.bodySmall),
              const SizedBox(width: 12),
              Icon(Icons.currency_rupee,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                _formatCurrency(day.basePricePaise + day.addonsPricePaise),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          if (hasAddons) ...[
            const SizedBox(height: 6),
            Text(
              'Add-ons: ${day.addons.map((a) => a['name']).join(', ')}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (day.instructions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Notes: ${day.instructions}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (day.orderId != null) ...[
            const SizedBox(height: 6),
            Text(
              'Order #${day.orderId} · ${day.orderStatus ?? 'unknown'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    this.color,
  });
  final String label;
  final String value;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: effectiveColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: effectiveColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '—' : value,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Unable to load subscription.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
String _formatCurrency(int paise) {
  final rupees = paise / 100.0;
  final formatted = rupees.truncateToDouble() == rupees
      ? rupees.toStringAsFixed(0)
      : rupees.toStringAsFixed(2);
  return '₹$formatted';
}
String _formatDate(DateTime? date) {
  if (date == null) return '—';
  return DateFormat('d MMM yyyy').format(date);
}

// Action Buttons Widget
class _SubscriptionActionButtons extends StatefulWidget {
  const _SubscriptionActionButtons({
    required this.subscriptionId,
    required this.status,
    required this.detail,
    this.preview,
    this.plan,
  });

  final int subscriptionId;
  final String status;
  final SubscriptionDetail detail;
  final PlanSubscription? preview;
  final SubscriptionPlan? plan;

  @override
  State<_SubscriptionActionButtons> createState() => _SubscriptionActionButtonsState();
}

class _SubscriptionActionButtonsState extends State<_SubscriptionActionButtons> {
  bool _isLoading = false;

  Future<void> _handleReschedule() async {
    // Get upcoming days only (exclude today and past dates)
    final today = DateTime.now();
    final upcomingDays = widget.detail.days
        .where((day) => day.date != null && day.date!.isAfter(today))
        .map((day) => {
              'date': day.date!,
              'qty': day.quantity,
              'id': day.id,
            })
        .toList();

    if (upcomingDays.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No upcoming dates to reschedule')),
      );
      return;
    }

    // Navigate to reschedule screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionCreateSubscriptionScreen(
          isEditMode: true,
          isRescheduleMode: true,
          existingSubscriptionId: widget.subscriptionId,
          existingDays: upcomingDays,
          originalTotalQuantity: widget.detail.totalUnits,
          subscription: widget.preview,
          subscriptionPlan: widget.plan,
        ),
      ),
    );

    // Refresh if rescheduled
    if (result == true && mounted) {
      // Trigger refresh - you may need to use a provider or callback
      Navigator.pop(context, true);
    }
  }

  Future<void> _handleUpdatePayment() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _PaymentUpdateDialog(),
    );

    if (result == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await SubscriptionService.updatePaymentDetails(
        subscriptionId: widget.subscriptionId,
        paymentMethod: result['payment_method'],
        paymentStatus: result['payment_status'],
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment details updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh screen
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleStatusChange(String newStatus, String actionLabel) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _ReasonDialog(
        title: '$actionLabel Subscription',
        hint: 'Reason for ${actionLabel.toLowerCase()}',
      ),
    );

    if (reason == null || !mounted) return;

    // Validate reason is not empty
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SubscriptionService.updateSubscriptionStatus(
        subscriptionId: widget.subscriptionId,
        status: newStatus,
        reason: trimmedReason,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subscription ${actionLabel.toLowerCase()}ed successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh screen
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
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.status.toLowerCase() == 'active';
    final isSuspended = widget.status.toLowerCase() == 'suspended';
    final isCancelled = widget.status.toLowerCase() == 'cancelled';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleReschedule,
                icon: const Icon(Icons.edit_calendar),
                label: const Text('Reschedule'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E3A2F),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleUpdatePayment,
                icon: const Icon(Icons.payment),
                label: const Text('Payment'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E3A2F),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Status Actions
        if (!isCancelled) ...[
          if (isActive)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _handleStatusChange('Paused', 'Suspend'),
                icon: const Icon(Icons.pause_circle_outline),
                label: const Text('Suspend Subscription'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                ),
              ),
            ),
          if (isSuspended)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _handleStatusChange('active', 'Reactivate'),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Reactivate Subscription'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _handleStatusChange('cancelled', 'Cancel'),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel Subscription'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ),
        ],

        if (_isLoading) ...[
          const SizedBox(height: 16),
          const Center(
            child: CircularProgressIndicator(),
          ),
        ],
      ],
    );
  }
}

// Payment Update Dialog
class _PaymentUpdateDialog extends StatefulWidget {
  @override
  State<_PaymentUpdateDialog> createState() => _PaymentUpdateDialogState();
}

class _PaymentUpdateDialogState extends State<_PaymentUpdateDialog> {
  String? _paymentMethod;
  String? _paymentStatus;

  static const _paymentMethods = ['Cash', 'Online', 'Card'];
  static const _paymentStatuses = ['Pending', 'Paid', 'Refunded'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Payment Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            decoration: const InputDecoration(
              labelText: 'Payment Method',
              border: OutlineInputBorder(),
            ),
            items: _paymentMethods
                .map((method) => DropdownMenuItem(
                      value: method,
                      child: Text(method),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _paymentMethod = value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _paymentStatus,
            decoration: const InputDecoration(
              labelText: 'Payment Status',
              border: OutlineInputBorder(),
            ),
            items: _paymentStatuses
                .map((status) => DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _paymentStatus = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_paymentMethod != null || _paymentStatus != null)
              ? () {
                  Navigator.pop(context, {
                    if (_paymentMethod != null) 'payment_method': _paymentMethod!,
                    if (_paymentStatus != null) 'payment_status': _paymentStatus!,
                  });
                }
              : null,
          child: const Text('Update'),
        ),
      ],
    );
  }
}

// Reason Dialog
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.hint,
  });

  final String title;
  final String hint;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: widget.hint,
          border: const OutlineInputBorder(),
        ),
        maxLines: 3,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
