/// Sales Report Model
class SalesReport {
  final double totalSales;
  final int totalOrders;
  final double averageOrderValue;
  final String period;
  final String? startDate;
  final String? endDate;
  final List<DailySales>? dailyBreakdown;

  SalesReport({
    required this.totalSales,
    required this.totalOrders,
    required this.averageOrderValue,
    required this.period,
    this.startDate,
    this.endDate,
    this.dailyBreakdown,
  });

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    return SalesReport(
      totalSales: _parseDouble(json['total_sales']),
      totalOrders: _parseInt(json['total_orders']),
      averageOrderValue: _parseDouble(json['average_order_value']),
      period: json['period']?.toString() ?? '',
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      dailyBreakdown: json['daily_breakdown'] != null
          ? (json['daily_breakdown'] as List)
              .map((e) => DailySales.fromJson(e))
              .toList()
          : null,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// Daily Sales Breakdown
class DailySales {
  final String date;
  final double sales;
  final int orders;

  DailySales({
    required this.date,
    required this.sales,
    required this.orders,
  });

  factory DailySales.fromJson(Map<String, dynamic> json) {
    return DailySales(
      date: json['date']?.toString() ?? '',
      sales: _parseDouble(json['sales']),
      orders: _parseInt(json['orders']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// Product Sales Report Model
class ProductSalesReport {
  final String productId;
  final String productName;
  final int quantitySold;
  final double totalRevenue;
  final double averagePrice;

  ProductSalesReport({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.totalRevenue,
    required this.averagePrice,
  });

  factory ProductSalesReport.fromJson(Map<String, dynamic> json) {
    return ProductSalesReport(
      productId: json['product_id']?.toString() ?? json['id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? json['name']?.toString() ?? '',
      quantitySold: _parseInt(json['quantity_sold'] ?? json['quantity']),
      totalRevenue: _parseDouble(json['total_revenue'] ?? json['revenue']),
      averagePrice: _parseDouble(json['average_price'] ?? json['avg_price']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// Customer Sales Report Model
class CustomerSalesReport {
  final String customerId;
  final String customerName;
  final String? phone;
  final String? email;
  final int totalOrders;
  final double totalSpent;
  final double averageOrderValue;

  CustomerSalesReport({
    required this.customerId,
    required this.customerName,
    this.phone,
    this.email,
    required this.totalOrders,
    required this.totalSpent,
    required this.averageOrderValue,
  });

  factory CustomerSalesReport.fromJson(Map<String, dynamic> json) {
    return CustomerSalesReport(
      customerId: json['customer_id']?.toString() ?? json['id']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? json['name']?.toString() ?? 'Unknown',
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      totalOrders: _parseInt(json['total_orders'] ?? json['orders']),
      totalSpent: _parseDouble(json['total_spent'] ?? json['spent']),
      averageOrderValue: _parseDouble(json['average_order_value'] ?? json['avg_order_value']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
