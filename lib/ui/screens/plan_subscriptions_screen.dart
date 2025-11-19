import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:outlet_app/data/models/plan_subscription.dart';
import 'package:outlet_app/data/models/subscription_plan.dart';
import 'package:outlet_app/providers/plan_subscriptions_provider.dart';

class PlanSubscriptionsScreen extends ConsumerWidget {
  const PlanSubscriptionsScreen({super.key, required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSubscriptions = ref.watch(planSubscriptionsProvider(plan.id));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${plan.product?.name ?? 'Plan'} subscribers'),
        backgroundColor: const Color(0xFF54A079),
      ),
      body: SafeArea(
        child: asyncSubscriptions.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            message: 'Unable to load subscriptions',
            onRetry: () => ref.refresh(planSubscriptionsProvider(plan.id)),
          ),
          data: (subscriptions) {
            if (subscriptions.isEmpty) {
              return const _EmptyState();
            }
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.refresh(planSubscriptionsProvider(plan.id)),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                itemCount: subscriptions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final subscription = subscriptions[index];
                  return _SubscriptionCard(
                    subscription: subscription,
                    theme: theme,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription, required this.theme});

  final PlanSubscription subscription;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final address = subscription.address;
    final currencyFormatter =
        NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final totalAmount = subscription.totalPaise / 100.0;
    final paidAmount = subscription.paidPaise / 100.0;
    final remainingAmount = (subscription.remainingPaise) / 100.0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscription.customer.name ?? 'Unnamed customer',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subscription.customer.mobile?.isNotEmpty == true)
                        Text(
                          subscription.customer.mobile!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
                _StatusChip(status: subscription.status),
              ],
            ),
            if (address != null && address.addressLine?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: address.label ?? 'Delivery address',
                value: address.addressLine!,
                helper: address.pinCode,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _BadgeChip(
                  icon: Icons.today_outlined,
                  label: 'Start',
                  value: _formatDate(subscription.startDate) ?? '—',
                ),
                _BadgeChip(
                  icon: Icons.calendar_month_outlined,
                  label: 'End',
                  value: _formatDate(subscription.endDate) ?? 'Open ended',
                ),
                _BadgeChip(
                  icon: Icons.event_repeat_outlined,
                  label: 'Days',
                  value: (subscription.numberOfDays ?? 0).toString(),
                ),
                _BadgeChip(
                  icon: Icons.fastfood_outlined,
                  label: 'Quantity',
                  value: (subscription.totalQuantity ?? 0).toString(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _AmountBreakdown(
              currencyFormatter: currencyFormatter,
              paidAmount: paidAmount,
              totalAmount: totalAmount,
              remainingAmount: remainingAmount,
              billingType: subscription.billingType,
            ),
            const SizedBox(height: 16),
            Text(
              'Subscribed on ${_formatDateTime(subscription.createdAt) ?? 'unknown'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return DateFormat('d MMM yyyy').format(date);
  }

  String? _formatDateTime(DateTime? date) {
    if (date == null) return null;
    return DateFormat('d MMM yyyy, h:mm a').format(date);
  }
}

class _AmountBreakdown extends StatelessWidget {
  const _AmountBreakdown({
    required this.currencyFormatter,
    required this.paidAmount,
    required this.totalAmount,
    required this.remainingAmount,
    required this.billingType,
  });

  final NumberFormat currencyFormatter;
  final double paidAmount;
  final double totalAmount;
  final double remainingAmount;
  final String? billingType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(16),
      ),
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
                    _AmountRow(
                      label: 'Total billed',
                      value: currencyFormatter.format(totalAmount),
                    ),
                    const SizedBox(height: 8),
                    _AmountRow(
                      label: 'Paid amount',
                      value: currencyFormatter.format(paidAmount),
                    ),
                    const SizedBox(height: 8),
                    _AmountRow(
                      label: 'Outstanding',
                      value: currencyFormatter.format(remainingAmount),
                      highlight: remainingAmount > 0,
                    ),
                  ],
                ),
              ),
              if (billingType != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Billing',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Chip(
                      label: Text(billingType!),
                      backgroundColor: Colors.white,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.black54,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
            color: highlight ? const Color(0xFFB3261E) : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.helper,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
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
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium,
              ),
              if (helper != null)
                Text(
                  helper!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black45,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF54A079).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF54A079)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.black54,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final formatted = status
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'),
            (match) => '${match.group(1)} ${match.group(2)}')
        .toUpperCase();
    final color = _statusColor(status);
    return Chip(
      backgroundColor: color.withOpacity(0.12),
      label: Text(formatted),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 48, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              'No subscriptions for this plan yet.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return const Color(0xFF1B8966);
    case 'pendingpayment':
    case 'pending payment':
      return const Color(0xFFD47A27);
    case 'cancelled':
    case 'expired':
      return const Color(0xFFB3261E);
    default:
      return const Color(0xFF3F4A58);
  }
}
