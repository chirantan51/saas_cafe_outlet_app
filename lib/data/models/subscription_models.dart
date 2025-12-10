// lib/models/subscription_models.dart
class SubDayIn {
  final String date;         // "YYYY-MM-DD"
  final int qty;             // >= 1
  final String? slotStart;   // ISO8601 "2025-09-03T12:40:00+05:30"

  SubDayIn({required this.date, required this.qty, this.slotStart});

  Map<String, dynamic> toJson() => {
    "date": date,
    "qty": qty,
    if (slotStart != null) "slot_start": slotStart,
  };
}

class QuoteDay {
  final String date;
  final int qty;
  final String slotStart;
  final String slotEnd;
  final String slotLabel;
  final int pricePaise;

  QuoteDay({
    required this.date,
    required this.qty,
    required this.slotStart,
    required this.slotEnd,
    required this.slotLabel,
    required this.pricePaise,
  });

  factory QuoteDay.fromJson(Map<String, dynamic> j) => QuoteDay(
    date: j["date"],
    qty: j["qty"],
    slotStart: j["slot_start"],
    slotEnd: j["slot_end"],
    slotLabel: j["slot_label"] ?? "",
    pricePaise: j["price_paise"],
  );
}

class SubscriptionQuote {
  final String productId;
  final String outletId;
  final int unitPaise;
  final int baseTotalPaise;
  final int daysCount;
  final int totalQty;
  final List<QuoteDay> perDay;
  final List<String> notes;

  SubscriptionQuote({
    required this.productId,
    required this.outletId,
    required this.unitPaise,
    required this.baseTotalPaise,
    required this.daysCount,
    required this.totalQty,
    required this.perDay,
    required this.notes,
  });

  factory SubscriptionQuote.fromJson(Map<String, dynamic> j) => SubscriptionQuote(
    productId: j["product_id"],
    outletId: j["outlet_id"],
    unitPaise: j["base_unit_paise"],
    baseTotalPaise: j["summary"]["base_total_paise"],
    daysCount: j["summary"]["days_count"],
    totalQty: j["summary"]["total_qty"],
    perDay: (j["per_day"] as List).map((e) => QuoteDay.fromJson(e)).toList(),
    notes: (j["notes"] as List?)?.map((e) => e.toString()).toList() ?? const [],
  );
}

/// New subscription quote response from POST /api/subscriptions/quote/
class SubscriptionQuoteResponse {
  final String productId;
  final String outletId;
  final String currency;
  final int baseUnitPaise;
  final QuoteSummary summary;
  final List<QuotePerDay> perDay;
  final List<String> notes;

  const SubscriptionQuoteResponse({
    required this.productId,
    required this.outletId,
    required this.currency,
    required this.baseUnitPaise,
    required this.summary,
    required this.perDay,
    required this.notes,
  });

  factory SubscriptionQuoteResponse.fromJson(Map<String, dynamic> json) {
    return SubscriptionQuoteResponse(
      productId: json['product_id'] as String? ?? '',
      outletId: json['outlet_id'] as String? ?? '',
      currency: json['currency'] as String? ?? 'INR',
      baseUnitPaise: json['base_unit_paise'] as int? ?? 0,
      summary: QuoteSummary.fromJson(
          json['summary'] as Map<String, dynamic>? ?? {}),
      perDay: (json['per_day'] as List<dynamic>?)
              ?.map((e) => QuotePerDay.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      notes: (json['notes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class QuoteSummary {
  final int totalQty;
  final int daysCount;
  final int baseTotalPaise;
  final int grossTotalPaise;
  final int discountPaise;
  final AppliedDiscountTier? appliedDiscountTier;
  final int netTotalPaise;

  const QuoteSummary({
    required this.totalQty,
    required this.daysCount,
    required this.baseTotalPaise,
    required this.grossTotalPaise,
    required this.discountPaise,
    this.appliedDiscountTier,
    required this.netTotalPaise,
  });

  factory QuoteSummary.fromJson(Map<String, dynamic> json) {
    return QuoteSummary(
      totalQty: json['total_qty'] as int? ?? 0,
      daysCount: json['days_count'] as int? ?? 0,
      baseTotalPaise: json['base_total_paise'] as int? ?? 0,
      grossTotalPaise: json['gross_total_paise'] as int? ?? 0,
      discountPaise: json['discount_paise'] as int? ?? 0,
      appliedDiscountTier: json['applied_discount_tier'] != null
          ? AppliedDiscountTier.fromJson(
              json['applied_discount_tier'] as Map<String, dynamic>)
          : null,
      netTotalPaise: json['net_total_paise'] as int? ?? 0,
    );
  }
}

class QuotePerDay {
  final String date;
  final int qty;
  final String slotStart;
  final String slotEnd;
  final String slotLabel;
  final int pricePaise;

  const QuotePerDay({
    required this.date,
    required this.qty,
    required this.slotStart,
    required this.slotEnd,
    required this.slotLabel,
    required this.pricePaise,
  });

  factory QuotePerDay.fromJson(Map<String, dynamic> json) {
    return QuotePerDay(
      date: json['date'] as String? ?? '',
      qty: json['qty'] as int? ?? 0,
      slotStart: json['slot_start'] as String? ?? '',
      slotEnd: json['slot_end'] as String? ?? '',
      slotLabel: json['slot_label'] as String? ?? '',
      pricePaise: json['price_paise'] as int? ?? 0,
    );
  }
}

class AppliedDiscountTier {
  final int minDays;
  final String discountType;
  final String value;
  final String label;

  const AppliedDiscountTier({
    required this.minDays,
    required this.discountType,
    required this.value,
    required this.label,
  });

  factory AppliedDiscountTier.fromJson(Map<String, dynamic> json) {
    return AppliedDiscountTier(
      minDays: json['min_days'] as int? ?? 0,
      discountType: json['discount_type'] as String? ?? '',
      value: json['value'] as String? ?? '0',
      label: json['label'] as String? ?? '',
    );
  }
}

/// Slot option sent from server in `sub_config.available_slots`.
class SlotOption {
  final String slotStart; // ISO8601
  final String slotEnd;   // ISO8601
  final String slotLabel; // Optional display label

  const SlotOption({
    required this.slotStart,
    required this.slotEnd,
    required this.slotLabel,
  });

  factory SlotOption.fromJson(Map<String, dynamic> j) => SlotOption(
        slotStart: (j['slot_start'] ?? '').toString(),
        slotEnd: (j['slot_end'] ?? '').toString(),
        slotLabel: (j['slot_label'] ?? '').toString(),
      );
}

/// Existing subscription as returned by GET /api/subscriptions/
class SubscriptionItem {
  final int id;
  final String status; // e.g. "Active", "Paused", "Completed"
  final String billingType; // e.g. "Prepaid"
  final int minDays;
  final DateTime startDate;
  final DateTime? endDate;
  final int totalPaise;
  final int paidPaise;
  final String productId;
  final String productName;
  final int outletId;
  final String outletName;
  final int addressId;
  final DateTime createdAt;
  final List<SubscriptionDayItem> days;
  final int totalUnits;
  final int unitsDelivered;
  final List<String> itemsIncluded;
  final int unitPricePaise;

  SubscriptionItem({
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
    required this.createdAt,
    required this.days,
    required this.totalUnits,
    required this.unitsDelivered,
    required this.itemsIncluded,
    required this.unitPricePaise,
  });

  static int _i(dynamic v) => (v is int) ? v : int.tryParse('${v ?? ''}') ?? 0;
  static DateTime? _dt(dynamic v) {
    final s = (v ?? '').toString();
    if (s.isEmpty) return null;
    try { return DateTime.parse(s); } catch (_) { return null; }
  }

  factory SubscriptionItem.fromJson(Map<String, dynamic> j) {
    return SubscriptionItem(
      id: _i(j['id']),
      status: (j['status'] ?? '').toString(),
      billingType: (j['billing_type'] ?? '').toString(),
      minDays: _i(j['min_days']),
      startDate: _dt(j['start_date']) ?? DateTime.now(),
      endDate: _dt(j['end_date']),
      totalPaise: _i(j['total_paise']),
      paidPaise: _i(j['paid_paise']),
      productId: (() {
        final raw = j['product_id'] ?? j['product_uuid'] ?? j['product'];
        return raw == null ? '' : raw.toString();
      })(),
      productName: (j['product_name'] ?? '').toString(),
      outletId: _i(j['outlet']),
      outletName: (j['outlet_name'] ?? '').toString(),
      addressId: _i(j['address']),
      createdAt: _dt(j['created_at']) ?? DateTime.now(),
      days: ((j['days'] as List?) ?? const [])
          .whereType<Map>()
          .map((d) => SubscriptionDayItem.fromJson(Map<String, dynamic>.from(d)))
          .toList(),
      totalUnits: _i(j['total_units']),
      unitsDelivered: _i(j['units_delivered']),
      itemsIncluded: ((j['items_included'] as List?) ?? const [])
          .map((e) => e?.toString() ?? '')
          .where((s) => s.trim().isNotEmpty)
          .cast<String>()
          .toList(),
      unitPricePaise: _i(j['unit_price']),
    );
  }
}

class SubscriptionDayItem {
  final int id;
  final DateTime date;
  final int qty;
  final int basePricePaise;
  final int addonsPricePaise;
  final String status; // e.g. "Scheduled"
  final String instructions;
  final List<dynamic> addonsJson; // passthrough
  final dynamic order; // id or null
  final String? orderStatus; // e.g. "delivered", "future"
  final String? slotStart;
  final String? slotEnd;
  final String? slotLabel;

  SubscriptionDayItem({
    required this.id,
    required this.date,
    required this.qty,
    required this.basePricePaise,
    required this.addonsPricePaise,
    required this.status,
    required this.instructions,
    required this.addonsJson,
    required this.order,
    this.orderStatus,
    this.slotStart,
    this.slotEnd,
    this.slotLabel,
  });

  static int _i(dynamic v) => (v is int) ? v : int.tryParse('${v ?? ''}') ?? 0;
  static DateTime _d(dynamic v) {
    try { return DateTime.parse((v ?? '').toString()); } catch (_) { return DateTime.now(); }
  }

  factory SubscriptionDayItem.fromJson(Map<String, dynamic> j) => SubscriptionDayItem(
        id: _i(j['id']),
        date: _d(j['date']),
        qty: _i(j['qty']),
        basePricePaise: _i(j['base_price_paise']),
        addonsPricePaise: _i(j['addons_price_paise']),
        status: (j['status'] ?? '').toString(),
        instructions: (j['instructions'] ?? '').toString(),
        addonsJson: (j['addons_json'] as List?)?.toList() ?? const [],
        order: j['order'],
        orderStatus: (j['order_status'] as String?)?.toLowerCase(),
        slotStart: (j['slot_start'] ?? j['slotStart'])?.toString(),
        slotEnd: (j['slot_end'] ?? j['slotEnd'])?.toString(),
        slotLabel: (j['slot_label'] ?? j['slotLabel'])?.toString(),
      );

  int get totalPaise => basePricePaise + addonsPricePaise;
}
