class SubscriptionDetail {
  const SubscriptionDetail({
    required this.id,
    required this.status,
    required this.billingType,
    required this.minDays,
    required this.startDate,
    required this.endDate,
    required this.totalPaise,
    required this.paidPaise,
    required this.productId,
    required this.productName,
    required this.outletId,
    required this.outletName,
    required this.addressId,
    required this.days,
    required this.totalUnits,
    required this.unitsDelivered,
    required this.itemsIncluded,
    required this.unitPricePaise,
    required this.createdAt,
  });

  final int id;
  final String status;
  final String? billingType;
  final int? minDays;
  final DateTime? startDate;
  final DateTime? endDate;
  final int totalPaise;
  final int paidPaise;
  final String productId;
  final String? productName;
  final int? outletId;
  final String? outletName;
  final int? addressId;
  final List<SubscriptionDeliveryDay> days;
  final int totalUnits;
  final int unitsDelivered;
  final List<String> itemsIncluded;
  final int unitPricePaise;
  final DateTime? createdAt;

  bool get isPaidInFull => totalPaise > 0 && paidPaise >= totalPaise;
  int get remainingUnits => (totalUnits - unitsDelivered).clamp(0, totalUnits);

  factory SubscriptionDetail.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    List<String> parseStringList(dynamic value) {
      if (value is List) {
        return value
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return const [];
    }

    final daysRaw = json['days'];
    final days = (daysRaw is List)
        ? daysRaw
            .whereType<Map<String, dynamic>>()
            .map(SubscriptionDeliveryDay.fromJson)
            .toList()
        : <SubscriptionDeliveryDay>[];

    return SubscriptionDetail(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      status: json['status']?.toString() ?? 'Unknown',
      billingType: json['billing_type']?.toString(),
      minDays: _toInt(json['min_days']),
      startDate: parseDate(json['start_date']),
      endDate: parseDate(json['end_date']),
      totalPaise: _toInt(json['total_paise']),
      paidPaise: _toInt(json['paid_paise']),
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString(),
      outletId: _toInt(json['outlet']) == 0 ? null : _toInt(json['outlet']),
      outletName: json['outlet_name']?.toString(),
      addressId: _toInt(json['address']) == 0 ? null : _toInt(json['address']),
      days: days,
      totalUnits: _toInt(json['total_units']),
      unitsDelivered: _toInt(json['units_delivered']),
      itemsIncluded: parseStringList(json['items_included']),
      unitPricePaise: _toInt(json['unit_price']),
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

class SubscriptionDeliveryDay {
  const SubscriptionDeliveryDay({
    required this.id,
    required this.date,
    required this.quantity,
    required this.basePricePaise,
    required this.addonsPricePaise,
    required this.status,
    required this.instructions,
    required this.addons,
    required this.orderId,
    required this.orderStatus,
  });

  final int id;
  final DateTime? date;
  final int quantity;
  final int basePricePaise;
  final int addonsPricePaise;
  final String status;
  final String instructions;
  final List<Map<String, dynamic>> addons;
  final int? orderId;
  final String? orderStatus;

  factory SubscriptionDeliveryDay.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return SubscriptionDeliveryDay(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      date: parseDate(json['date']),
      quantity: SubscriptionDetail._toInt(json['qty']),
      basePricePaise: SubscriptionDetail._toInt(json['base_price_paise']),
      addonsPricePaise: SubscriptionDetail._toInt(json['addons_price_paise']),
      status: json['status']?.toString() ?? 'unknown',
      instructions: json['instructions']?.toString() ?? '',
      addons: (json['addons_json'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const [],
      orderId: (json['order'] is int)
          ? json['order'] as int
          : int.tryParse('${json['order']}'),
      orderStatus: json['order_status']?.toString(),
    );
  }
}
