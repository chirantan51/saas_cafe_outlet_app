import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outlet_app/data/models/order_model.dart';
import 'package:outlet_app/providers/dashboard_provider.dart';
import 'package:outlet_app/providers/dashboard_refresh_provider.dart';
import 'package:outlet_app/providers/recent_orders_provider.dart';
import 'package:outlet_app/ui/screens/manage_menu_screen.dart';
import 'package:outlet_app/ui/widgets/order_detail_dialog.dart';

class DashboardV2Screen extends ConsumerStatefulWidget {
  const DashboardV2Screen({super.key});

  @override
  ConsumerState<DashboardV2Screen> createState() => _DashboardV2ScreenState();
}

class _DashboardV2ScreenState extends ConsumerState<DashboardV2Screen> {
  int _selectedIndex = 0; // 0=Home,1=Orders,2=Menu,3=Reports
  late final ProviderSubscription<bool> _dashboardListener;

  @override
  void initState() {
    super.initState();
    _dashboardListener = ref.listenManual<bool>(
      dashboardRefreshProvider,
      (prev, next) {
        if (next == true) {
          ref.invalidate(dashboardProvider);
          ref.invalidate(recentOrdersProvider);
          ref.read(dashboardRefreshProvider.notifier).state = false;
        }
      },
    );
  }

  @override
  void dispose() {
    _dashboardListener.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(dashboardProvider);
    final ordersAsync = ref.watch(recentOrdersProvider);

    // Compute counts per tab from current orders snapshot
    final orders = ordersAsync.asData?.value ?? <OrderModel>[];
    final int countNew = orders.where((o) => o.status == 'Pending' || o.status == 'Accepted').length;
    final int countPreparing = orders.where((o) => o.status == 'Preparing').length;
    final int countReady = orders.where((o) => o.status == 'Ready').length;
    final int countDelivering = orders.where((o) => o.status == 'Delivering').length;
    final int countCompleted = orders.where((o) => o.status == 'Delivered').length;
    final int countCancelled = orders.where((o) => o.status == 'Cancelled').length;
    final int countSubscriptions = orders.where((o) => (o.orderType ?? 'OnDemand') == 'Subscription').length;
    final int countScheduled = orders.where((o) => (o.orderType ?? 'OnDemand') == 'Scheduled').length;

    // Build labels without showing (0)
    String _label(String base, int n) => n > 0 ? '$base ($n)' : base;
    final newLabel = _label('New', countNew);
    final preparingLabel = _label('Preparing', countPreparing);
    final readyLabel = _label('Ready', countReady);
    final deliveringLabel = _label('Delivering', countDelivering);
    final completedLabel = _label('Completed', countCompleted);
    final cancelledLabel = _label('Cancelled', countCancelled);
    final subscriptionsLabel = _label('Subscriptions', countSubscriptions);
    final scheduledLabel = _label('Scheduled', countScheduled);

    return DefaultTabController(
      length: 8,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.black54,
          onTap: (idx) async {
            setState(() => _selectedIndex = idx);
            switch (idx) {
              case 0:
                // Home (Dashboard) — stay here
                break;
              case 1:
                // Orders — currently shown as Live Queue in this screen
                // Optionally, scroll to Live Queue section in future
                break;
              case 2:
                // Menu
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageMenuScreen()),
                );
                break;
              case 3:
                // Reports — placeholder
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reports coming soon')),
                  );
                }
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Menu'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardProvider);
            ref.invalidate(recentOrdersProvider);
          },
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                title: const _HeroBar(),
              ),
              SliverToBoxAdapter(child: _KpiStrip(metricsAsync: metricsAsync)),

              const SliverToBoxAdapter(
                child: _SectionHeader(title: 'Live Queue'),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabHeaderDelegate(
                  TabBar(
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.black54,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    indicator: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    tabs: [
                      Tab(text: newLabel),
                      Tab(text: preparingLabel),
                      Tab(text: readyLabel),
                      Tab(text: deliveringLabel),
                      Tab(text: completedLabel),
                      Tab(text: cancelledLabel),
                      Tab(text: subscriptionsLabel),
                      Tab(text: scheduledLabel),
                    ],
                  ),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: true,
                child: TabBarView(
                  children: [
                    _OrdersList(ordersAsync: ordersAsync, statuses: const ['Pending', 'Accepted']),
                    _OrdersList(ordersAsync: ordersAsync, statuses: const ['Preparing']),
                    _OrdersList(ordersAsync: ordersAsync, statuses: const ['Ready']),
                    _OrdersList(ordersAsync: ordersAsync, statuses: const ['Delivering']),
                    _OrdersList(ordersAsync: ordersAsync, statuses: const ['Delivered']),
                    _OrdersList(ordersAsync: ordersAsync, statuses: const ['Cancelled']),
                    _OrdersList(ordersAsync: ordersAsync, typeFilter: 'Subscription'),
                    _OrdersList(ordersAsync: ordersAsync, typeFilter: 'Scheduled'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBar extends StatefulWidget {
  const _HeroBar();
  @override
  State<_HeroBar> createState() => _HeroBarState();
}

class _HeroBarState extends State<_HeroBar> {
  bool open = true;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Chaiamates',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(child: Container()),
        Transform.scale(
          scale: 0.8, // Reduce visual size of the switch
          child: Switch(
            value: open,
            onChanged: (v) => setState(() => open = v),
            activeColor: Theme.of(context).primaryColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

class _QuickActionsBar extends ConsumerWidget {
  const _QuickActionsBar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Action(
            icon: Icons.menu_book,
            label: 'Menu',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageMenuScreen()),
              );
            },
          ),
          _Action(icon: Icons.bar_chart, label: 'Reports', onTap: () {}),
          _Action(icon: Icons.receipt_long, label: 'Orders', onTap: () {}),
          _Action(icon: Icons.settings, label: 'Settings', onTap: () {}),
        ],
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  final AsyncValue<DashboardMetrics> metricsAsync;
  const _KpiStrip({required this.metricsAsync});

  @override
  Widget build(BuildContext context) {
    return metricsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16.0),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('Failed to load KPIs: $e'),
      ),
      data: (m) {
        final items = [
          _Kpi('Orders', '${m.totalOrders}', Icons.shopping_cart),
          _Kpi('Revenue', '₹ ${m.totalRevenue.toStringAsFixed(0)}', Icons.currency_rupee),
          _Kpi('Active', '${m.pendingOrders}', Icons.delivery_dining),
          _Kpi('Cancelled', '${m.cancelledOrders}', Icons.cancel),
        ];
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: LayoutBuilder(builder: (context, c) {
            final isWide = c.maxWidth > 600;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              childAspectRatio: 2.6,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: items.map((k) => _KpiCard(k)).toList(),
            );
          }),
        );
      },
    );
  }
}

class _OrdersList extends StatelessWidget {
  final AsyncValue<List<OrderModel>> ordersAsync;
  final List<String>? statuses; // null => all statuses
  final String? typeFilter; // 'OnDemand' | 'Subscription' | 'Scheduled'
  const _OrdersList({required this.ordersAsync, this.statuses, this.typeFilter});

  @override
  Widget build(BuildContext context) {
    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (orders) {
        Iterable<OrderModel> filtered = orders;
        if (statuses != null) {
          filtered = filtered.where((o) => statuses!.contains(o.status));
        }
        if (typeFilter != null) {
          filtered = filtered.where((o) => (o.orderType ?? 'OnDemand') == typeFilter);
        }
        final list = filtered.toList();
        if (list.isEmpty) {
          return const Center(child: Text('No orders in this lane.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final o = list[i];
            return _OrderTile(order: o);
          },
        );
      },
    );
  }
}

/* --- Small UI Components --- */

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          FloatingActionButton(
              mini: true,
              onPressed: onTap,
              backgroundColor: Theme.of(context).primaryColor,
              child: Icon(icon)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}

class _Kpi {
  final String title;
  final String value;
  final IconData icon;
  _Kpi(this.title, this.value, this.icon);
}

class _KpiCard extends StatelessWidget {
  final _Kpi kpi;
  const _KpiCard(this.kpi);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(kpi.icon, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kpi.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.0),
                  ),
                  Text(
                    kpi.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.0),
                  ),
                ],
              ),
            ),
          ),
        ]),
      );
}

class _OrderTile extends StatelessWidget {
  final OrderModel order;
  const _OrderTile({required this.order});
  @override
  Widget build(BuildContext context) {
    final bool isDelivered = order.status == 'Delivered' && order.deliveredAt != null;
    final int minutesDisplay = isDelivered
        ? order.deliveredAt!.difference(order.placedAt).inMinutes
        : DateTime.now().difference(order.placedAt).inMinutes;
    final int? approxMins = order.approximateDeliveryDuration;
    final bool hasOnTimeInfo = isDelivered && approxMins != null;
    final int? delayDelta = hasOnTimeInfo ? (minutesDisplay - approxMins!) : null; // >0 means delayed
    return Card(
      child: ListTile(
        leading: _StatusBadge(status: order.status, minutes: minutesDisplay),
        title: Text(order.customer),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.deliveryAddress ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if ((order.orderType ?? 'OnDemand') == 'Subscription')
                  _TypeChip(label: 'Subscription', color: Theme.of(context).primaryColor),
                if ((order.orderType ?? 'OnDemand') == 'Scheduled')
                  _TypeChip(label: 'Scheduled', color: Colors.blue),
                if (hasOnTimeInfo && delayDelta != null)
                  _TypeChip(
                    label: delayDelta <= 0 ? 'Within target' : 'Delayed by ${delayDelta}m',
                    color: delayDelta <= 0 ? Colors.green : Colors.red,
                  ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('₹ ${order.grossTotal.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('$minutesDisplay min',
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ),
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => OrderDetailDialog(order: order),
          );
        },
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TypeChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final int minutes;
  const _StatusBadge({required this.status, required this.minutes});
  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case 'Pending':
        c = Colors.orange;
        break;
      case 'Accepted':
        c = Colors.teal;
        break;
      case 'Preparing':
        c = Colors.blue;
        break;
      case 'Ready':
        c = Colors.green;
        break;
      case 'Delivering':
        c = Colors.purple;
        break;
      case 'Cancelled':
        c = Colors.red;
        break;
      default:
        c = Colors.grey;
    }
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
          color: c.withOpacity(.1),
          shape: BoxShape.circle,
          border: Border.all(color: c, width: 2)),
      alignment: Alignment.center,
      child: Text('$minutes',
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14)),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      );
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabHeaderDelegate(this.tabBar);
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: Colors.white, child: tabBar);
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}
