class PlanSubscription {
  const PlanSubscription({
    required this.id,
    required this.status,
    required this.billingType,
    required this.startDate,
    required this.endDate,
    required this.delivery_slot_label,
    required this.totalPaise,
    required this.paidPaise,
    required this.productId,
    required this.productName,
    required this.customer,
    required this.address,
    required this.numberOfDays,
    required this.totalQuantity,
    required this.deliveredQuantity,
    required this.createdAt,
  });

  final int id;
  final String status;
  final String? billingType;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? delivery_slot_label;
  final int totalPaise;
  final int paidPaise;
  final String productId;
  final String? productName;
  final PlanSubscriptionCustomer customer;
  final PlanSubscriptionAddress? address;
  final int? numberOfDays;
  final int? totalQuantity;
  final int? deliveredQuantity;
  final DateTime? createdAt;

  bool get isPaidInFull => paidPaise >= totalPaise && totalPaise > 0;
  int get remainingPaise => (totalPaise - paidPaise).clamp(0, totalPaise);

  factory PlanSubscription.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return PlanSubscription(
      id: json['id'] as int,
      status: json['status']?.toString() ?? 'Unknown',
      billingType: json['billing_type']?.toString(),
      startDate: parseDate(json['start_date']),
      endDate: parseDate(json['end_date']),
      delivery_slot_label: json['delivery_slot_label']?.toString(),
      totalPaise: _toInt(json['total_paise']),
      paidPaise: _toInt(json['paid_paise']),
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString(),
      customer: PlanSubscriptionCustomer.fromJson(
        json['customer'] as Map<String, dynamic>? ?? const {},
      ),
      address: PlanSubscriptionAddress.maybeFromJson(
        json['address'] as Map<String, dynamic>?,
      ),
      numberOfDays: _toInt(json['no_of_days']),
      totalQuantity: _toInt(json['total_qty']),
      deliveredQuantity: _toInt(json['delivered_qty']),
      createdAt: parseDate(json['created_at']),
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }
}

class PlanSubscriptionCustomer {
  const PlanSubscriptionCustomer({
    required this.id,
    required this.customer_id,
    required this.userId,
    required this.name,
    required this.mobile,
  });

  final int? id;
  final String customer_id;
  final String? userId;
  final String? name;
  final String? mobile;

  factory PlanSubscriptionCustomer.fromJson(Map<String, dynamic> json) {
    return PlanSubscriptionCustomer(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}'),
      customer_id: json['customer_id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      name: json['name']?.toString(),
      mobile: json['mobile']?.toString(),
    );
  }
}

class PlanSubscriptionAddress {
  const PlanSubscriptionAddress({
    required this.label,
    required this.addressLine,
    required this.pinCode,
    required this.latitude,
    required this.longitude,
  });

  final String? label;
  final String? addressLine;
  final String? pinCode;
  final double? latitude;
  final double? longitude;

  factory PlanSubscriptionAddress.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return PlanSubscriptionAddress(
      label: json['label']?.toString(),
      addressLine: json['address']?.toString(),
      pinCode: json['pin_code']?.toString(),
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
    );
  }

  static PlanSubscriptionAddress? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return PlanSubscriptionAddress.fromJson(json);
  }
}
