import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:outlet_app/data/models/order_model.dart';
import 'package:outlet_app/providers/business_mode_provider.dart';
import 'package:outlet_app/providers/dashboard_provider.dart';
import 'package:outlet_app/providers/dashboard_refresh_provider.dart';
import 'package:outlet_app/providers/offers_provider.dart';
import 'package:outlet_app/providers/recent_orders_provider.dart';
import 'package:outlet_app/providers/subscription_products_provider.dart';
import 'package:outlet_app/services/order_service.dart';
import 'package:outlet_app/ui/screens/dashboard_v3.dart';
import 'package:outlet_app/ui/screens/delivery_settings_screen.dart';
import 'package:outlet_app/ui/screens/manage_menu_screen.dart';
import 'package:outlet_app/ui/screens/manage_offers_screen.dart';
import 'package:outlet_app/ui/widgets/order_detail_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Color _colorWithOpacity(Color color, double opacity) {
  final raw = (opacity * 255).round();
  final alpha = math.max(0, math.min(255, raw));
  return color.withAlpha(alpha);
}

class DashboardModernScreen extends ConsumerStatefulWidget {
  const DashboardModernScreen({super.key});

  @override
  ConsumerState<DashboardModernScreen> createState() =>
      _DashboardModernScreenState();
}

class _DashboardModernScreenState extends ConsumerState<DashboardModernScreen> {
  bool _isOnline = true;
  int _tabIndex = 0;
  bool _processingAction = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(offerCampaignsProvider.notifier).bootstrap();
    });
  }

  Future<void> _handleStatusToggle(bool value) async {
    setState(() => _isOnline = value);
    // Hook up API call when endpoint is ready.
  }

  Future<void> _handleOrderQuickAction(OrderModel order, String status) async {
    if (_processingAction) return;
    setState(() => _processingAction = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        _showSnack('Missing auth token');
        return;
      }
      final ok = await updateOrderStatus(
        orderId: order.orderId,
        newStatus: status,
        authToken: token,
      );
      if (!mounted) return;
      if (ok) {
        _showSnack('Order ${order.orderId} marked $status');
        ref.invalidate(recentOrdersProvider);
        ref.read(dashboardRefreshProvider.notifier).state = true;
      } else {
        _showSnack('Unable to update order');
      }
    } finally {
      if (mounted) setState(() => _processingAction = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openOrderDetail(OrderModel order) {
    showDialog(
      context: context,
      builder: (_) => OrderDetailDialog(order: order),
    );
  }

  void _handleShortcut(ShortcutAction action) {
    switch (action) {
      case ShortcutAction.addProduct:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManageMenuScreen()),
        );
        break;
      case ShortcutAction.createOffer:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManageOffersScreen()),
        );
        break;
      case ShortcutAction.viewSubscriptions:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DashboardV3Screen()),
        );
        break;
    }
  }

  void _handleNavTap(int index) {
    if (_tabIndex == index) return;
    setState(() => _tabIndex = index);
    switch (index) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DashboardV3Screen()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManageMenuScreen()),
        );
        break;
      case 3:
        _showSnack('Reports module coming soon');
        break;
      default:
        break;
    }
  }

  Future<void> _refreshAll() async {
    ref.invalidate(dashboardProvider);
    ref.invalidate(recentOrdersProvider);
    final supportsSubscriptions = ref.read(dashboardProvider).maybeWhen(
          data: (metrics) => metrics.supportsSubscriptions,
          orElse: () => false,
        );
    if (supportsSubscriptions) {
      ref.invalidate(subscriptionDashboardProvider);
    }
    await ref.read(offerCampaignsProvider.notifier).loadCampaigns();
  }

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(dashboardProvider);
    final ordersAsync = ref.watch(recentOrdersProvider);
    final supportsSubscriptions =
        metricsAsync.asData?.value.supportsSubscriptions ?? false;
    final outletId = metricsAsync.asData?.value.outletId;
    final subsAsync = supportsSubscriptions
        ? ref.watch(subscriptionDashboardProvider)
        : AsyncValue.data(SubscriptionDashboard.empty());
    final offersAsync = ref.watch(offerCampaignsProvider);
    final mode = ref.watch(businessModeProvider);

    return Scaffold(
      drawer: _DrawerSheet(
          mode: mode, supportsSubscriptions: supportsSubscriptions),
      backgroundColor: const Color(0xFFF5F5F5),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: _handleNavTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF54A079),
        unselectedItemColor: Colors.black54,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined), label: 'Catalog'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined), label: 'Reports'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: true,
              snap: true,
              backgroundColor: Colors.white,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Outlet Dashboard',
                      style: TextStyle(
                        color: Color(0xFF1F1B20),
                        fontWeight: FontWeight.w600,
                      )),
                  Text(
                    DateFormat('EEEE, MMM d').format(DateTime.now()),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  )
                ],
              ),
              actions: [
                if (outletId != null && outletId.isNotEmpty)
                  IconButton(
                    tooltip: 'Delivery settings',
                    icon: const Icon(Icons.my_location_outlined,
                        color: Color(0xFF54A079)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DeliverySettingsScreen(outletId: outletId),
                        ),
                      );
                    },
                  ),
                Row(
                  children: [
                    const Text('Offline',
                        style: TextStyle(color: Colors.black54)),
                    Switch.adaptive(
                      value: _isOnline,
                      onChanged: _handleStatusToggle,
                      activeTrackColor:
                          _colorWithOpacity(const Color(0xFF54A079), .4),
                      inactiveTrackColor: Colors.black26,
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _StatsStrip(
                    metrics: metricsAsync,
                    orders: ordersAsync,
                    subs: subsAsync,
                  ),
                  const SizedBox(height: 16),
                  _ShortcutsGrid(
                    onTap: _handleShortcut,
                    showSubscriptionShortcut: supportsSubscriptions,
                  ),
                  const SizedBox(height: 24),
                  _RecentOrdersSection(
                    ordersAsync: ordersAsync,
                    onView: _openOrderDetail,
                    onAccept: (order) =>
                        _handleOrderQuickAction(order, 'Accepted'),
                    onReject: (order) =>
                        _handleOrderQuickAction(order, 'Rejected'),
                    busy: _processingAction,
                  ),
                  const SizedBox(height: 24),
                  if (supportsSubscriptions) ...[
                    _SubscriptionSnapshot(subsAsync: subsAsync),
                    const SizedBox(height: 24),
                  ],
                  _OffersHighlight(offersAsync: offersAsync),
                  const SizedBox(height: 24),
                  const _ReportsPreview(),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ShortcutAction { addProduct, createOffer, viewSubscriptions }

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.metrics,
    required this.orders,
    required this.subs,
  });

  final AsyncValue<DashboardMetrics> metrics;
  final AsyncValue<List<OrderModel>> orders;
  final AsyncValue<SubscriptionDashboard> subs;

  @override
  Widget build(BuildContext context) {
    final metricData = metrics.asData?.value;
    final ordersData = orders.asData?.value ?? const <OrderModel>[];
    final subsData = subs.asData?.value;

    final pendingCount = ordersData.where((o) => o.status == 'Pending').length;
    final preparingCount =
        ordersData.where((o) => o.status == 'Preparing').length;
    final completedCount =
        ordersData.where((o) => o.status == 'Delivered').length;

    final tiles = [
      _StatCard(
        title: "Today's Orders",
        value: metricData?.totalOrders.toString() ?? '--',
        icon: Icons.shopping_bag_outlined,
      ),
      _StatCard(
        title: "Today's Revenue",
        value: metricData != null
            ? '₹${metricData.totalRevenue.toStringAsFixed(0)}'
            : '--',
        icon: Icons.currency_rupee_outlined,
      ),
      _StatCard(
        title: 'Pending Orders',
        value: pendingCount.toString(),
        icon: Icons.timelapse,
      ),
      _StatCard(
        title: 'Preparing',
        value: preparingCount.toString(),
        icon: Icons.local_fire_department_outlined,
      ),
      _StatCard(
        title: 'Completed',
        value: completedCount.toString(),
        icon: Icons.check_circle_outline,
      ),
      _StatCard(
        title: 'Subs Today',
        value: subsData?.meta.orderCount.toString() ?? '0',
        icon: Icons.repeat,
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: tiles,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 2 - 22,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF54A079)),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutsGrid extends StatelessWidget {
  const _ShortcutsGrid(
      {required this.onTap, required this.showSubscriptionShortcut});

  final void Function(ShortcutAction action) onTap;
  final bool showSubscriptionShortcut;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _ShortcutTile(
        label: 'Add Product',
        icon: Icons.add_box_outlined,
        color: const Color(0xFF54A079),
        onTap: () => onTap(ShortcutAction.addProduct),
      ),
      _ShortcutTile(
        label: 'Create Offer',
        icon: Icons.local_offer_outlined,
        color: const Color(0xFF4E7EF5),
        onTap: () => onTap(ShortcutAction.createOffer),
      ),
    ];

    if (showSubscriptionShortcut) {
      cards.add(
        _ShortcutTile(
          label: 'View Subscriptions',
          icon: Icons.event_repeat_outlined,
          color: const Color(0xFFE67E22),
          onTap: () => onTap(ShortcutAction.viewSubscriptions),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
          children: cards,
        ),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _colorWithOpacity(color, .12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 72),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, height: 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentOrdersSection extends StatelessWidget {
  const _RecentOrdersSection({
    required this.ordersAsync,
    required this.onView,
    required this.onAccept,
    required this.onReject,
    required this.busy,
  });

  final AsyncValue<List<OrderModel>> ordersAsync;
  final void Function(OrderModel order) onView;
  final void Function(OrderModel order) onAccept;
  final void Function(OrderModel order) onReject;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent Orders',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DashboardV3Screen()),
              ),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Unable to load orders: $e')),
          data: (orders) {
            if (orders.isEmpty) {
              return const _EmptyPanel(message: 'No orders yet today.');
            }
            final visible = orders.take(5).toList();
            return Column(
              children: [
                for (final order in visible)
                  _RecentOrderTile(
                    order: order,
                    onView: () => onView(order),
                    onAccept: () => onAccept(order),
                    onReject: () => onReject(order),
                    busy: busy,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  const _RecentOrderTile({
    required this.order,
    required this.onView,
    required this.onAccept,
    required this.onReject,
    required this.busy,
  });

  final OrderModel order;
  final VoidCallback onView;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool busy;

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFF4B400);
      case 'Preparing':
        return const Color(0xFF42A5F5);
      case 'Ready':
        return const Color(0xFF7E57C2);
      case 'Delivered':
        return const Color(0xFF43A047);
      case 'Cancelled':
        return const Color(0xFFE53935);
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.customer,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _colorWithOpacity(color, .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  order.status,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              )
            ],
          ),
          const SizedBox(height: 6),
          Text(order.deliveryAddress ?? 'Pickup',
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          Row(
            children: [
              Chip(
                label: Text('₹${order.netTotal.toStringAsFixed(0)}'),
                backgroundColor: _colorWithOpacity(const Color(0xFF54A079), .1),
                labelStyle: const TextStyle(
                    color: Color(0xFF54A079), fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Text(order.orderType ?? 'OnDemand',
                  style: const TextStyle(color: Colors.black54)),
              const Spacer(),
              IconButton(
                tooltip: 'View details',
                icon: const Icon(Icons.visibility_outlined),
                onPressed: onView,
              ),
              if (order.status == 'Pending') ...[
                TextButton(
                  onPressed: busy ? null : onReject,
                  child: const Text('Reject'),
                ),
                ElevatedButton(
                  onPressed: busy ? null : onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF54A079),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Accept'),
                ),
              ],
            ],
          )
        ],
      ),
    );
  }
}

class _SubscriptionSnapshot extends StatelessWidget {
  const _SubscriptionSnapshot({required this.subsAsync});

  final AsyncValue<SubscriptionDashboard> subsAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Subscription Snapshot',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        subsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('Unable to load subscriptions: $e')),
          data: (dash) {
            if (dash.products.isEmpty) {
              return const _EmptyPanel(
                  message: 'No subscription orders today.');
            }
            final top = dash.products.take(3).toList();
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        title: 'Products',
                        value: dash.meta.productCount.toString(),
                        icon: Icons.inventory_2_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        title: 'Orders Today',
                        value: dash.meta.orderCount.toString(),
                        icon: Icons.repeat,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final product in top)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(height: 4),
                        Text(
                          '${product.totalOrderCount} orders · ${product.slotCount} slots',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: product.slots.take(4).map((slot) {
                            return Chip(
                              label: Text(slot.label),
                              backgroundColor: _colorWithOpacity(
                                  const Color(0xFF54A079), .08),
                              labelStyle: const TextStyle(
                                  fontSize: 12, color: Color(0xFF54A079)),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OffersHighlight extends StatelessWidget {
  const _OffersHighlight({required this.offersAsync});

  final OfferCampaignsState offersAsync;

  @override
  Widget build(BuildContext context) {
    final active = offersAsync.activeCampaign;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Offers & Campaigns',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageOffersScreen()),
              ),
              child: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (offersAsync.isLoading && active == null)
          const Center(child: CircularProgressIndicator())
        else if (active == null)
          const _EmptyPanel(
              message: 'No active campaigns. Create one to boost sales.')
        else
          Builder(
            builder: (context) {
              final typeLabel =
                  active.offerType.trim().isEmpty ? 'Offer' : active.offerType;
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6FBF8F), Color(0xFF4E916C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 6)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(active.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    if (active.description != null &&
                        active.description!.isNotEmpty)
                      Text(
                        active.description!,
                        style: TextStyle(
                            color: _colorWithOpacity(Colors.white, .85)),
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text(typeLabel),
                          backgroundColor: _colorWithOpacity(Colors.white, .2),
                          labelStyle: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        if (active.value != null)
                          Chip(
                            label: Text(
                                'Value: ${active.value!.toStringAsFixed(0)}'),
                            backgroundColor:
                                _colorWithOpacity(Colors.white, .2),
                            labelStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _ReportsPreview extends StatelessWidget {
  const _ReportsPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reports & Insights',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            children: [
              _ReportTile(
                title: 'Sales Analytics',
                subtitle: 'Daily · Weekly · Monthly trends at a glance.',
                icon: Icons.show_chart,
              ),
              Divider(),
              _ReportTile(
                title: 'Top Selling Products',
                subtitle: 'Identify bestsellers and slow movers instantly.',
                icon: Icons.star_rate_outlined,
              ),
              Divider(),
              _ReportTile(
                title: 'Subscription Health',
                subtitle: 'Track retention, pauses, and plan performance.',
                icon: Icons.favorite_outline,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: _colorWithOpacity(const Color(0xFF54A079), .12),
          child: Icon(icon, color: const Color(0xFF54A079)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: Colors.black38),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _colorWithOpacity(const Color(0xFF54A079), .12),
            child: Icon(icon, color: const Color(0xFF54A079)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          )
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 40, color: Colors.black26),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _DrawerSheet extends StatelessWidget {
  const _DrawerSheet({required this.mode, required this.supportsSubscriptions});

  final BusinessMode mode;
  final bool supportsSubscriptions;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            const ListTile(
              title: Text('Navigation',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            _DrawerTile(
              icon: Icons.people_outline,
              label: 'Customer Management',
              onTap: () => Navigator.pop(context),
            ),
            if (supportsSubscriptions)
              _DrawerTile(
                icon: Icons.subscriptions_outlined,
                label: 'Manage subscriptions',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/manage-subscriptions');
                },
              ),
            _DrawerTile(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () => Navigator.pop(context),
            ),
            _DrawerTile(
              icon: Icons.info_outline,
              label: 'About us',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/about-us');
              },
            ),
            _DrawerTile(
              icon: Icons.support_agent_outlined,
              label: 'Support & Help',
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
            ListTile(
              title: const Text('Mode'),
              subtitle: Text(mode.name),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF54A079)),
      title: Text(label),
      onTap: onTap,
    );
  }
}
