class OfferCampaign {
  final String? campaignId;
  final String? outletId;
  final String name;
  final String offerType;
  final String? description;
  final DateTime? startAt;
  final DateTime? endAt;
  final double? minOrderAmount;
  final double? value;
  final bool? applyPerUnit;
  final String? happyHourStart;
  final String? happyHourEnd;
  final bool isActive;
  final int priority;
  final List<OfferRule> rules;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OfferCampaign({
    required this.campaignId,
    this.outletId,
    required this.name,
    required this.offerType,
    this.description,
    this.startAt,
    this.endAt,
    this.minOrderAmount,
    this.value,
    this.applyPerUnit,
    this.happyHourStart,
    this.happyHourEnd,
    required this.isActive,
    required this.priority,
    required this.rules,
    this.createdAt,
    this.updatedAt,
  });

  factory OfferCampaign.fromJson(Map<String, dynamic> json) {
    return OfferCampaign(
      campaignId: json['campaign_id']?.toString(),
      outletId: json['outlet_id']?.toString(),
      name: json['name']?.toString() ?? '',
      offerType: json['offer_type']?.toString() ?? '',
      description: json['description']?.toString(),
      startAt: _parseDate(json['start_at']),
      endAt: _parseDate(json['end_at']),
      minOrderAmount: _parseDouble(json['min_order_amount']),
      value: _parseDouble(json['value']),
      applyPerUnit: _parseBool(json['apply_per_unit']),
      happyHourStart: json['happy_hour_start']?.toString(),
      happyHourEnd: json['happy_hour_end']?.toString(),
      isActive: _parseBool(json['is_active']) ?? false,
      priority: _parseInt(json['priority']) ?? 0,
      rules: (json['rules'] as List<dynamic>? ?? [])
          .map((r) => OfferRule.fromJson(r as Map<String, dynamic>))
          .toList(),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson({bool includeIdentifiers = false}) {
    return {
      if (includeIdentifiers && campaignId != null) 'campaign_id': campaignId,
      if (outletId != null && outletId!.isNotEmpty) 'outlet_id': outletId,
      'name': name,
      'offer_type': offerType,
      'description': description,
      'start_at': startAt?.toIso8601String(),
      'end_at': endAt?.toIso8601String(),
      'min_order_amount': _formatDecimal(minOrderAmount),
      'value': _formatDecimal(value),
      'apply_per_unit': applyPerUnit,
      'happy_hour_start': happyHourStart,
      'happy_hour_end': happyHourEnd,
      'is_active': isActive,
      'priority': priority,
      'rules': rules
          .map((rule) => rule.toJson(includeIdentifiers: includeIdentifiers))
          .toList(),
    };
  }

  OfferCampaign copyWith({
    String? campaignId,
    String? outletId,
    String? name,
    String? offerType,
    String? description,
    DateTime? startAt,
    DateTime? endAt,
    double? minOrderAmount,
    double? value,
    bool? applyPerUnit,
    String? happyHourStart,
    String? happyHourEnd,
    bool? isActive,
    int? priority,
    List<OfferRule>? rules,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OfferCampaign(
      campaignId: campaignId ?? this.campaignId,
      outletId: outletId ?? this.outletId,
      name: name ?? this.name,
      offerType: offerType ?? this.offerType,
      description: description ?? this.description,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      value: value ?? this.value,
      applyPerUnit: applyPerUnit ?? this.applyPerUnit,
      happyHourStart: happyHourStart ?? this.happyHourStart,
      happyHourEnd: happyHourEnd ?? this.happyHourEnd,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      rules: rules ?? this.rules,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final lower = value.toString().toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static String? _formatDecimal(double? value) {
    if (value == null) return null;
    return value.toStringAsFixed(2);
  }

  String get displayOfferType {
    switch (offerType) {
      case 'ORDER_FLAT':
        return 'Flat order discount';
      case 'ORDER_PERCENTAGE':
        return 'Order % discount';
      case 'ITEM_FLAT':
        return 'Item flat discount';
      case 'HAPPY_HOUR':
        return 'Happy hours';
      case 'BUY_X_GET_Y':
        return 'Buy X get Y';
      default:
        return offerType.replaceAll('_', ' ').toLowerCase();
    }
  }
}

class OfferRule {
  final int? ruleId;
  final String productId;
  final String? productName;
  final int? minQuantity;
  final int? freeQuantity;
  final double? overrideValue;
  final String? overrideType;
  final bool? applyPerUnit;

  const OfferRule({
    required this.ruleId,
    required this.productId,
    this.productName,
    this.minQuantity,
    this.freeQuantity,
    this.overrideValue,
    this.overrideType,
    this.applyPerUnit,
  });

  factory OfferRule.fromJson(Map<String, dynamic> json) {
    return OfferRule(
      ruleId: OfferCampaign._parseInt(json['rule_id']),
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString(),
      minQuantity: OfferCampaign._parseInt(json['min_quantity']),
      freeQuantity: OfferCampaign._parseInt(json['free_quantity']),
      overrideValue: OfferCampaign._parseDouble(json['override_value']),
      overrideType: json['override_type']?.toString(),
      applyPerUnit: OfferCampaign._parseBool(json['apply_per_unit']),
    );
  }

  Map<String, dynamic> toJson({bool includeIdentifiers = false}) {
    return {
      if (includeIdentifiers && ruleId != null) 'rule_id': ruleId,
      'product_id': productId,
      'min_quantity': minQuantity,
      'free_quantity': freeQuantity,
      'override_value': OfferCampaign._formatDecimal(overrideValue),
      'override_type': overrideType,
      'apply_per_unit': applyPerUnit,
    };
  }

  OfferRule copyWith({
    int? ruleId,
    String? productId,
    String? productName,
    int? minQuantity,
    int? freeQuantity,
    double? overrideValue,
    String? overrideType,
    bool? applyPerUnit,
  }) {
    return OfferRule(
      ruleId: ruleId ?? this.ruleId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      minQuantity: minQuantity ?? this.minQuantity,
      freeQuantity: freeQuantity ?? this.freeQuantity,
      overrideValue: overrideValue ?? this.overrideValue,
      overrideType: overrideType ?? this.overrideType,
      applyPerUnit: applyPerUnit ?? this.applyPerUnit,
    );
  }
}
