
import 'dart:convert';

class ProductVariant {
  final String variantId;
  final String? productId;
  final String name;
  final String? slug;
  final String? description;
  final double price;
  final bool isActive;
  final DateTime? availableFrom;
  final DateTime? availableUntil;
  final String? image;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProductVariant({
    required this.variantId,
    this.productId,
    required this.name,
    this.slug,
    this.description,
    required this.price,
    this.isActive = true,
    this.availableFrom,
    this.availableUntil,
    this.image,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    double parsePrice(dynamic p) {
      if (p == null) return 0.0;
      if (p is double) return p;
      if (p is int) return p.toDouble();
      return double.tryParse(p.toString()) ?? 0.0;
    }

    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      try {
        return DateTime.parse(d.toString());
      } catch (_) {
        return null;
      }
    }

    return ProductVariant(
      variantId: map['variant_id']?.toString() ?? map['variantId']?.toString() ?? '',
      productId: map['product']?.toString() ?? map['product_id']?.toString(),
      name: map['name']?.toString() ?? '',
      slug: map['slug']?.toString(),
      description: map['description']?.toString(),
      price: parsePrice(map['price'] ?? map['unit_price'] ?? map['price_cents']),
      isActive: map['is_active'] == null ? true : (map['is_active'] == true || map['is_active'].toString().toLowerCase() == 'true'),
      availableFrom: parseDate(map['available_from']),
      availableUntil: parseDate(map['available_until']),
      image: map['image']?.toString(),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'variant_id': variantId,
      'product': productId,
      'name': name,
      'slug': slug,
      'description': description,
      'price': price,
      'is_active': isActive,
      'available_from': availableFrom?.toIso8601String(),
      'available_until': availableUntil?.toIso8601String(),
      'image': image,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory ProductVariant.fromJson(String source) =>
      ProductVariant.fromMap(source.isEmpty ? {} : Map<String, dynamic>.from(jsonDecode(source)));

  String toJson() => jsonEncode(toMap());

  ProductVariant copyWith({
    String? variantId,
    String? productId,
    String? name,
    String? slug,
    String? description,
    double? price,
    bool? isActive,
    DateTime? availableFrom,
    DateTime? availableUntil,
    String? image,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductVariant(
      variantId: variantId ?? this.variantId,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
      availableFrom: availableFrom ?? this.availableFrom,
      availableUntil: availableUntil ?? this.availableUntil,
      image: image ?? this.image,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ProductVariant(variantId: $variantId, productId: $productId, name: $name, price: $price)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ProductVariant && other.variantId == variantId;
  }

  @override
  int get hashCode => variantId.hashCode;
}

class OrderItem {
  final int? orderItemId;
  final String productId;
  final String productName;
  final ProductVariant? variant;
  final String? variantId;
  final String? variantName;
  final int quantity;
  final double price;
  final double? unitPrice;
  final double? lineTotalAfterDiscount;
  final List<Map<String, dynamic>> customizations;

  OrderItem({
    this.orderItemId,
    required this.productId,
    required this.productName,
    this.variant,
    this.variantId,
    this.variantName,
    this.quantity = 1,
    required this.price,
    this.unitPrice,
    this.lineTotalAfterDiscount,
    List<Map<String, dynamic>>? customizations,
  }) : customizations = customizations ?? const <Map<String, dynamic>>[];

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> _parseCustomizations(dynamic raw) {
      if (raw is List) {
        return raw
            .map((entry) {
              if (entry is Map) {
                final instruction = entry['instruction']?.toString().trim() ?? '';
                if (instruction.isEmpty) return null;
                final quantity = entry['quantity'];
                return <String, dynamic>{
                  'quantity': quantity is num
                      ? quantity
                      : int.tryParse(quantity?.toString() ?? '') ?? 0,
                  'instruction': instruction,
                };
              } else if (entry is String) {
                final text = entry.trim();
                if (text.isEmpty) return null;
                return <String, dynamic>{
                  'quantity': 1,
                  'instruction': text,
                };
              }
              return null;
            })
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      return const <Map<String, dynamic>>[];
    }

    ProductVariant? pv;
    if (json['variant'] is Map) {
      pv = ProductVariant.fromMap(Map<String, dynamic>.from(json['variant']));
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return OrderItem(
      orderItemId: parseInt(json['order_item_id'] ?? json['id']),
      productId: (json['product'] ?? json['product_id'])?.toString() ?? '',
      productName: (json['product_name'] ?? json['name'])?.toString() ?? '',
      variant: pv,
      variantId: (json['variant_id'] ?? json['variantId'] ?? pv?.variantId)?.toString(),
      variantName: (json['variant_name'] ?? json['variantName'] ?? pv?.name)?.toString(),
      quantity: parseInt(json['quantity'] ?? json['qty']) ?? 1,
      price: parseDouble(json['price']) ?? 0.0,
      unitPrice: parseDouble(json['unit_price']),
      lineTotalAfterDiscount: parseDouble(json['line_total_after_discount']),
      customizations: _parseCustomizations(json['customizations']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (orderItemId != null) 'order_item_id': orderItemId,
      'product_id': productId,
      'product_name': productName,
      if (variant != null) 'variant': variant!.toMap(),
      if (variantId != null) 'variant_id': variantId,
      if (variantName != null) 'variant_name': variantName,
      'quantity': quantity,
      'price': price,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (lineTotalAfterDiscount != null) 'line_total_after_discount': lineTotalAfterDiscount,
      if (customizations.isNotEmpty) 'customizations': customizations,
    };
  }

  String toJson() => jsonEncode(toMap());

  OrderItem copyWith({
    int? orderItemId,
    String? productId,
    String? productName,
    ProductVariant? variant,
    String? variantId,
    String? variantName,
    int? quantity,
    double? price,
    double? unitPrice,
    double? lineTotalAfterDiscount,
    List<Map<String, dynamic>>? customizations,
  }) {
    return OrderItem(
      orderItemId: orderItemId ?? this.orderItemId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      variant: variant ?? this.variant,
      variantId: variantId ?? this.variantId,
      variantName: variantName ?? this.variantName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      unitPrice: unitPrice ?? this.unitPrice,
      lineTotalAfterDiscount: lineTotalAfterDiscount ?? this.lineTotalAfterDiscount,
      customizations: customizations ?? List<Map<String, dynamic>>.from(this.customizations),
    );
  }

  @override
  String toString() {
    return 'OrderItem(orderItemId: $orderItemId, productId: $productId, productName: $productName, variantId: $variantId, quantity: $quantity, price: $price)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is OrderItem &&
        other.orderItemId == orderItemId &&
        other.productId == productId &&
        other.variantId == variantId &&
        other.quantity == quantity &&
        other.price == price;
  }

  @override
  int get hashCode => Object.hash(orderItemId, productId, variantId, quantity, price);
}

class OrderModel {
  final String orderId;
  final String status;
  final String? orderType; // 'OnDemand' | 'Subscription' | 'Scheduled'
  final String? deliveryType; // e.g. dine_in, delivery
  final String customer_id;
  final String customer;
  final String customerMobile;
  final double grossTotal;
  final double deliveryCharges;
  final double netTotal;
  final double discountAmount;
  final String paymentStatus;
  final String? paymentMethod;
  final String? outletId;
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
    this.deliveryType,
    required this.customer_id,
    required this.customer,
    required this.customerMobile,
    required this.grossTotal,
    required this.deliveryCharges,
    required this.netTotal,
    this.discountAmount = 0.0,
    required this.paymentStatus,
    this.paymentMethod,
    this.outletId,
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
      deliveryType: json['delivery_type']?.toString(),
      customer_id: json['customer_id'] ?? '',
      customer: json['customer_name'] ?? '',
      customerMobile: json['customer_mobile'] ?? '',
      grossTotal: double.tryParse(json['gross_total'].toString()) ?? 0.0,
      deliveryCharges: double.tryParse(json['delivery_charges'].toString()) ?? 0.0,
      netTotal: double.tryParse(json['net_total'].toString()) ?? 0.0,
      discountAmount: double.tryParse(json['discount_amount']?.toString() ?? '') ?? 0.0,
      paymentStatus: json['payment_status'] ?? '',
      paymentMethod: json['payment_method']?.toString(),
      outletId: json['outlet']?.toString(),
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
