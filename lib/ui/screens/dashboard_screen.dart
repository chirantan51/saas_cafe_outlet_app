import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outlet_app/data/models/order_model.dart';
import 'package:outlet_app/providers/dashboard_refresh_provider.dart';
import 'package:outlet_app/providers/menu_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:outlet_app/providers/recent_orders_provider.dart';
import 'package:outlet_app/ui/widgets/order_detail_dialog.dart';
import 'manage_menu_screen.dart';
import 'package:outlet_app/providers/dashboard_provider.dart';
import 'dart:async';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final ProviderSubscription<bool> _dashboardListener;

  @override
  void initState() {
    super.initState();

    _dashboardListener = ref.listenManual<bool>(
      dashboardRefreshProvider,
      (prev, next) {
        if (next == true) {
          ref.invalidate(dashboardProvider);
          ref.read(dashboardRefreshProvider.notifier).state = false;
        }
      },
    );
  }

  @override
  void dispose() {
    _dashboardListener.close(); // ✅ Proper cleanup
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recentOrders = ref.watch(recentOrdersProvider);

    final dashboard = ref.watch(dashboardProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Light Grey Background
      //extendBodyBehindAppBar: true, // To make the AppBar transparent
      appBar: const CustomAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: dashboard.when(
            data: (metrics) {
              final recentOrders = ref.watch(recentOrdersProvider);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Statistics Cards
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _dashboardCard("Total Orders", "${metrics.totalOrders}",
                          Icons.shopping_cart),
                      _dashboardCard(
                          "Earnings",
                          "₹ ${metrics.totalRevenue.toStringAsFixed(0)}",
                          Icons.currency_rupee_sharp),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _dashboardCard("Active Orders",
                          "${metrics.pendingOrders}", Icons.delivery_dining),
                      _dashboardCard("Cancelled", "${metrics.cancelledOrders}",
                          Icons.cancel),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Recent Orders",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F1B20)),
                  ),
                  const SizedBox(height: 10),
                  recentOrders.when(
                    data: (orders) => Expanded(
                        child: RecentOrdersWidget(
                            orders:
                                orders)), // ✅ FIX: pass only List<OrderModel>
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text("Error: $err")),
                  ),

                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _quickActionButton(Icons.menu_book, "Manage Menu", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManageMenuScreen(),
                          ),
                        ).then((value) {
                          ref.invalidate(menuProvider); // ✅ Refresh Menu List
                        });
                      }),
                      _quickActionButton(
                          Icons.bar_chart, "View Reports", () {}),
                      _quickActionButton(Icons.settings, "Settings", () {}),
                    ],
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text("Failed to load: $err")),
          ),
        ),
      ),
    );
  }

  Widget _dashboardCard(String title, String value, IconData icon) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor, // Primary Color
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 30),
          const SizedBox(height: 5),
          Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ✅ Order Tile Widget
  Widget _orderTile(String orderId, String amount, String status) {
    Color statusColor = status == "Pending"
        ? Colors.orange
        : status == "Completed"
            ? Colors.green
            : Colors.red;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.receipt_long, color: Colors.black54),
        title:
            Text(orderId, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(amount),
        trailing: Text(status,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ✅ Quick Action Buttons
  Widget _quickActionButton(
      IconData icon, String label, Function()? onPressed) {
    return Column(
      children: [
        FloatingActionButton(
          heroTag: label, // Avoid hero animation issues
          onPressed: onPressed,
          backgroundColor: Theme.of(context).primaryColor,
          mini: true,
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 5),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF1F1B20))),
      ],
    );
  }
}

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  _CustomAppBarState createState() => _CustomAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _CustomAppBarState extends State<CustomAppBar> {
  bool _isShopOn = false; // State for the switch

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white, // Transparent background
      elevation: 0.0, // Remove shadow
      leading: IconButton(
        icon: const Icon(
          Icons.menu, // 4 dots icon (using more_vert as a placeholder)
        ),
        onPressed: () {
          // Handle leading icon press
        },
      ),
      title: Text(
        'Outlet',
        style: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).primaryColor,
        ),
      ),
      actions: [
        Switch(
          value: _isShopOn,
          onChanged: (value) {
            setState(() {
              _isShopOn = value; // Update the switch state
            });
            // Handle shop On/Off logic here
          },
          activeColor: Theme.of(context).primaryColor, // Customize switch color
          inactiveThumbColor: Colors.grey, // Customize inactive thumb color
        ),
      ],
    );
  }
}

class RecentOrdersWidget extends StatefulWidget {
  final List<OrderModel> orders;
  const RecentOrdersWidget({required this.orders});

  @override
  State<RecentOrdersWidget> createState() => _RecentOrdersWidgetState();
}

class _RecentOrdersWidgetState extends State<RecentOrdersWidget> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // Refresh every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.orders.length,
      itemBuilder: (context, index) {
        final order = widget.orders[index];
        final Duration elapsed =
            DateTime.now().difference(order.placedAt); // Add this
        final String elapsedTime = '${elapsed.inMinutes}'; // And format it
        return Card(
          child: ListTile(
              leading: order.status == "Pending"
                  ? Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.orange,
                        border: Border.all(color: Colors.orange, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "${elapsed.inMinutes}",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : order.status == "Delivered"
                      ? Icon(Icons.check_circle, color: Colors.green, size: 30)
                      : order.status == "Preparing" ? Icon(Icons.alarm , color: Colors.green, size: 30) 
                      : order.status == "Ready" ? Icon(Icons.done, color: Colors.green, size: 30) 
                      : order.status == "Delivering" ? Icon(Icons.delivery_dining, color: Colors.green, size: 30) 
                      : order.status == "Delivered" ? Icon(Icons.done_rounded, color: Colors.green, size: 30) 
                      : order.status == "Accepted" ? Icon(Icons.done, color: Colors.green, size: 30) 
                      : Icon(Icons.cancel, color: Colors.red, size: 30,),
              title: Text("${order.customer}"),
              subtitle: Column(
                children: [
                  //TODO Need to add order items here along with quantity
                  // Wrap(
                  //   spacing: 6,
                  //   runSpacing: 4,
                  //   children: order.items.map((item) {
                  //     return Container(
                  //       padding: const EdgeInsets.symmetric(
                  //           horizontal: 8, vertical: 4),
                  //       decoration: BoxDecoration(
                  //         color:
                  //             const Color(0xFFEDF7ED), // light green background
                  //         borderRadius: BorderRadius.circular(20),
                  //         border: Border.all(
                  //             color: Theme.of(context).primaryColor, width: 1),
                  //       ),
                  //       child: Text(
                  //         "${item.productName} x${item.quantity}",
                  //         style: const TextStyle(
                  //           fontSize: 12,
                  //           fontWeight: FontWeight.w500,
                  //           color: Color(0xFF1F1B20),
                  //         ),
                  //       ),
                  //     );
                  //   }).toList(),
                  // ),
                  const SizedBox(height: 4),
                  const SizedBox(height: 4),
                  Text(
                    "${order.deliveryAddress}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              trailing: Text("₹ ${order.grossTotal.toStringAsFixed(0)}"),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => OrderDetailDialog(order: order),
                );
              }),
        );
      },
    );
  }

  String _formatElapsedTime(Duration duration) {
    if (duration.inMinutes < 1) return 'Just now';
    if (duration.inMinutes < 60) return '${duration.inMinutes} min ago';
    if (duration.inHours < 24) return '${duration.inHours} hr ago';
    return '${duration.inDays} day${duration.inDays > 1 ? 's' : ''} ago';
  }
}
