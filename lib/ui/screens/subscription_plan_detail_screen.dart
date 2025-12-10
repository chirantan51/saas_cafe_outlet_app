import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:outlet_app/data/models/plan_subscription.dart';
import 'package:outlet_app/data/models/subscription_plan.dart';
import 'package:outlet_app/providers/plan_subscriptions_provider.dart';
import 'package:outlet_app/providers/subscription_plans_provider.dart';
import 'package:outlet_app/ui/screens/create_subscription_plan_screen.dart';
import 'package:outlet_app/ui/screens/subscription_create_subscription.dart';
import 'package:outlet_app/ui/screens/subscription_subscription_detail_screen.dart';

class SubscriptionPlanDetailScreen extends ConsumerWidget {
  const SubscriptionPlanDetailScreen({super.key, required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = plan.product;
    final accent = Theme.of(context).primaryColor;

    Future<bool> _handlePop() async {
      ref.invalidate(subscriptionPlansProvider);
      return true;
    }

    return WillPopScope(
      onWillPop: _handlePop,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _handlePop();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(product?.name ?? 'Subscription Plan'),
          actions: [
            IconButton(
              tooltip: 'Edit plan',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => EditSubscriptionPlanScreen(plan: plan),
                  ),
                );
                if (result == true) {
                  ref.invalidate(subscriptionPlansProvider);
                  SubscriptionPlan? refreshedPlan;
                  try {
                    final plans =
                        await ref.read(subscriptionPlansProvider.future);
                    for (final p in plans) {
                      if (p.id == plan.id) {
                        refreshedPlan = p;
                        break;
                      }
                    }
                  } catch (_) {}
                  if (!context.mounted) return;
                  if (refreshedPlan != null) {
                    // Plan still exists - it was updated
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) =>
                            SubscriptionPlanDetailScreen(plan: refreshedPlan!),
                      ),
                    );
                  } else {
                    // Plan doesn't exist anymore - it was deleted
                    Navigator.of(context).pop();
                  }
                }
              },
            ),
            IconButton(
              tooltip: 'Plan summary',
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    insetPadding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _SummaryCard(plan: plan),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SubscriptionCreateSubscriptionScreen(
                  subscriptionPlan: plan,
                ),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('New Subscription'),
        ),
        body: Container(
          color: Colors.grey.shade200,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // _QuickStatsStrip(plan: plan),
                  // if ((product?.itemsIncluded ?? const []).isNotEmpty) ...[
                  //   const SizedBox(height: 16),
                  //   _IncludedItemsCard(items: product!.itemsIncluded),
                  // ],
                  //const SizedBox(height: 16),
                  _PlanSubscriptionsPreview(plan: plan),
                  if (plan.servingZones.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _InfoCard(
                      title: 'Serving zones',
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: plan.servingZones
                              .map(
                                (zone) => Chip(
                                  label: Text('Zone $zone'),
                                  backgroundColor: Colors.grey.shade200,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    final product = plan.product;
    final theme = Theme.of(context);
    final accent = Theme.of(context).primaryColor;

    final status = product?.status ?? 'Unknown';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(22),
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
                        product?.name ?? 'Subscription Plan',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((product?.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          product!.description!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'Product ID: ${plan.productId}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (product?.price != null && product!.price!.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      '₹${product.price}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _TagChip(
                  icon: Icons.assignment_outlined,
                  label: status,
                  color: _statusColor(status),
                ),
                _TagChip(
                  icon: Icons.calendar_today_outlined,
                  label: plan.minDays != null
                      ? '${plan.minDays} day minimum'
                      : 'Flexible tenure',
                ),
                _TagChip(
                  icon: Icons.restaurant_menu_outlined,
                  label: plan.vegType ?? 'Diet not set',
                ),
                _TagChip(
                  icon: Icons.spa_outlined,
                  label: plan.jainCompatible == true
                      ? 'Jain compatible'
                      : 'Not Jain friendly',
                  outlined: plan.jainCompatible != true,
                ),
                _TagChip(
                  icon: Icons.wb_sunny_outlined,
                  label: plan.allowSundays == true
                      ? 'Sundays allowed'
                      : 'No Sunday service',
                  outlined: plan.allowSundays != true,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _InfoTile(
              icon: Icons.currency_rupee,
              label: 'Price',
              value: product?.price != null && product!.price!.isNotEmpty
                  ? '₹${product.price}'
                  : 'Not set',
            ),
            _InfoTile(
              icon: Icons.assignment_outlined,
              label: 'Status',
              value: product?.status ?? 'Unknown',
            ),
            _InfoTile(
              icon: Icons.calendar_today_outlined,
              label: 'Minimum tenure',
              value: plan.minDays != null
                  ? '${plan.minDays} day plan'
                  : 'Not specified',
            ),
            _InfoTile(
              icon: Icons.restaurant_menu_outlined,
              label: 'Veg type',
              value: plan.vegType ?? 'Not specified',
            ),
            _InfoTile(
              icon: Icons.spa_outlined,
              label: 'Jain compatible',
              value: _yesNo(plan.jainCompatible),
            ),
            _InfoTile(
              icon: Icons.wb_sunny_outlined,
              label: 'Deliver on Sundays',
              value: _yesNo(plan.allowSundays),
            ),
            _InfoTile(
              icon: Icons.inventory_2_outlined,
              label: 'Daily quantity limit',
              value: plan.dailyQtyLimit?.toString() ?? 'No limit set',
            ),
          ],
        ),
      ),
    );
  }
}

class _IncludedItemsCard extends StatelessWidget {
  const _IncludedItemsCard({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'What\'s included',
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $item'),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ServingDetailsCard extends StatelessWidget {
  const _ServingDetailsCard({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if ((plan.servingArea ?? '').isNotEmpty) {
      rows.add(
        _InfoTile(
          icon: Icons.map_outlined,
          label: 'Serving area',
          value: plan.servingArea!,
        ),
      );
    }

    rows.add(
      _InfoTile(
        icon: Icons.timer_outlined,
        label: 'Slot duration',
        value: plan.slotMinutesOverride != null
            ? '${plan.slotMinutesOverride} minutes'
            : 'Default from outlet',
      ),
    );

    rows.add(
      _InfoTile(
        icon: Icons.people_outline,
        label: 'Capacity per slot',
        value: plan.capacityPerSlotOverride != null
            ? plan.capacityPerSlotOverride.toString()
            : 'Not capped',
      ),
    );

    if (plan.windowStartOverride != null || plan.windowEndOverride != null) {
      rows.add(
        _InfoTile(
          icon: Icons.schedule,
          label: 'Serving window',
          value:
              '${plan.windowStartOverride ?? '--:--'} - ${plan.windowEndOverride ?? '--:--'}',
        ),
      );
    }

    return _InfoCard(title: 'Serving details', children: rows);
  }
}

class _DiscountTiersCard extends StatelessWidget {
  const _DiscountTiersCard({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Discount tiers',
      children: plan.discountTiers
          .map(
            (tier) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${tier.qty ?? '-'} days · ${_discountLabel(tier)}',
              ),
            ),
          )
          .toList(),
    );
  }

  String _discountLabel(SubscriptionDiscountTier tier) {
    if (tier.percentOff != null) {
      return '${tier.percentOff!.toStringAsFixed(0)}% off';
    }
    if (tier.flatOff != null) {
      return '₹${tier.flatOff!.toStringAsFixed(0)} off/day';
    }
    return 'Custom discount';
  }
}

class _HolidaysCard extends StatelessWidget {
  const _HolidaysCard({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Upcoming holidays',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: plan.holidaysList
              .map(
                (holiday) => Chip(
                  label: Text(holiday),
                  backgroundColor: Colors.grey.shade200,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _QuickStatsStrip extends StatelessWidget {
  const _QuickStatsStrip({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    final stats = <Widget>[
      _QuickStatCard(
        label: 'Active subs',
        value: (plan.activeSubscriptionsCount ?? 0).toString(),
        icon: Icons.people_outline,
      ),
      _QuickStatCard(
        label: 'Minimum days',
        value: plan.minDays != null ? '${plan.minDays}' : '—',
        icon: Icons.calendar_today_outlined,
      ),
      _QuickStatCard(
        label: 'Daily limit',
        value: plan.dailyQtyLimit?.toString() ?? 'Unlimited',
        icon: Icons.inventory_outlined,
      ),
      if (plan.discountTiers.isNotEmpty)
        _QuickStatCard(
          label: 'Discount tiers',
          value: plan.discountTiers.length.toString(),
          icon: Icons.local_offer_outlined,
        ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: stats,
    );
  }
}

class _PlanSubscriptionsPreview extends ConsumerStatefulWidget {
  const _PlanSubscriptionsPreview({required this.plan});

  final SubscriptionPlan plan;

  @override
  ConsumerState<_PlanSubscriptionsPreview> createState() =>
      _PlanSubscriptionsPreviewState();
}

class _PlanSubscriptionsPreviewState
    extends ConsumerState<_PlanSubscriptionsPreview> {
  static const _pageSize = 10;

  final TextEditingController _searchController = TextEditingController();
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _visibleCount = _pageSize;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMore(int totalFiltered) {
    setState(() {
      _visibleCount += _pageSize;
      if (_visibleCount > totalFiltered) {
        _visibleCount = totalFiltered;
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final asyncSubs = ref.watch(planSubscriptionsProvider(plan.id));

    return asyncSubs.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (error, _) => _InfoCard(
        title: 'Subscriptions',
        children: [
          Text(
            'Failed to load subscriptions. Pull to refresh.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      data: (subscriptions) {
        if (subscriptions.isEmpty) {
          return const _InfoCard(
            title: 'Subscriptions',
            children: [
              Text('No subscribers yet.'),
            ],
          );
        }

        final rawQuery = _searchController.text.trim();
        final query = rawQuery.toLowerCase();
        final filtered = query.isEmpty
            ? subscriptions
            : subscriptions
                .where((sub) {
                  final name = sub.customer.name?.toLowerCase() ?? '';
                  final mobile = sub.customer.mobile?.toLowerCase() ?? '';
                  final addressLine = sub.address?.addressLine?.toLowerCase() ?? '';
                  final label = sub.address?.label?.toLowerCase() ?? '';
                  return name.contains(query) ||
                      mobile.contains(query) ||
                      addressLine.contains(query) ||
                      label.contains(query);
                })
                .toList();

        final totalFiltered = filtered.length;
        final visibleCount =
            totalFiltered < _visibleCount ? totalFiltered : _visibleCount;
        final visibleSubs = filtered.take(visibleCount).toList();
        final hiddenCount = totalFiltered - visibleCount;

        return Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Subscriptions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by name, mobile, or address',
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: _clearSearch,
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            if (visibleSubs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  query.isEmpty
                      ? 'No subscribers yet.'
                      : 'No subscriptions match "$rawQuery".',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black54),
                ),
              )
            else ...[
              for (final sub in visibleSubs) ...[
                _SubscriptionPreviewRow(sub: sub, plan: widget.plan),
                if (sub != visibleSubs.last) const SizedBox(height: 12),
              ],
              if (hiddenCount > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _showMore(totalFiltered),
                    child: Text('Show more ($hiddenCount more)'),
                  ),
                ),
              if (query.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Showing $visibleCount of $totalFiltered matching subscriptions.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54),
                  ),
                ),
            ],
            if (query.isEmpty && totalFiltered < subscriptions.length)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${subscriptions.length - totalFiltered} '
                  'subscription${subscriptions.length - totalFiltered == 1 ? '' : 's'} '
                  'hidden by filters.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.black54),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SubscriptionPreviewRow extends ConsumerWidget {
  const _SubscriptionPreviewRow({required this.sub, required this.plan});

  final PlanSubscription sub;
  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final start = _formatDate(sub.startDate) ?? '—';
    final totalQty = sub.totalQuantity ?? 0;
    final deliveredQty = sub.deliveredQuantity ?? 0;
    final remainingQty = totalQty > deliveredQty ? totalQty - deliveredQty : 0;
    final statusColor = _statusColor(sub.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SubscriptionSubscriptionDetailScreen(
                subscriptionId: sub.id,
                preview: sub,
                plan: plan,
              ),
            ),
          );

          // Refresh the subscriptions list if any update was made
          if (result == true && context.mounted) {
            // Trigger a refresh of the plan subscriptions provider
            // This will reload the subscription list
            ref.invalidate(planSubscriptionsProvider(plan.id));
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sub.customer.name ?? 'Customer',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _formatStatus(sub.status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              if (sub.customer.mobile?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    sub.customer.mobile!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.black54),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.today_outlined,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('Start: $start', style: theme.textTheme.bodySmall),
                  if ((sub.numberOfDays ?? 0) > 0) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.calendar_today_outlined,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${sub.numberOfDays} day plan',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: totalQty > 0
                            ? (deliveredQty / totalQty).clamp(0.0, 1.0)
                            : 0,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$deliveredQty / $totalQty',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (remainingQty > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '$remainingQty deliveries remaining',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatStatus(String status) {
    return status.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x15000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.icon,
    required this.label,
    this.color,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? const Color(0xFF1E3A2F);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : effectiveColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: outlined
            ? Border.all(color: effectiveColor.withOpacity(0.4))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: effectiveColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: effectiveColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return const Color(0xFF1B8966);
    case 'inactive':
      return const Color(0xFFD47A27);
    case 'suspended':
      return const Color(0xFFB3261E);
    default:
      return const Color(0xFF44505A);
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...children,
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
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

String _yesNo(bool? value) {
  if (value == null) return 'Not set';
  return value ? 'Yes' : 'No';
}

String? _formatDate(DateTime? date) {
  if (date == null) return null;
  return DateFormat('d MMM yyyy').format(date);
}
