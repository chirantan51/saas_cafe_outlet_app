class OrderItem {
  final String productName;
  final int quantity;
  final double price;

  OrderItem({
    required this.productName,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productName: json['product_name'] ?? '',
      quantity: json['quantity'],
      price: double.tryParse(json['price'].toString()) ?? 0.0,
    );
  }
}

class OrderModel {
  final String orderId;
  final String status;
  final String customer;
  final String customerMobile;
  final double grossTotal;
  final double deliveryCharges;
  final double netTotal;
  final String paymentStatus;
  final String? deliveryAddress;
  final DateTime placedAt;
  final List<OrderItem> items;

  OrderModel({
    required this.orderId,
    required this.status,
    required this.customer,
    required this.customerMobile,
    required this.grossTotal,
    required this.deliveryCharges,
    required this.netTotal,
    required this.paymentStatus,
    required this.deliveryAddress,
    required this.placedAt,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      orderId: json['order_id'],
      status: json['status'],
      customer: json['customer_name'] ?? '',
      customerMobile: json['customer_mobile'] ?? '',
      grossTotal: double.tryParse(json['gross_total'].toString()) ?? 0.0,
      deliveryCharges: double.tryParse(json['delivery_charges'].toString()) ?? 0.0,
      netTotal: double.tryParse(json['net_total'].toString()) ?? 0.0,
      paymentStatus: json['payment_status'] ?? '',
      deliveryAddress: json['delivery_address'],
      placedAt: DateTime.parse(json['placed_at']),
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromJson(item))
              .toList() ??
          [],
    );
  }

  String timeElapsed() {
    final now = DateTime.now();
    final diff = now.difference(placedAt);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
    if (diff.inHours < 24) return "${diff.inHours} hr ago";
    return "${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago";
  }
}
