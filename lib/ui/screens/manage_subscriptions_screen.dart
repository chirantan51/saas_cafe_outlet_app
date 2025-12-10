import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outlet_app/data/models/subscription_plan.dart';
import 'package:outlet_app/providers/subscription_plans_provider.dart';
import 'package:outlet_app/ui/screens/subscription_plan_detail_screen.dart';

class ManageSubscriptionsScreen extends ConsumerWidget {
  const ManageSubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, '/create-subscription-plan');
        },
        icon: const Icon(Icons.add),
        label: const Text('New plan'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 6,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(88),
        child: AppBar(
          elevation: 0,
          centerTitle: false,
          titleSpacing: 16,
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor,
                  Color(0xFF3B7C5F),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage Subscriptions',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Review plans and subscribers',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => ref.refresh(subscriptionPlansProvider),
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
      body: SafeArea(
        child: plansAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _ErrorState(
            message: 'Unable to load subscription plans',
            onRetry: () => ref.refresh(subscriptionPlansProvider),
          ),
          data: (plans) {
            if (plans.isEmpty) {
              return const _EmptyState();
            }
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.refresh(subscriptionPlansProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: plans.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _SubscriptionPlanListTile(plan: plans[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SubscriptionPlanListTile extends StatelessWidget {
  const _SubscriptionPlanListTile({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = plan.product;
    final price = product?.price;
    final items = product?.itemsIncluded ?? const [];
    final mins = plan.minDays;
    final summaryLines = <String>[];

    if (price != null && price.isNotEmpty) {
      summaryLines.add('₹$price');
    }

    if (items.isNotEmpty) {
      final summary = items.take(3).join(', ');
      final remaining = items.length > 3 ? ' +${items.length - 3} more' : '';
      summaryLines.add('Includes: $summary$remaining');
    }

    if (mins != null && mins > 0) {
      summaryLines.add('Min ${mins} day plan');
    }

    final activeCount = plan.activeSubscriptionsCount ?? 0;
    final titleRaw = product?.name?.trim();
    final title = titleRaw != null && titleRaw.isNotEmpty
        ? titleRaw
        : 'Subscription Plan';
    //final avatarLabel = title.isNotEmpty ? title[0].toUpperCase() : 'S';
    final avatarLabel = activeCount.toString();

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SubscriptionPlanDetailScreen(plan: plan),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.primaryColor.withOpacity(0.08)),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.primaryColor.withOpacity(0.12),
                  child: Text(
                    avatarLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (summaryLines.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 16),
                          child: Text(
                            summaryLines.join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                              height: 1.35,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black26),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // _StatPill(
                //   icon: Icons.people_alt_outlined,
                //   label: '$activeCount subscriptions',
                // ),
                if (mins != null && mins > 0)
                  _StatPill(
                    context: context,
                    icon: Icons.calendar_month_outlined,
                    label: 'Min ${mins} days',
                  ),
                if (plan.vegType != null && plan.vegType!.isNotEmpty)
                  _StatPill(
                    context: context,
                    icon: Icons.restaurant_menu_outlined,
                    label: plan.vegType!,
                  ),
                if (plan.allowSundays != null)
                  _StatPill(
                    context: context,
                    icon: plan.allowSundays!
                        ? Icons.wb_sunny
                        : Icons.do_not_disturb_on_outlined,
                    label:
                        plan.allowSundays! ? 'Sundays allowed' : 'No Sundays',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _StatPill({required BuildContext context, required IconData icon, required String label}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.primaryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A2F),
            ),
          ),
        ],
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
            const Icon(Icons.inbox_outlined, size: 48, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              'No subscription plans yet.\nCreate one from your dashboard to see it here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
