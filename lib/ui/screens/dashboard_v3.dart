import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outlet_app/data/models/order_model.dart';
import 'package:outlet_app/providers/business_mode_provider.dart';
import 'package:outlet_app/providers/dashboard_provider.dart';
import 'package:outlet_app/providers/dashboard_refresh_provider.dart';
import 'package:outlet_app/providers/recent_orders_provider.dart';
import 'package:outlet_app/providers/subscription_products_provider.dart';
import 'package:outlet_app/ui/widgets/order_detail_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:outlet_app/services/order_service.dart';
import 'package:outlet_app/ui/screens/manage_menu_screen.dart';

class DashboardV3Screen extends ConsumerStatefulWidget {
  const DashboardV3Screen({super.key});

  @override
  ConsumerState<DashboardV3Screen> createState() => _DashboardV3ScreenState();
}

class _DashboardV3ScreenState extends ConsumerState<DashboardV3Screen> {
  // 'OnDemand' | 'Subscription'
  String _selectedType = 'OnDemand';
  late final ProviderSubscription<bool> _dashboardListener;
  late final ProviderSubscription<BusinessMode> _modeListener;
  int _bottomIndex = 0; // Orders, Menu, Reports

  @override
  void initState() {
    super.initState();
    // Refresh listeners like V2
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

    // Ensure selected type aligns with current mode
    _modeListener = ref.listenManual<BusinessMode>(
      businessModeProvider,
      (prev, next) {
        _ensureValidSelection(next);
      },
    );
  }

  @override
  void dispose() {
    _dashboardListener.close();
    _modeListener.close();
    super.dispose();
  }

  void _ensureValidSelection(BusinessMode mode) {
    if (!mounted) return;
    switch (mode) {
      case BusinessMode.onDemandOnly:
        if (_selectedType != 'OnDemand') {
          setState(() => _selectedType = 'OnDemand');
        }
        break;
      case BusinessMode.subscriptionOnly:
        if (_selectedType != 'Subscription') {
          setState(() => _selectedType = 'Subscription');
        }
        break;
      case BusinessMode.both:
        // keep existing selection
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(businessModeProvider);
    final ordersAsync = ref.watch(recentOrdersProvider);
    final subsAsync = ref.watch(subscriptionDashboardProvider);
    final metricsAsync = ref.watch(dashboardProvider);

    // Orders filtered by selected type
    OrderTypePredicate typeMatch;
    if (_selectedType == 'Subscription') {
      typeMatch = (o) => (o.orderType ?? 'OnDemand') == 'Subscription';
    } else {
      // OnDemand: include null or 'OnDemand' or 'Scheduled'
      typeMatch = (o) {
        final t = o.orderType ?? 'OnDemand';
        return t == 'OnDemand' || t == 'Scheduled';
      };
    }

    // Precompute counts for labels so tabs render even while loading
    final allOrders = ordersAsync.asData?.value ?? <OrderModel>[];
    final filtered = allOrders.where(typeMatch).toList();
    int countNew = filtered.where((o) => o.status == 'Pending' || o.status == 'Accepted').length;
    int countPreparing = filtered.where((o) => o.status == 'Preparing').length;
    int countReady = filtered.where((o) => o.status == 'Ready').length;
    int countDelivering = filtered.where((o) => o.status == 'Delivering').length;
    int countCompleted = filtered.where((o) => o.status == 'Delivered').length;
    int countCancelled = filtered.where((o) => o.status == 'Cancelled').length;
    String label(String b, int n) => n > 0 ? '$b ($n)' : b;

    // Build
    return DefaultTabController(
      length: 6, // New, Preparing, Ready, Delivering, Completed, Cancelled
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        bottomNavigationBar: _selectedType == 'OnDemand'
            ? BottomNavigationBar(
                currentIndex: _bottomIndex,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: const Color(0xFF54A079),
                unselectedItemColor: Colors.black54,
                onTap: (idx) async {
                  setState(() => _bottomIndex = idx);
                  switch (idx) {
                    case 0:
                      // Orders (we're already on orders dashboard)
                      break;
                    case 1:
                      // Menu
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ManageMenuScreen()),
                      );
                      break;
                    case 2:
                      // Reports placeholder
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
              )
            : null,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Dashboard',
            style: TextStyle(color: Color(0xFF54A079), fontWeight: FontWeight.w600),
          ),
          actions: [
            PopupMenuButton<BusinessMode>(
              icon: const Icon(Icons.tune, color: Color(0xFF54A079)),
              onSelected: (m) => ref.read(businessModeProvider.notifier).setMode(m),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: BusinessMode.onDemandOnly,
                  child: Text('On Demand only'),
                ),
                PopupMenuItem(
                  value: BusinessMode.subscriptionOnly,
                  child: Text('Subscription only'),
                ),
                PopupMenuItem(
                  value: BusinessMode.both,
                  child: Text('Both'),
                ),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: _TopTypeSwitcher(
                mode: mode,
                selected: _selectedType,
                onSelect: (t) => setState(() => _selectedType = t),
              ),
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardProvider);
            ref.invalidate(recentOrdersProvider);
          },
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              if (_selectedType == 'Subscription') {
                return [
                  SliverToBoxAdapter(
                    child: _SubscriptionsOverviewV2(dashboardAsync: subsAsync),
                  ),
                ];
              } else {
                return [
                  SliverToBoxAdapter(
                    child: _KpiStripV3(
                      metricsAsync: metricsAsync,
                      ordersAsync: ordersAsync,
                      filter: typeMatch,
                    ),
                  ),
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                    sliver: SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabsHeaderDelegate(
                        child: Container(
                          color: Colors.white,
                          child: TabBar(
                            isScrollable: true,
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.black54,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicatorPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            indicator: const BoxDecoration(
                              color: Color(0xFF54A079),
                              borderRadius: BorderRadius.all(Radius.circular(16)),
                            ),
                            tabs: [
                              Tab(text: label('New', countNew)),
                              Tab(text: label('Preparing', countPreparing)),
                              Tab(text: label('Ready', countReady)),
                              Tab(text: label('Delivering', countDelivering)),
                              Tab(text: label('Completed', countCompleted)),
                              Tab(text: label('Cancelled', countCancelled)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ];
              }
            },
            body: _selectedType == 'Subscription'
                ? ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: const [SizedBox(height: 1)],
                  )
                : TabBarView(
                    children: [
                      _OrdersListV3(ordersAsync: ordersAsync, filter: typeMatch, statuses: const ['Pending', 'Accepted']),
                      _OrdersListV3(ordersAsync: ordersAsync, filter: typeMatch, statuses: const ['Preparing']),
                      _OrdersListV3(ordersAsync: ordersAsync, filter: typeMatch, statuses: const ['Ready']),
                      _OrdersListV3(ordersAsync: ordersAsync, filter: typeMatch, statuses: const ['Delivering']),
                      _OrdersListV3(ordersAsync: ordersAsync, filter: typeMatch, statuses: const ['Delivered']),
                      _OrdersListV3(ordersAsync: ordersAsync, filter: typeMatch, statuses: const ['Cancelled']),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

typedef OrderTypePredicate = bool Function(OrderModel o);

class _TopTypeSwitcher extends StatelessWidget {
  final BusinessMode mode;
  final String selected; // 'OnDemand' | 'Subscription'
  final ValueChanged<String> onSelect;
  const _TopTypeSwitcher({required this.mode, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final showOnDemand = mode != BusinessMode.subscriptionOnly;
    final showSubscription = mode != BusinessMode.onDemandOnly;
    final buttons = <_TypeButtonSpec>[];
    if (showOnDemand) {
      buttons.add(_TypeButtonSpec('On Demand', 'OnDemand'));
    }
    if (showSubscription) {
      buttons.add(_TypeButtonSpec('Subscription', 'Subscription'));
    }

    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? 0 : 6,
                right: i == buttons.length - 1 ? 0 : 6,
              ),
              child: _PillButton(
                label: buttons[i].label,
                active: selected == buttons[i].value,
                onTap: () => onSelect(buttons[i].value),
              ),
            ),
          ),
      ],
    );
  }
}

class _TypeButtonSpec {
  final String label;
  final String value;
  _TypeButtonSpec(this.label, this.value);
}

class _PillButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _PillButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF54A079) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF54A079), width: 1.2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF54A079),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _KpiStripV3 extends StatelessWidget {
  final AsyncValue<DashboardMetrics> metricsAsync;
  final AsyncValue<List<OrderModel>> ordersAsync;
  final OrderTypePredicate filter;
  const _KpiStripV3({required this.metricsAsync, required this.ordersAsync, required this.filter});

  @override
  Widget build(BuildContext context) {
    return ordersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16.0),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('Failed to load KPIs: $e'),
      ),
      data: (orders) {
        final filtered = orders.where(filter).toList();
        final totalOrders = filtered.length;
        final totalRevenue = filtered.fold<double>(0.0, (sum, o) => sum + o.grossTotal);
        final active = filtered.where((o) => o.status != 'Delivered' && o.status != 'Cancelled').length;
        final cancelled = filtered.where((o) => o.status == 'Cancelled').length;
        final items = [
          _Kpi('Orders', '$totalOrders', Icons.shopping_cart),
          _Kpi('Revenue', '₹ ${totalRevenue.toStringAsFixed(0)}', Icons.currency_rupee),
          _Kpi('Active', '$active', Icons.delivery_dining),
          _Kpi('Cancelled', '$cancelled', Icons.cancel),
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
                color: const Color(0x1A54A079),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(kpi.icon, color: const Color(0xFF54A079)),
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

class _OrdersListV3 extends StatelessWidget {
  final AsyncValue<List<OrderModel>> ordersAsync;
  final OrderTypePredicate filter;
  final List<String> statuses;
  const _OrdersListV3({required this.ordersAsync, required this.filter, required this.statuses});

  @override
  Widget build(BuildContext context) {
    final handle = NestedScrollView.sliverOverlapAbsorberHandleFor(context);
    return ordersAsync.when(
      loading: () => CustomScrollView(
        slivers: [
          SliverOverlapInjector(handle: handle),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (e, _) => CustomScrollView(
        slivers: [
          SliverOverlapInjector(handle: handle),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('Error: $e')),
          ),
        ],
      ),
      data: (orders) {
        final list = orders.where(filter).where((o) => statuses.contains(o.status)).toList();
        return CustomScrollView(
          slivers: [
            SliverOverlapInjector(handle: handle),
            if (list.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No orders in this lane.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final isLast = i == list.length - 1;
                      return Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                        child: _OrderTile(order: list[i]),
                      );
                    },
                    childCount: list.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
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
    final int? delayDelta = hasOnTimeInfo ? (minutesDisplay - approxMins!) : null;
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
                  const _TypeChip(label: 'Subscription', color: Color(0xFF54A079)),
                if ((order.orderType ?? 'OnDemand') == 'Scheduled')
                  const _TypeChip(label: 'Scheduled', color: Colors.blue),
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

class _TabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _TabsHeaderDelegate({required this.child});
  @override
  double get minExtent => kTextTabBarHeight;
  @override
  double get maxExtent => kTextTabBarHeight;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: Colors.white, alignment: Alignment.centerLeft, child: child);
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

class _SubscriptionsOverviewV2 extends StatelessWidget {
  final AsyncValue<SubscriptionDashboard> dashboardAsync;
  const _SubscriptionsOverviewV2({required this.dashboardAsync});

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  bool _isAddon(OrderItem item) => item.productName.toLowerCase().contains('addon') || item.productName.toLowerCase().contains('add-on');

  @override
  Widget build(BuildContext context) {
    return dashboardAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (dash) {
        final products = dash.products;
        final List<_ProductGroup> list = [];
        for (final p in products) {
          final group = _ProductGroup(
            productName: p.name,
            count: p.totalOrderCount,
            orderCount: p.totalOrderCount,
            hasAnyAddons: false,
          );
          for (final slot in p.slots) {
            for (final o in slot.orders) {
              group.orders.add(
                OrderModel(
                  orderId: o.orderId,
                  status: o.status,
                  orderType: 'Subscription',
                  customer: o.customerName,
                  customerMobile: o.customerMobile,
                  grossTotal: o.grossTotal,
                  deliveryCharges: 0.0,
                  netTotal: o.grossTotal,
                  paymentStatus: '',
                  deliveryAddress: o.deliveryAddress,
                  placedAt: o.placedAt,
                  scheduledFor: slot.start,
                  deliveredAt: null,
                  approximateDeliveryDuration: null,
                  approximateDeliveryTime: o.approxDeliveryTime,
                  // Populate a single item for this product so per-order qty shows >=1
                  items: [
                    OrderItem(
                      productName: p.name,
                      quantity: 1,
                      price: 0.0,
                    ),
                  ],
                ),
              );
            }
          }
          list.add(group);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    "Today's Subscriptions by Product",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  if (list.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange, width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Demo', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ProductExpandableTile(data: list[i], isDemo: false),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showProductOrdersSheet(BuildContext context, _ProductGroup group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(group.productName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    Text('Orders: ${group.orderCount}', style: const TextStyle(color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: group.orders.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final o = group.orders[i];
                      final hasAddon = o.items.any(_isAddon);
                      final qty = o.items
                          .where((it) => ! _isAddon(it) && it.productName == group.productName)
                          .fold<int>(0, (s, it) => s + it.quantity);
                      return ListTile(
                        dense: true,
                        title: Text(o.customer),
                        subtitle: Text(o.deliveryAddress ?? ''),
                        trailing: Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF54A079).withOpacity(.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF54A079)),
                              ),
                              child: Text('x$qty', style: const TextStyle(color: Color(0xFF54A079), fontWeight: FontWeight.w600)),
                            ),
                  if (hasAddon)
                    const Icon(Icons.add_circle, color: Colors.blue, size: 18),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductGroup {
  final String productName;
  int count;
  int orderCount;
  bool hasAnyAddons;
  final List<OrderModel> orders;
  _ProductGroup({required this.productName, this.count = 0, this.orderCount = 0, this.hasAnyAddons = false})
      : orders = [];
}

class _ProductExpandableTile extends StatefulWidget {
  final _ProductGroup data;
  final bool isDemo;
  const _ProductExpandableTile({required this.data, required this.isDemo});

  @override
  State<_ProductExpandableTile> createState() => _ProductExpandableTileState();
}

class _ProductExpandableTileState extends State<_ProductExpandableTile>
    with SingleTickerProviderStateMixin {
  // Local phase state per orderId: 'Orders' | 'Packed' | 'Dispatched' | 'Delivered'
  final Map<String, String> _phases = {};
  final Set<String> _updating = {};

  bool _isAddon(OrderItem item) => item.productName.toLowerCase().contains('addon') || item.productName.toLowerCase().contains('add-on');

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0x1A54A079),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.inventory_2, color: Color(0xFF54A079)),
          ),
          title: Text(
            widget.data.productName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Text('${widget.data.orderCount} orders', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              Text('Qty ${widget.data.count}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              if (widget.data.hasAnyAddons)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: const Text('Add-ons', style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              if (widget.isDemo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text('Demo', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          children: _buildPhaseRootChildren(context),
        ),
      ),
    );
  }

  int _rootTab = 0; // 0 Orders,1 Packed,2 Dispatched,3 Delivered
  static const List<String> _phaseLabels = ['Orders', 'Ready', 'Delivering', 'Delivered'];
  final Map<String, String> _demoPhases = {};
  late TabController _phaseController;
  String _labelWithCount(String base, int count) => count > 0 ? '$base ($count)' : base;

  @override
  void initState() {
    super.initState();
    _phaseController = TabController(length: _phaseLabels.length, vsync: this);
    _phaseController.addListener(() {
      if (_rootTab != _phaseController.index) {
        setState(() => _rootTab = _phaseController.index);
      }
    });
  }

  @override
  void dispose() {
    _phaseController.dispose();
    super.dispose();
  }

  String _phaseFromStatus(String status) {
    switch (status) {
      case 'Delivered':
        return 'Delivered';
      case 'Delivering':
        return 'Delivering';
      case 'Ready':
        return 'Ready';
      default:
        return 'Orders';
    }
  }

  List<Widget> _buildPhaseRootChildren(BuildContext context) {
    final labelSelected = _phaseLabels[_rootTab];
    final body = <Widget>[];
    List<int> counts = [0, 0, 0, 0];
    // Helper: snap to 30-min slot
    DateTime slotStart(DateTime t) {
      final m = t.minute < 30 ? 0 : 30;
      return DateTime(t.year, t.month, t.day, t.hour, m);
    }

    String slotLabel(DateTime s) {
      final e = s.add(const Duration(minutes: 30));
      String two(int v) => v.toString().padLeft(2, '0');
      return '${two(s.hour)}:${two(s.minute)} – ${two(e.hour)}:${two(e.minute)}';
    }

    // Demo data path
    if (widget.isDemo) {
      final now = DateTime.now();
      final s1 = slotStart(DateTime(now.year, now.month, now.day, now.hour, 0));
      final s2 = s1.add(const Duration(minutes: 30));
      final s3 = s2.add(const Duration(minutes: 30));
      final Map<String, List<Map<String, dynamic>>> demoData = {
        slotLabel(s1): [
          {"name": 'Rahul', "address": 'Block A, Street 1', "qty": 1, "hasAddon": true},
          {"name": 'Sneha', "address": 'MG Road, 2nd Cross', "qty": 2, "hasAddon": false},
        ],
        slotLabel(s2): [
          {"name": 'Arjun', "address": 'DLF Phase 3', "qty": 1, "hasAddon": false},
        ],
        slotLabel(s3): [
          {"name": 'Priya', "address": 'Sector 21', "qty": 3, "hasAddon": true},
          {"name": 'Karan', "address": 'Park Street', "qty": 1, "hasAddon": false},
        ],
      };
      int totalWithAddon = 0;
      int totalWithoutAddon = 0;
      demoData.forEach((label, rows) {
        // Header per slot
        body.add(_slotHeader(label, rows.length));
        // Rows filtered by phase
        final filtered = <Map<String, dynamic>>[];
        for (var i = 0; i < rows.length; i++) {
          final id = '$label#$i';
          final phase = _demoPhases[id] ?? 'Orders';
          final idx = _phaseLabels.indexOf(phase);
          if (idx >= 0) counts[idx]++;
          if (phase == labelSelected) filtered.add({...rows[i], 'id': id});
        }
        body.add(
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = filtered[i];
              final hasAddon = r['hasAddon'] == true;
              final qty = r['qty'] as int;
              // accumulate totals across all rows regardless of phase
              if (hasAddon) totalWithAddon += qty; else totalWithoutAddon += qty;
              return ListTile(
                dense: true,
                title: Text(r['name'] as String),
                subtitle: Text(r['address'] as String),
                trailing: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF54A079).withOpacity(.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF54A079)),
                      ),
                      child: Text('x$qty', style: const TextStyle(color: Color(0xFF54A079), fontWeight: FontWeight.w600)),
                    ),
                    if (hasAddon)
                      const Icon(Icons.add_circle, color: Colors.blue, size: 18),
                    _demoActionButtonFor(r['id'] as String, _demoPhases[r['id'] as String] ?? 'Orders'),
                  ],
                ),
              );
            },
          ),
        );
      });
      
      return [
        _rootPhaseTabs(counts),
        const SizedBox(height: 5),
        const Divider(height: 1),
        const SizedBox(height: 5),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Column(key: ValueKey(_rootTab), crossAxisAlignment: CrossAxisAlignment.start, children: body),
        ),
      ];
    }

    // Real orders grouping by 30-min slots using scheduledFor if present
    final Map<DateTime, List<OrderModel>> bucket = {};
    for (final o in widget.data.orders) {
      final ts = o.scheduledFor ?? o.placedAt;
      final start = slotStart(ts);
      bucket.putIfAbsent(start, () => []).add(o);
    }
    final keys = bucket.keys.toList()..sort();

    // Real orders path
    int totalWithAddon = 0;
    int totalWithoutAddon = 0;
    for (final k in keys) {
      final label = slotLabel(k);
      final orders = bucket[k]!;
      body.add(_slotHeader(label, orders.length));
      // Filter orders for selected phase
      final filtered = <OrderModel>[];
      for (final o in orders) {
        final phase = _phases[o.orderId] ?? _phaseFromStatus(o.status);
        final idx = _phaseLabels.indexOf(phase);
        if (idx >= 0) counts[idx]++;
        if (phase == labelSelected) filtered.add(o);
      }
      body.add(
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final o = filtered[i];
            final hasAddon = o.items.any(_isAddon);
            final qty = o.items
                .where((it) => !_isAddon(it) && it.productName == widget.data.productName)
                .fold<int>(0, (s, it) => s + it.quantity);
            // accumulate totals irrespective of phase
            if (hasAddon) totalWithAddon += qty; else totalWithoutAddon += qty;
            return ListTile(
              dense: true,
              title: Text(o.customer),
              subtitle: Text(o.deliveryAddress ?? ''),
              trailing: Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF54A079).withOpacity(.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF54A079)),
                    ),
                    child: Text('x$qty', style: const TextStyle(color: Color(0xFF54A079), fontWeight: FontWeight.w600)),
                  ),
                  if (hasAddon)
                    const Icon(Icons.add_circle, color: Colors.blue, size: 18),
                  _actionButtonFor(o.orderId, _phases[o.orderId] ?? _phaseFromStatus(o.status)),
                ],
              ),
            );
          },
        ),
      );
      // Also count orders not currently visible to totals
      for (final o in orders) {
        final hasAddon = o.items.any(_isAddon);
        final qty = o.items
            .where((it) => !_isAddon(it) && it.productName == widget.data.productName)
            .fold<int>(0, (s, it) => s + it.quantity);
        if (hasAddon) totalWithAddon += qty; else totalWithoutAddon += qty;
      }
    }
    
    return [
      _rootPhaseTabs(counts),
      const SizedBox(height: 5),
      const Divider(height: 1),
      const SizedBox(height: 5),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Column(key: ValueKey(_rootTab), crossAxisAlignment: CrossAxisAlignment.start, children: body),
      ),
    ];
  }

  Widget _slotHeader(String label, int count) => Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF54A079).withOpacity(.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF54A079)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1F1B20),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF54A079)),
              ),
              child: Text(
                '$count orders',
                style: const TextStyle(color: Color(0xFF54A079), fontWeight: FontWeight.w600, fontSize: 12),
              ),
            )
          ],
        ),
      );

  Widget _rootPhaseTabs(List<int> counts) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: TabBar(
          controller: _phaseController,
          isScrollable: true,
          dividerColor: Colors.transparent,
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF54A079),
          indicator: BoxDecoration(
            color: const Color(0xFF54A079),
            borderRadius: BorderRadius.circular(16),
          ),
          indicatorPadding: const EdgeInsets.symmetric(vertical: 4,),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: Text(_labelWithCount('Orders', counts[0])))),
            Tab(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: Text(_labelWithCount('Ready', counts[1])))),
            Tab(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: Text(_labelWithCount('Delivering', counts[2])))),
            Tab(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: Text(_labelWithCount('Delivered', counts[3])))),
          ],
        ),
      );

  Widget _demoRow(String name, String address, {required int qty, bool hasAddon = false}) {
    return ListTile(
      dense: true,
      title: Text(name),
      subtitle: Text(address),
      trailing: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF54A079).withOpacity(.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF54A079)),
            ),
            child: Text('x$qty', style: const TextStyle(color: Color(0xFF54A079), fontWeight: FontWeight.w600)),
          ),
                  if (hasAddon)
                    const Icon(Icons.add_circle, color: Colors.blue, size: 18),
        ],
      ),
    );
  }

  Widget _actionButtonFor(String orderId, String phase) {
    String? next;
    String? label;
    if (phase == 'Orders') { next = 'Ready'; label = 'Ready'; }
    else if (phase == 'Ready') { next = 'Delivering'; label = 'Delivering'; }
    else if (phase == 'Delivering') { next = 'Delivered'; label = 'Deliver'; }

    if (next == null) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }

    if (_updating.contains(orderId)) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return ElevatedButton(
      onPressed: () async {
        setState(() => _updating.add(orderId));
        bool ok = false;
        try {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');
          if (token == null) throw Exception('Not authenticated');
          ok = await updateOrderStatus(orderId: orderId, newStatus: next!, authToken: token);
        } catch (e) {
          ok = false;
        }
        if (!mounted) return;
        if (ok) {
          _phases[orderId] = next!;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update status')), 
          );
        }
        setState(() => _updating.remove(orderId));
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF54A079),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label!, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }

  Widget _demoActionButtonFor(String id, String phase) {
    String? next;
    String? label;
    if (phase == 'Orders') { next = 'Ready'; label = 'Ready'; }
    else if (phase == 'Ready') { next = 'Delivering'; label = 'Delivering'; }
    else if (phase == 'Delivering') { next = 'Delivered'; label = 'Deliver'; }

    if (next == null) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }

    return ElevatedButton(
      onPressed: () {
        _demoPhases[id] = next!;
        setState(() {});
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF54A079),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label!, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

class _ProductSummaryCard extends StatelessWidget {
  final _ProductGroup data;
  final VoidCallback onTap;
  const _ProductSummaryCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0x1A54A079),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.inventory_2, color: Color(0xFF54A079)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${data.orderCount} orders',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                        softWrap: true,
                      ),
                      Text(
                        'Qty ${data.count}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                        softWrap: true,
                      ),
                      if (data.hasAnyAddons)
                        const Icon(Icons.add_circle, color: Colors.blue, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
