import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:outlet_app/providers/auth_provider.dart';
import 'package:outlet_app/providers/recent_orders_provider.dart';
import 'package:outlet_app/services/order_service.dart';
import 'package:outlet_app/ui/widgets/order_stage_stepper.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/order_model.dart';

class OrderDetailDialog extends ConsumerWidget {
  final OrderModel order;

  const OrderDetailDialog({super.key, required this.order});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authToken = ref.watch(authProvider).authToken;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Order Details",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                          "Customer: ${order.customer} (${order.customerMobile})"),
                    ),
                    IconButton(
                      onPressed: () async {
                        final telUrl = Uri.parse("tel:${order.customerMobile}");
                        if (await canLaunchUrl(telUrl)) {
                          await launchUrl(telUrl);
                        }
                      },
                      icon: const Icon(Icons.phone,
                          size: 20, color: Color(0xFF54A079)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text("Delivery Address:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(order.deliveryAddress ?? '-'),
                const SizedBox(height: 10),
                Text("Items:", style: TextStyle(fontWeight: FontWeight.bold)),
                ListView.builder(
                  itemCount: order.items.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final item = order.items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(item.productName)),
                          Text(" x ${item.quantity}     "),
                          Text(" ₹${item.price.toStringAsFixed(0)}  "),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text("Gross Total: ")),
                    Text(" ₹${order.grossTotal.toStringAsFixed(0)}  "),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text("Delivery Charges: ")),
                    Text(" ₹${order.deliveryCharges.toStringAsFixed(0)}  "),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text("Net Total: ", style: TextStyle(fontWeight: FontWeight.bold),)),
                    Text(" ₹${order.netTotal.toStringAsFixed(0)}  ", style: TextStyle(fontWeight: FontWeight.bold),),
                  ],
                ),
                const Divider(height: 20),
                // const SizedBox(height: 10),
                Row(
                  children: [
                    Text("Status: "),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
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
                const SizedBox(height: 10),
                Text(
                    "Placed at: ${DateFormat('dd MMM, hh:mm a').format(order.placedAt)}"),
                const SizedBox(height: 20),
                // OrderStageStepper(
                //   stages: [
                //     "Pending",
                //     "Accepted",
                //     "Preparing",
                //     "Ready",
                //     "Delivering",
                //     "Delivered"
                //   ],
                //   currentStage: order.status,
                //   onStageChange: (newStatus) async {
                //     final success = await updateOrderStatus(
                //       orderId: order.orderId,
                //       newStatus: newStatus,
                //       authToken: authToken ?? '',
                //     );

                //     if (context.mounted) {
                //       Navigator.pop(context);
                //       ScaffoldMessenger.of(context).showSnackBar(
                //         SnackBar(
                //           content: Text(success
                //               ? "Status updated to $newStatus!"
                //               : "Failed to update status."),
                //           backgroundColor: success ? Colors.green : Colors.red,
                //         ),
                //       );
                //       ref.refresh(recentOrdersProvider);
                //     }
                //   },
                // ),

                _buildOrderActionArea(context, ref, authToken),

                // if (order.status.toLowerCase() == 'pending')
                //   Row(
                //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                //     children: [
                //       ElevatedButton.icon(
                //         onPressed: () async {
                //           final success = await updateOrderStatus(
                //             orderId: order.orderId,
                //             newStatus: "Accepted", // or "Rejected"
                //             authToken: authToken ?? '',
                //           );

                //           if (context.mounted) {
                //             Navigator.pop(context);
                //             ScaffoldMessenger.of(context).showSnackBar(
                //               SnackBar(
                //                 content: Text(success
                //                     ? "Order Accepted!"
                //                     : "Failed to update status."),
                //                 backgroundColor:
                //                     success ? Colors.green : Colors.red,
                //               ),
                //             );
                //             ref.refresh(recentOrdersProvider);
                //           }
                //         },
                //         icon: const Icon(Icons.check),
                //         label: const Text("Accept"),
                //         style: ElevatedButton.styleFrom(
                //           backgroundColor: Colors.green,
                //           foregroundColor: Colors.white,
                //           padding: const EdgeInsets.symmetric(
                //               horizontal: 16, vertical: 10),
                //           minimumSize: const Size(110, 40),
                //           textStyle: const TextStyle(fontSize: 14),
                //           shape: RoundedRectangleBorder(
                //             borderRadius: BorderRadius.circular(8),
                //           ),
                //         ),
                //       ),
                //       ElevatedButton.icon(
                //         onPressed: () async {
                //           final success = await updateOrderStatus(
                //             orderId: order.orderId,
                //             newStatus: "Rejected",
                //             authToken: authToken ?? '',
                //           );

                //           if (context.mounted) {
                //             Navigator.pop(context);
                //             ScaffoldMessenger.of(context).showSnackBar(
                //               SnackBar(
                //                 content: Text(success
                //                     ? "Order Accepted!"
                //                     : "Failed to update status."),
                //                 backgroundColor:
                //                     success ? Colors.green : Colors.red,
                //               ),
                //             );
                //             ref.refresh(recentOrdersProvider);
                //           }
                //         },
                //         icon: const Icon(Icons.close),
                //         label: const Text("Reject"),
                //         style: ElevatedButton.styleFrom(
                //           backgroundColor: Colors.red,
                //           foregroundColor: Colors.white,
                //           padding: const EdgeInsets.symmetric(
                //               horizontal: 16, vertical: 10),
                //           minimumSize: const Size(110, 40),
                //           textStyle: const TextStyle(fontSize: 14),
                //           shape: RoundedRectangleBorder(
                //             borderRadius: BorderRadius.circular(8),
                //           ),
                //         ),
                //       ),
                //     ],
                //   )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderActionArea(
      BuildContext context, WidgetRef ref, String? authToken) {
    if (order.status.toLowerCase() == 'pending') {
      // Show Accept / Reject Buttons
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
              onPressed: () async {
                final success = await updateOrderStatus(
                  orderId: order.orderId,
                  newStatus: "Accepted",
                  authToken: authToken ?? '',
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? "Order Accepted!"
                          : "Failed to update status."),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                  ref.refresh(recentOrdersProvider);
                }
              },
              icon: const Icon(Icons.check),
              label: const Text("Accept"),
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
              )),
          ElevatedButton.icon(
            onPressed: () async {
              final success = await updateOrderStatus(
                orderId: order.orderId,
                newStatus: "Rejected",
                authToken: authToken ?? '',
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? "Order Rejected!"
                        : "Failed to update status."),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
                ref.refresh(recentOrdersProvider);
              }
            },
            icon: const Icon(Icons.close),
            label: const Text("Reject"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: const Size(110, 40),
              textStyle: const TextStyle(fontSize: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      );
    }

    // Show Stage Stepper if order is beyond 'Accepted'
    const stageFlow = ["Preparing", "Ready", "Delivering", "Delivered"];
    final currentStage = order.status;

    // Only show if order is at or after 'Accepted'
    // if (stageFlow
    //     .map((e) => e.toLowerCase())
    //     .contains(currentStage.toLowerCase())) {
    return OrderStageStepper(
      stages: stageFlow,
      currentStage: currentStage,
      onStageChange: (newStatus) async {
        final success = await updateOrderStatus(
          orderId: order.orderId,
          newStatus: newStatus,
          authToken: authToken ?? '',
        );

        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success
                  ? "Updated to $newStatus!"
                  : "Failed to update status."),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
          ref.refresh(recentOrdersProvider);
        }
      },
    );
    //}

    //return const SizedBox.shrink();
  }

  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, String? authToken) {
    Future<void> _updateStatus(String newStatus, String successMsg) async {
      final success = await updateOrderStatus(
        orderId: order.orderId,
        newStatus: newStatus,
        authToken: authToken ?? '',
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? successMsg : "Failed to update status."),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        ref.refresh(recentOrdersProvider);
      }
    }

    switch (order.status.toLowerCase()) {
      case 'pending':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () => _updateStatus("Accepted", "Order Accepted!"),
              icon: const Icon(Icons.check),
              label: const Text("Accept"),
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
              onPressed: () => _updateStatus("Rejected", "Order Rejected!"),
              icon: const Icon(Icons.close),
              label: const Text("Reject"),
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
      case 'accepted':
        return Center(
          child: ElevatedButton(
            onPressed: () => _updateStatus("Preparing", "Started Preparing"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: const Size(110, 40),
              textStyle: const TextStyle(fontSize: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Start Preparing"),
          ),
        );
      case 'preparing':
        return Center(
          child: ElevatedButton(
            onPressed: () => _updateStatus("Ready", "Marked as Prepared"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: const Size(110, 40),
              textStyle: const TextStyle(fontSize: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Prepared"),
          ),
        );
      case 'ready':
        return Center(
          child: ElevatedButton(
            onPressed: () => _updateStatus("Delivering", "Started Delivery"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: const Size(110, 40),
              textStyle: const TextStyle(fontSize: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Start Delivery"),
          ),
        );
      case 'delivering':
        return Center(
          child: ElevatedButton(
            onPressed: () => _updateStatus("Delivered", "Delivery Completed"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: const Size(110, 40),
              textStyle: const TextStyle(fontSize: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Finish Delivery"),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
