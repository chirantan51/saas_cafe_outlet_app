import 'package:outlet_app/constants.dart';

String? resolveImageUrl(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty) return null;

  // If already absolute, return as-is
  if (s.startsWith('http://') || s.startsWith('https://')) return s;

  // Ensure BASE_URL has no trailing slash
  final base = BASE_URL.endsWith('/') ? BASE_URL.substring(0, BASE_URL.length - 1) : BASE_URL;

  // Ensure path has a single leading slash
  final path = s.startsWith('/') ? s : '/$s';

  return '$base$path';
}

Map<String, dynamic>? normalizeMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

bool parseBoolish(dynamic raw) {
  if (raw == null) return false;
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final str = raw.toString().toLowerCase();
  return str == 'true' || str == '1' || str == 'yes';
}

int? parseIntLike(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString());
}

double? parseDoubleLike(dynamic raw) {
  if (raw == null) return null;
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString());
}

double computeItemFlatDiscount(Map<String, dynamic>? item, int quantity) {
  if (item == null || quantity <= 0) return 0.0;

  final offer = normalizeMap(item['active_offer']);
  if (offer == null) return 0.0;

  final offerType = offer['offer_type']?.toString().toUpperCase();
  if (offerType != 'ITEM_FLAT') return 0.0;

  final rule = normalizeMap(offer['rule']);
  if (rule == null) return 0.0;

  final minQty = parseIntLike(rule['min_quantity']);
  final overrideValue = parseDoubleLike(rule['override_value']);
  final applyPerUnit = parseBoolish(rule['apply_per_unit']);

  if (minQty == null || minQty <= 1 || overrideValue == null) return 0.0;
  if (quantity < minQty) return 0.0;

  double total;
  if (applyPerUnit) {
    total = overrideValue * quantity;
  } else {
    final sets = quantity ~/ minQty;
    total = overrideValue * (sets <= 0 ? 1 : sets);
  }

  if (total.isNaN || total.isNegative) return 0.0;
  return total;
}

String? buildItemFlatOfferText(Map<String, dynamic>? item) {
  if (item == null) return null;

  final offer = normalizeMap(item['active_offer']);
  if (offer == null) return null;

  final offerType = offer['offer_type']?.toString().toUpperCase();
  if (offerType != 'ITEM_FLAT') return null;

  final rule = normalizeMap(offer['rule']);
  if (rule == null) return null;

  final minQty = parseIntLike(rule['min_quantity']);
  final overrideValue = parseDoubleLike(rule['override_value']);
  final applyPerUnit = parseBoolish(rule['apply_per_unit']);

  if (minQty == null || minQty <= 1 || overrideValue == null) return null;

  double perUnitDiscount;
  if (applyPerUnit) {
    perUnitDiscount = overrideValue;
  } else {
    perUnitDiscount = overrideValue / minQty;
  }

  if (perUnitDiscount <= 0 || perUnitDiscount.isNaN) return null;

  final savingsText = perUnitDiscount % 1 == 0
      ? perUnitDiscount.toInt().toString()
      : perUnitDiscount.toStringAsFixed(2);

  return 'Buy $minQty or more, Save ₹$savingsText on each unit';
}
