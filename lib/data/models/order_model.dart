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
  final String? orderType; // 'OnDemand' | 'Subscription' | 'Scheduled'
  final String customer;
  final String customerMobile;
  final double grossTotal;
  final double deliveryCharges;
  final double netTotal;
  final String paymentStatus;
  final String? deliveryAddress;
  final DateTime placedAt;
  final DateTime? scheduledFor; // for scheduled orders
  final DateTime? deliveredAt; // completion timestamp
  final int? approximateDeliveryDuration; // minutes target from server
  final DateTime? approximateDeliveryTime; // optional ETA timestamp from server
  final List<OrderItem> items;

  OrderModel({
    required this.orderId,
    required this.status,
    this.orderType,
    required this.customer,
    required this.customerMobile,
    required this.grossTotal,
    required this.deliveryCharges,
    required this.netTotal,
    required this.paymentStatus,
    required this.deliveryAddress,
    required this.placedAt,
    this.scheduledFor,
    this.deliveredAt,
    this.approximateDeliveryDuration,
    this.approximateDeliveryTime,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      orderId: json['order_id'],
      status: json['status'],
      orderType: json['order_type'],
      customer: json['customer_name'] ?? '',
      customerMobile: json['customer_mobile'] ?? '',
      grossTotal: double.tryParse(json['gross_total'].toString()) ?? 0.0,
      deliveryCharges: double.tryParse(json['delivery_charges'].toString()) ?? 0.0,
      netTotal: double.tryParse(json['net_total'].toString()) ?? 0.0,
      paymentStatus: json['payment_status'] ?? '',
      deliveryAddress: json['delivery_address'],
      placedAt: DateTime.parse(json['placed_at']),
      scheduledFor: json['scheduled_for'] != null && (json['scheduled_for'] as String).isNotEmpty
          ? DateTime.tryParse(json['scheduled_for'])
          : null,
      deliveredAt: json['delivered_at'] != null && (json['delivered_at'] as String).isNotEmpty
          ? DateTime.tryParse(json['delivered_at'])
          : null,
      approximateDeliveryDuration: (() {
        final v = json['approximate_delivery_duration'];
        if (v == null) return null;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString());
      }()),
      approximateDeliveryTime: (() {
        final v = json['approximate_delivery_time'];
        if (v == null) return null;
        if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
        return null;
      }()),
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
