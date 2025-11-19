import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:outlet_app/data/models/offer_model.dart';
import 'package:outlet_app/data/models/order_model.dart';
import 'package:outlet_app/providers/business_mode_provider.dart';
import 'package:outlet_app/providers/dashboard_provider.dart';
import 'package:outlet_app/providers/dashboard_refresh_provider.dart';
import 'package:outlet_app/providers/offers_provider.dart';
import 'package:outlet_app/providers/recent_orders_provider.dart';
import 'package:outlet_app/providers/subscription_products_provider.dart';
import 'package:outlet_app/ui/screens/manage_menu_screen.dart';
import 'package:outlet_app/ui/screens/manage_offers_screen.dart';
import 'package:outlet_app/ui/screens/create_order_screen.dart';
import 'package:outlet_app/ui/screens/delivery_settings_screen.dart';
import 'package:outlet_app/ui/screens/reports_screen.dart';
import 'package:outlet_app/ui/widgets/order_detail_dialog.dart';
import 'package:outlet_app/services/order_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _connectionSafeMessage(Object error) {
  final message = error.toString();
  if (message.toLowerCase().contains('connection refused')) {
    return 'Unable to reach the server. Please check your internet connection or try again later.';
  }
  return message;
}

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastBackPress;

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
    final supportsSubscriptions = ref.read(dashboardProvider).maybeWhen(
          data: (metrics) => metrics.supportsSubscriptions,
          orElse: () => false,
        );
    switch (mode) {
      case BusinessMode.onDemandOnly:
        if (_selectedType != 'OnDemand') {
          setState(() => _selectedType = 'OnDemand');
        }
        break;
      case BusinessMode.subscriptionOnly:
        if (!supportsSubscriptions) {
          if (_selectedType != 'OnDemand') {
            setState(() => _selectedType = 'OnDemand');
          }
          ref
              .read(businessModeProvider.notifier)
              .setMode(BusinessMode.onDemandOnly);
          break;
        }
        if (_selectedType != 'Subscription') {
          setState(() => _selectedType = 'Subscription');
        }
        break;
      case BusinessMode.both:
        if (!supportsSubscriptions && _selectedType == 'Subscription') {
          setState(() => _selectedType = 'OnDemand');
        }
        break;
    }
  }

  Future<void> _openManageOffers() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageOffersScreen()),
    );
    if (!mounted) return;
    ref.read(offerCampaignsProvider.notifier).loadCampaigns();
  }

  void _openAboutUs() {
    Navigator.pushNamed(context, '/about-us');
  }

  void _openManageSubscriptions() {
    Navigator.pushNamed(context, '/manage-subscriptions');
  }

  Future<void> _openCreateOrder(
      {bool isEditMode = false, OrderModel? order}) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => CreateOrderScreen(
                isEditMode: isEditMode,
                order: order,
              )),
    );
    if (created == true && mounted) {
      ref.read(dashboardRefreshProvider.notifier).state = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(businessModeProvider);
    final ordersAsync = ref.watch(recentOrdersProvider);
    final metricsAsync = ref.watch(dashboardProvider);
    final metrics = metricsAsync.asData?.value;
    final supportsSubscriptions = metrics?.supportsSubscriptions ?? false;
    final supportsOnDemand = metrics?.supportsOnDemand ?? false;
    final outletId = metricsAsync.asData?.value.outletId;
    final subsAsync = supportsSubscriptions
        ? ref.watch(subscriptionDashboardProvider)
        : AsyncValue.data(SubscriptionDashboard.empty());
    final offersState = ref.watch(offerCampaignsProvider);
    final activeOffer = offersState.activeCampaign;

    final selectedType =
        (!supportsSubscriptions && _selectedType == 'Subscription')
            ? 'OnDemand'
            : _selectedType;

    final showTypeSwitcher = supportsOnDemand && supportsSubscriptions;

    if (!supportsSubscriptions && _selectedType == 'Subscription') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedType != 'OnDemand') {
          setState(() => _selectedType = 'OnDemand');
        }
      });
    }

    // Orders filtered by selected type
    OrderTypePredicate typeMatch;
    if (selectedType == 'Subscription') {
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
    int countNew = filtered
        .where((o) => o.status == 'Pending' || o.status == 'Accepted')
        .length;
    int countPreparing = filtered.where((o) => o.status == 'Preparing').length;
    int countReady = filtered.where((o) => o.status == 'Ready').length;
    int countDelivering =
        filtered.where((o) => o.status == 'Delivering').length;
    int countCompleted = filtered.where((o) => o.status == 'Delivered').length;
    int countCancelled = filtered.where((o) => o.status == 'Cancelled').length;
    String label(String b, int n) => n > 0 ? '$b ($n)' : b;

    // Build
    return WillPopScope(
        onWillPop: _handleBackPress,
        child: DefaultTabController(
          length: 6, // New, Preparing, Ready, Delivering, Completed, Cancelled
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: const Color(0xFFF5F5F5),
            floatingActionButton: selectedType == 'OnDemand'
                ? FloatingActionButton.extended(
                    onPressed: _openCreateOrder,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Create order'),
                  )
                : null,
            bottomNavigationBar: selectedType == 'OnDemand'
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
                            MaterialPageRoute(
                                builder: (_) => const ManageMenuScreen()),
                          );
                          break;
                        case 2:
                          // Reports
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ReportsScreen()),
                          );
                          break;
                      }
                    },
                    items: const [
                      BottomNavigationBarItem(
                          icon: Icon(Icons.receipt_long), label: 'Orders'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.menu_book), label: 'Menu'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.bar_chart), label: 'Reports'),
                    ],
                  )
                : null,
            drawer: _DashboardDrawer(
              outletId: outletId,
              onManageOffers: _openManageOffers,
              onDeliverySettings: outletId == null || outletId.isEmpty
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DeliverySettingsScreen(outletId: outletId),
                        ),
                      );
                    },
              onAboutUs: _openAboutUs,
              onManageSubscriptions:
                  supportsSubscriptions ? _openManageSubscriptions : null,
              onCustomerManagement: () =>
                  Navigator.pushNamed(context, '/customer-management'),
            ),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: const Text(
                'Dashboard',
                style: TextStyle(
                    color: Color(0xFF54A079), fontWeight: FontWeight.w600),
              ),
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Color(0xFF54A079)),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(showTypeSwitcher ? 52 : 0),
                child: showTypeSwitcher
                    ? Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: _TopTypeSwitcher(
                          selected: selectedType,
                          supportsSubscriptions: supportsSubscriptions,
                          supportsOnDemand: supportsOnDemand,
                          onSelect: (t) => setState(() => _selectedType = t),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            body: ScrollConfiguration(
              behavior: const _NoStretchScrollBehavior(),
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(dashboardProvider);
                  ref.invalidate(recentOrdersProvider);
                  if (supportsSubscriptions) {
                    ref.invalidate(subscriptionDashboardProvider);
                  }
                  await ref
                      .read(offerCampaignsProvider.notifier)
                      .loadCampaigns();
                },
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    final slivers = <Widget>[];
                    // if (offersState.isLoading && offersState.campaigns.isEmpty) {
                    //   slivers.add(const SliverToBoxAdapter(
                    //     child: Padding(
                    //       padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    //       child: LinearProgressIndicator(minHeight: 2),
                    //     ),
                    //   ));
                    // } else if (activeOffer != null) {
                    //   slivers.add(
                    //     SliverToBoxAdapter(
                    //       child: Padding(
                    //         padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    //         child: _ActiveOfferBanner(
                    //           campaign: activeOffer,
                    //           onManage: _openManageOffers,
                    //         ),
                    //       ),
                    //     ),
                    //   );
                    // } else if (!offersState.isLoading) {
                    //   slivers.add(
                    //     SliverToBoxAdapter(
                    //       child: Padding(
                    //         padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    //         child: _OfferManagePrompt(
                    //           hasCampaigns: offersState.campaigns.isNotEmpty,
                    //           onTap: _openManageOffers,
                    //         ),
                    //       ),
                    //     ),
                    //   );
                    // }

                    if (selectedType == 'Subscription') {
                      slivers.add(
                        SliverToBoxAdapter(
                          child: _SubscriptionsOverviewV2(
                              dashboardAsync: subsAsync),
                        ),
                      );
                    } else {
                      slivers.addAll([
                        SliverToBoxAdapter(
                          child: _KpiStripV3(
                            metricsAsync: metricsAsync,
                            ordersAsync: ordersAsync,
                            filter: typeMatch,
                          ),
                        ),
                        SliverOverlapAbsorber(
                          handle:
                              NestedScrollView.sliverOverlapAbsorberHandleFor(
                                  context),
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
                                  indicatorPadding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 6),
                                  indicator: const BoxDecoration(
                                    color: Color(0xFF54A079),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(16)),
                                  ),
                                  tabs: [
                                    Tab(text: label('New', countNew)),
                                    Tab(
                                        text:
                                            label('Preparing', countPreparing)),
                                    Tab(text: label('Ready', countReady)),
                                    Tab(
                                        text: label(
                                            'Delivering', countDelivering)),
                                    Tab(
                                        text:
                                            label('Completed', countCompleted)),
                                    Tab(
                                        text:
                                            label('Cancelled', countCancelled)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ]);
                    }

                    return slivers;
                  },
                  body: selectedType == 'Subscription'
                      ? ListView(
                          padding: const EdgeInsets.only(bottom: 16),
                          children: const [SizedBox(height: 1)],
                        )
                      : TabBarView(
                          children: [
                            _OrdersListV3(
                                ordersAsync: ordersAsync,
                                filter: typeMatch,
                                statuses: const ['Pending', 'Accepted']),
                            _OrdersListV3(
                                ordersAsync: ordersAsync,
                                filter: typeMatch,
                                statuses: const ['Preparing']),
                            _OrdersListV3(
                                ordersAsync: ordersAsync,
                                filter: typeMatch,
                                statuses: const ['Ready']),
                            _OrdersListV3(
                                ordersAsync: ordersAsync,
                                filter: typeMatch,
                                statuses: const ['Delivering']),
                            _OrdersListV3(
                                ordersAsync: ordersAsync,
                                filter: typeMatch,
                                statuses: const ['Delivered']),
                            _OrdersListV3(
                                ordersAsync: ordersAsync,
                                filter: typeMatch,
                                statuses: const ['Cancelled']),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ));
  }

  Future<bool> _handleBackPress() async {
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
      }
      return false;
    }
    return true;
  }
}

class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _DashboardDrawer extends StatelessWidget {
  const _DashboardDrawer({
    required this.outletId,
    required this.onManageOffers,
    this.onDeliverySettings,
    required this.onAboutUs,
    this.onManageSubscriptions,
    this.onCustomerManagement,
  });

  final String? outletId;
  final VoidCallback onManageOffers;
  final VoidCallback? onDeliverySettings;
  final VoidCallback onAboutUs;
  final VoidCallback? onManageSubscriptions;
  final VoidCallback? onCustomerManagement;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 16, 24),
              color: const Color(0xFF54A079),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Chaimates Outlet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Quick access',
                    style: TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.local_offer_outlined,
                  color: Color(0xFF54A079)),
              title: const Text('Manage offers'),
              onTap: () {
                Navigator.of(context).pop();
                onManageOffers();
              },
            ),
            if (onDeliverySettings != null)
              ListTile(
                leading: const Icon(Icons.my_location_outlined,
                    color: Color(0xFF54A079)),
                title: const Text('Delivery settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  onDeliverySettings?.call();
                },
              ),
            if (onManageSubscriptions != null)
              ListTile(
                leading: const Icon(Icons.subscriptions_outlined,
                    color: Color(0xFF54A079)),
                title: const Text('Manage subscriptions'),
                onTap: () {
                  Navigator.of(context).pop();
                  onManageSubscriptions?.call();
                },
              ),
            if (onCustomerManagement != null)
              ListTile(
                leading:
                    const Icon(Icons.people_outline, color: Color(0xFF54A079)),
                title: const Text('Customer management'),
                onTap: () {
                  Navigator.of(context).pop();
                  onCustomerManagement?.call();
                },
              ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Color(0xFF54A079)),
              title: const Text('About us'),
              onTap: () {
                Navigator.of(context).pop();
                onAboutUs();
              },
            ),
            const Divider(),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    outletId == null || outletId!.isEmpty
                        ? 'No outlet selected'
                        : 'Outlet ID: $outletId',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef OrderTypePredicate = bool Function(OrderModel o);

class _TopTypeSwitcher extends StatelessWidget {
  final String selected; // 'OnDemand' | 'Subscription'
  final bool supportsSubscriptions;
  final bool supportsOnDemand;
  final ValueChanged<String> onSelect;
  const _TopTypeSwitcher(
      {required this.selected,
      required this.supportsSubscriptions,
      required this.supportsOnDemand,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final showOnDemand = supportsOnDemand;
    final showSubscription = supportsSubscriptions;
    final buttons = <_TypeButtonSpec>[];
    if (showOnDemand) {
      buttons.add(_TypeButtonSpec('On Demand', 'OnDemand'));
    }
    if (showSubscription) {
      buttons.add(_TypeButtonSpec('Subscription', 'Subscription'));
    }

    if (buttons.length <= 1) {
      return const SizedBox.shrink();
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
  const _PillButton(
      {required this.label, required this.active, required this.onTap});

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

class _ActiveOfferBanner extends StatelessWidget {
  const _ActiveOfferBanner({required this.campaign, required this.onManage});

  final OfferCampaign campaign;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d · HH:mm');
    final validity = <String>[];
    if (campaign.startAt != null) {
      validity.add('From ${formatter.format(campaign.startAt!.toLocal())}');
    }
    if (campaign.endAt != null) {
      validity.add('Till ${formatter.format(campaign.endAt!.toLocal())}');
    }

    final buffer = StringBuffer();
    if (campaign.minOrderAmount != null && campaign.minOrderAmount! > 0) {
      buffer.write('Min order ₹${campaign.minOrderAmount!.toStringAsFixed(0)}');
    }
    if (campaign.value != null) {
      if (buffer.isNotEmpty) buffer.write(' · ');
      if (campaign.offerType == 'ORDER_PERCENTAGE') {
        buffer.write('${campaign.value!.toStringAsFixed(0)}% off');
      } else {
        buffer.write('₹${campaign.value!.toStringAsFixed(0)} off');
      }
    }
    final headline = buffer.toString();

    final ruleSummary = _summarizeRule(campaign);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6FBF8F), Color(0xFF4E916C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Active Offer',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.white70, letterSpacing: 0.6),
                ),
              ),
              OutlinedButton(
                onPressed: onManage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Manage'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            campaign.name,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          if (headline.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              headline,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white.withOpacity(0.9)),
            ),
          ],
          if (campaign.description != null &&
              campaign.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              campaign.description!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white.withOpacity(0.9)),
            ),
          ],
          if (ruleSummary != null) ...[
            const SizedBox(height: 6),
            Text(
              ruleSummary,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white.withOpacity(0.85)),
            ),
          ],
          if (validity.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              validity.join(' · '),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  String? _summarizeRule(OfferCampaign campaign) {
    if (campaign.rules.isEmpty) return null;
    final rule = campaign.rules.first;
    final parts = <String>[];
    if (rule.productName != null && rule.productName!.isNotEmpty) {
      parts.add(rule.productName!);
    }
    if (rule.minQuantity != null) {
      parts.add('Min qty ${rule.minQuantity}');
    }
    if (rule.freeQuantity != null && rule.freeQuantity! > 0) {
      parts.add('Free ${rule.freeQuantity}');
    }
    if (rule.overrideValue != null) {
      parts.add('Override ₹${rule.overrideValue!.toStringAsFixed(0)}');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _OfferManagePrompt extends StatelessWidget {
  const _OfferManagePrompt({required this.hasCampaigns, required this.onTap});

  final bool hasCampaigns;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(
            hasCampaigns
                ? Icons.local_offer_outlined
                : Icons.new_releases_outlined,
            color: const Color(0xFF54A079),
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasCampaigns ? 'No active offer' : 'Create your first offer',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  hasCampaigns
                      ? 'Activate a promotion to highlight on the dashboard.'
                      : 'Boost orders with discounts, happy hours, or bundle deals.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onTap,
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }
}

class _KpiStripV3 extends StatelessWidget {
  final AsyncValue<DashboardMetrics> metricsAsync;
  final AsyncValue<List<OrderModel>> ordersAsync;
  final OrderTypePredicate filter;
  const _KpiStripV3(
      {required this.metricsAsync,
      required this.ordersAsync,
      required this.filter});

  @override
  Widget build(BuildContext context) {
    return ordersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16.0),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('Failed to load KPIs: ${_connectionSafeMessage(e)}'),
      ),
      data: (orders) {
        final filtered = orders.where(filter).toList();
        final totalOrders = filtered.length;
        final deliveredOrders = filtered.where(
          (o) => o.status.toLowerCase() == 'delivered',
        );
        final totalRevenue = deliveredOrders.fold<double>(
          0.0,
          (sum, o) => sum + o.netTotal,
        );
        final active = filtered
            .where((o) => o.status != 'Delivered' && o.status != 'Cancelled')
            .length;
        final cancelled = filtered.where((o) => o.status == 'Cancelled').length;
        final items = [
          _Kpi('Orders', '$totalOrders', Icons.shopping_cart),
          _Kpi('Revenue', '₹ ${totalRevenue.toStringAsFixed(0)}',
              Icons.currency_rupee),
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
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54, height: 1.0),
                  ),
                  Text(
                    kpi.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, height: 1.0),
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
  const _OrdersListV3(
      {required this.ordersAsync,
      required this.filter,
      required this.statuses});

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
            child: Center(child: Text('Error: ${_connectionSafeMessage(e)}')),
          ),
        ],
      ),
      data: (orders) {
        final list = orders
            .where(filter)
            .where((o) => statuses.contains(o.status))
            .toList();
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
    final bool isDelivered =
        order.status == 'Delivered' && order.deliveredAt != null;
    final int minutesDisplay = isDelivered
        ? order.deliveredAt!.difference(order.placedAt).inMinutes
        : DateTime.now().difference(order.placedAt).inMinutes;
    final int? approxMins = order.approximateDeliveryDuration;
    final bool hasOnTimeInfo = isDelivered && approxMins != null;
    final int? delayDelta =
        hasOnTimeInfo ? (minutesDisplay - approxMins!) : null;
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
                  const _TypeChip(
                      label: 'Subscription', color: Color(0xFF54A079)),
                if ((order.orderType ?? 'OnDemand') == 'Scheduled')
                  const _TypeChip(label: 'Scheduled', color: Colors.blue),
                if (hasOnTimeInfo && delayDelta != null)
                  _TypeChip(
                    label: delayDelta <= 0
                        ? 'Within target'
                        : 'Delayed by ${delayDelta}m',
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
        onLongPress: () {
          order.status != "delivered"
              ? _openCreateOrder(context, isEditMode: true, order: order)
              : null;
        },
      ),
    );
  }

  Future<void> _openCreateOrder(
    BuildContext context, {
    bool isEditMode = false,
    OrderModel? order,
  }) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateOrderScreen(
          isEditMode: isEditMode,
          order: order,
        ),
      ),
    );
    // If you need to trigger a refresh after navigation, you'll need to pass
    // a callback from the parent widget or use a different state management approach
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
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
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
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87)),
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
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(
          color: Colors.white, alignment: Alignment.centerLeft, child: child);
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}

class _SubscriptionsOverviewV2 extends StatelessWidget {
  final AsyncValue<SubscriptionDashboard> dashboardAsync;
  const _SubscriptionsOverviewV2({required this.dashboardAsync});

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  bool _isAddon(OrderItem item) =>
      item.productName.toLowerCase().contains('addon') ||
      item.productName.toLowerCase().contains('add-on');

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
            final bucket = _SlotBucket(label: slot.label, start: slot.start);
            for (final o in slot.orders) {
              final orderModel = OrderModel(
                orderId: o.orderId,
                status: o.status,
                orderType: 'Subscription',
                customer_id: o.customer_id,
                customer: o.customerName,
                customerMobile: o.customerMobile,
                grossTotal: o.grossTotal,
                deliveryCharges: 0.0,
                netTotal: o.grossTotal,
                paymentStatus: '',
                deliveryAddress: o.deliveryAddress,
                placedAt: o.placedAt,
                scheduledFor: slot.start ?? o.approxDeliveryTime ?? o.placedAt,
                deliveredAt: null,
                approximateDeliveryDuration: null,
                approximateDeliveryTime: o.approxDeliveryTime,
                items: [
                  OrderItem(
                    productId: p.productId,
                    productName: p.name,
                    quantity: 1,
                    price: 0.0,
                  ),
                ],
              );
              bucket.orders.add(orderModel);
              group.orders.add(orderModel);
            }
            group.slots.add(bucket);
          }
          list.add(group);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    "Product-wise Subscription Orders",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              list.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange, width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('No Subscription Orders today..',
                          style: TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          _ProductExpandableTile(data: list[i], isDemo: false),
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
                      child: Text(group.productName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    Text('Orders: ${group.orderCount}',
                        style: const TextStyle(color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: group.slots.length,
                    itemBuilder: (_, slotIndex) {
                      final bucket = group.slots[slotIndex];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _slotHeaderModal(bucket.label, bucket.orders.length),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: bucket.orders.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final o = bucket.orders[i];
                              final hasAddon = o.items.any(_isAddon);
                              final qty = o.items
                                  .where((it) =>
                                      !_isAddon(it) &&
                                      it.productName == group.productName)
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF54A079)
                                            .withOpacity(.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: const Color(0xFF54A079)),
                                      ),
                                      child: Text('x$qty',
                                          style: const TextStyle(
                                              color: Color(0xFF54A079),
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    if (hasAddon)
                                      const Icon(Icons.add_circle,
                                          color: Colors.blue, size: 18),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
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

  Widget _slotHeaderModal(String label, int count) => Container(
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
                style: const TextStyle(
                    color: Color(0xFF54A079),
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              ),
            )
          ],
        ),
      );
}

class _ProductGroup {
  final String productName;
  int count;
  int orderCount;
  bool hasAnyAddons;
  final List<_SlotBucket> slots;
  final List<OrderModel> orders;
  _ProductGroup(
      {required this.productName,
      this.count = 0,
      this.orderCount = 0,
      this.hasAnyAddons = false})
      : slots = [],
        orders = [];
}

class _SlotBucket {
  final String label;
  final DateTime? start;
  final List<OrderModel> orders;
  _SlotBucket({required this.label, this.start}) : orders = [];
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

  bool _isAddon(OrderItem item) =>
      item.productName.toLowerCase().contains('addon') ||
      item.productName.toLowerCase().contains('add-on');

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
              Text('${widget.data.orderCount} orders',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              Text('Qty ${widget.data.count}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              if (widget.data.hasAnyAddons)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: const Text('Add-ons',
                      style: TextStyle(
                          color: Colors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              if (widget.isDemo)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text('Demo',
                      style: TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          children: _buildPhaseRootChildren(context),
        ),
      ),
    );
  }

  int _rootTab = 0; // 0 Orders,1 Packed,2 Dispatched,3 Delivered
  static const List<String> _phaseLabels = [
    'Orders',
    'Ready',
    'Delivering',
    'Delivered'
  ];
  final Map<String, String> _demoPhases = {};
  late TabController _phaseController;
  String _labelWithCount(String base, int count) =>
      count > 0 ? '$base ($count)' : base;

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
    final counts = [0, 0, 0, 0];

    String fallbackSlotLabel(DateTime start) {
      final end = start.add(const Duration(minutes: 30));
      String two(int v) => v.toString().padLeft(2, '0');
      return '${two(start.hour)}:${two(start.minute)} - ${two(end.hour)}:${two(end.minute)}';
    }

    Widget buildOrdersList(List<OrderModel> source) {
      if (source.isEmpty) {
        return const SizedBox.shrink();
      }
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: source.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final o = source[i];
          final hasAddon = o.items.any(_isAddon);
          final qty = o.items
              .where((it) =>
                  !_isAddon(it) && it.productName == widget.data.productName)
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF54A079).withOpacity(.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF54A079)),
                  ),
                  child: Text('x$qty',
                      style: const TextStyle(
                          color: Color(0xFF54A079),
                          fontWeight: FontWeight.w600)),
                ),
                if (hasAddon)
                  const Icon(Icons.add_circle, color: Colors.blue, size: 18),
                _actionButtonFor(o.orderId,
                    _phases[o.orderId] ?? _phaseFromStatus(o.status)),
              ],
            ),
          );
        },
      );
    }

    void addSlotSection(String label, List<OrderModel> orders) {
      body.add(_slotHeader(label, orders.length));
      final filtered = <OrderModel>[];
      for (final order in orders) {
        final phase = _phases[order.orderId] ?? _phaseFromStatus(order.status);
        if (phase == labelSelected) {
          filtered.add(order);
        }
      }
      body.add(buildOrdersList(filtered));
    }

    for (final order in widget.data.orders) {
      final phase = _phases[order.orderId] ?? _phaseFromStatus(order.status);
      final idx = _phaseLabels.indexOf(phase);
      if (idx >= 0) counts[idx]++;
    }

    final slots = [...widget.data.slots];
    slots.sort((a, b) {
      final aStart = a.start;
      final bStart = b.start;
      if (aStart != null && bStart != null) return aStart.compareTo(bStart);
      if (aStart != null) return -1;
      if (bStart != null) return 1;
      return a.label.compareTo(b.label);
    });

    if (slots.isEmpty && widget.data.orders.isNotEmpty) {
      final Map<DateTime, List<OrderModel>> fallbackBuckets = {};
      for (final order in widget.data.orders) {
        final ts = order.scheduledFor ?? order.placedAt;
        final minute = ts.minute < 30 ? 0 : 30;
        final start = DateTime(ts.year, ts.month, ts.day, ts.hour, minute);
        fallbackBuckets.putIfAbsent(start, () => []).add(order);
      }
      final keys = fallbackBuckets.keys.toList()..sort();
      for (final key in keys) {
        addSlotSection(fallbackSlotLabel(key), fallbackBuckets[key]!);
      }
    } else {
      for (final slot in slots) {
        final headerLabel = slot.label.trim().isNotEmpty
            ? slot.label
            : (slot.start != null ? fallbackSlotLabel(slot.start!) : 'Slot');
        addSlotSection(headerLabel, slot.orders);
      }
    }

    if (body.isEmpty) {
      body.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No subscription orders in this phase.',
          style: TextStyle(color: Colors.black54),
        ),
      ));
    }

    return [
      _rootPhaseTabs(counts),
      const SizedBox(height: 5),
      const Divider(height: 1),
      const SizedBox(height: 5),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Column(
            key: ValueKey(_rootTab),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: body),
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
                style: const TextStyle(
                    color: Color(0xFF54A079),
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
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
          indicatorPadding: const EdgeInsets.symmetric(
            vertical: 4,
          ),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Text(_labelWithCount('Orders', counts[0])))),
            Tab(
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Text(_labelWithCount('Ready', counts[1])))),
            Tab(
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Text(_labelWithCount('Delivering', counts[2])))),
            Tab(
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Text(_labelWithCount('Delivered', counts[3])))),
          ],
        ),
      );

  Widget _demoRow(String name, String address,
      {required int qty, bool hasAddon = false}) {
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
            child: Text('x$qty',
                style: const TextStyle(
                    color: Color(0xFF54A079), fontWeight: FontWeight.w600)),
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
    if (phase == 'Orders') {
      next = 'Ready';
      label = 'Ready';
    } else if (phase == 'Ready') {
      next = 'Delivering';
      label = 'Delivering';
    } else if (phase == 'Delivering') {
      next = 'Delivered';
      label = 'Deliver';
    }

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
          ok = await updateOrderStatus(
              orderId: orderId, newStatus: next!, authToken: token);
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
      child: Text(label!,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }

  Widget _demoActionButtonFor(String id, String phase) {
    String? next;
    String? label;
    if (phase == 'Orders') {
      next = 'Ready';
      label = 'Ready';
    } else if (phase == 'Ready') {
      next = 'Delivering';
      label = 'Delivering';
    } else if (phase == 'Delivering') {
      next = 'Delivered';
      label = 'Deliver';
    }

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
      child: Text(label!,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
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
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                        softWrap: true,
                      ),
                      Text(
                        'Qty ${data.count}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                        softWrap: true,
                      ),
                      if (data.hasAnyAddons)
                        const Icon(Icons.add_circle,
                            color: Colors.blue, size: 18),
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
