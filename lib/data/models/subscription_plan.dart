class SubscriptionPlan {
  final int id;
  final String productId;
  final SubscriptionProduct? product;
  final bool isSubscribable;
  final int? minDays;
  final String? vegType;
  final bool? jainCompatible;
  final bool? allowSundays;
  final int? dailyQtyLimit;
  final String? servingArea;
  final int? slotMinutesOverride;
  final int? capacityPerSlotOverride;
  final String? windowStartOverride;
  final String? windowEndOverride;
  final List<SubscriptionDiscountTier> discountTiers;
  final List<String> holidaysList;
  final List<int> servingZones;
  final int? activeSubscriptionsCount;

  const SubscriptionPlan({
    required this.id,
    required this.productId,
    required this.product,
    required this.isSubscribable,
    this.minDays,
    this.vegType,
    this.jainCompatible,
    this.allowSundays,
    this.dailyQtyLimit,
    this.servingArea,
    this.slotMinutesOverride,
    this.capacityPerSlotOverride,
    this.windowStartOverride,
    this.windowEndOverride,
    this.discountTiers = const [],
    this.holidaysList = const [],
    this.servingZones = const [],
    this.activeSubscriptionsCount,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as int,
      productId: json['product_id']?.toString() ?? '',
      product: SubscriptionProduct.maybeFromJson(
        json['product'] as Map<String, dynamic>?,
      ),
      isSubscribable: json['is_subscribable'] ?? false,
      minDays: _asInt(json['min_days']),
      vegType: json['veg_type']?.toString(),
      jainCompatible: json['jain_compatible'] as bool?,
      allowSundays: json['allow_sundays'] as bool?,
      dailyQtyLimit: _asInt(json['daily_qty_limit']),
      servingArea: json['serving_area']?.toString(),
      slotMinutesOverride: _asInt(json['slot_minutes_override']),
      capacityPerSlotOverride: _asInt(json['capacity_per_slot_override']),
      windowStartOverride: json['window_start_override']?.toString(),
      windowEndOverride: json['window_end_override']?.toString(),
      discountTiers: (json['discount_tiers'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(SubscriptionDiscountTier.fromJson)
              .toList() ??
          const [],
      holidaysList: (json['holidays_list'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      servingZones: (json['serving_zones'] as List<dynamic>?)
              ?.map((e) => _asInt(e))
              .whereType<int>()
              .toList() ??
          const [],
      activeSubscriptionsCount: _asInt(json['active_subscriptions_count']),
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString());
  }
}

class SubscriptionProduct {
  final int id;
  final String productId;
  final String name;
  final String? status;
  final String? price;
  final String? description;
  final List<String> itemsIncluded;
  final String? displayImage;

  const SubscriptionProduct({
    required this.id,
    required this.productId,
    required this.name,
    this.status,
    this.price,
    this.description,
    this.itemsIncluded = const [],
    this.displayImage,
  });

  factory SubscriptionProduct.fromJson(Map<String, dynamic> json) {
    return SubscriptionProduct(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id'].toString()) ?? 0,
      productId: json['product_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed product',
      status: json['status']?.toString(),
      price: json['price']?.toString(),
      description: json['description']?.toString(),
      itemsIncluded: (json['items_included'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      displayImage: json['display_image']?.toString(),
    );
  }

  static SubscriptionProduct? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return SubscriptionProduct.fromJson(json);
  }
}

class SubscriptionDiscountTier {
  final int? qty;
  final double? percentOff;
  final double? flatOff;

  const SubscriptionDiscountTier({
    this.qty,
    this.percentOff,
    this.flatOff,
  });

  factory SubscriptionDiscountTier.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    final discountType = json['discount_type']?.toString().toLowerCase();
    final value = parseDouble(json['value']);

    return SubscriptionDiscountTier(
      qty: SubscriptionPlan._asInt(json['qty'] ?? json['min_days']),
      percentOff: discountType == 'percent'
          ? value
          : parseDouble(json['percent_off']),
      flatOff: discountType == 'flat'
          ? value
          : parseDouble(json['flat_off']),
    );
  }
}
