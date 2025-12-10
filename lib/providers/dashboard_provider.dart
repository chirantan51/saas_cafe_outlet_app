import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_service.dart';

final dashboardProvider = FutureProvider<DashboardMetrics>((ref) async {
  try {
    final api = ApiService();

    final res = await api.get('/api/outlets/dashboard/');

    if (res.statusCode == 200) {
      return DashboardMetrics.fromJson(res.data);
    } else {
      throw Exception("Failed to load dashboard metrics");
    }
  } on ApiException catch (e) {
    throw Exception(e.message);
  }
});

class DashboardMetrics {
  final int totalOrders;
  final double totalRevenue;
  final int pendingOrders;
  final int cancelledOrders;
  final bool supportsOnDemand;
  final bool supportsSubscriptions;
  final bool supportsOffers;
  final bool supportsDelivery;
  final String? outletId;

  DashboardMetrics({
    required this.totalOrders,
    required this.totalRevenue,
    required this.pendingOrders,
    required this.cancelledOrders,
    required this.supportsOnDemand,
    required this.supportsSubscriptions,
    required this.supportsOffers,
    required this.supportsDelivery,
    required this.outletId,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    int readInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    double readDouble(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0;
    }

    bool supportsValue(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is num) return value != 0;
      final lower = value.toString().toLowerCase();
      return lower == 'true';
    }

    bool capabilityFlag(
      Map<String, dynamic> capabilities,
      List<String> keys,
    ) {
      for (final key in keys) {
        if (capabilities.containsKey(key)) {
          return supportsValue(capabilities[key]);
        }
        if (json.containsKey(key)) {
          return supportsValue(json[key]);
        }
      }
      return false;
    }

    String? extractOutletId(Map<String, dynamic> source) {
      String? normalize(dynamic value) {
        if (value == null) return null;
        final str = value.toString();
        return str.isEmpty ? null : str;
      }

      final keys = [
        'outlet_id',
        'outletId',
        'outletID',
        'id',
        'uuid',
      ];
      for (final key in keys) {
        final match = normalize(source[key]);
        if (match != null) return match;
      }

      final outletMap = source['outlet'];
      if (outletMap is Map<String, dynamic>) {
        for (final key in keys) {
          final match = normalize(outletMap[key]);
          if (match != null) return match;
        }
      }

      final outletDetails = source['outlet_details'] ?? source['outletInfo'];
      if (outletDetails is Map<String, dynamic>) {
        for (final key in keys) {
          final match = normalize(outletDetails[key]);
          if (match != null) return match;
        }
      }

      return null;
    }

    final capabilities =
        (json['capabilities'] as Map<String, dynamic>?) ?? const {};

    final supportsOnDemand = capabilityFlag(capabilities, const [
      'ondemand_feature_enabled',
      'orders_enabled',
      'ondemand_enabled',
    ]);

    final supportsSubscriptions = capabilityFlag(capabilities, const [
      'subscriptions_feature_enabled',
      'supports_subscription',
      'subscription_enabled',
      'has_subscription',
      'subscription_feature',
    ]);

    final supportsOffers = capabilityFlag(capabilities, const [
      'offers_feature_enabled',
      'offers_enabled',
      'offers',
    ]);

    final supportsDelivery = capabilityFlag(capabilities, const [
      'delivery_feature_enabled',
      'delivery_enabled',
      'delivery',
    ]);

    final ordersLast12h =
        (json['orders_last12h'] as Map<String, dynamic>?) ?? const {};
    final byStatus =
        (ordersLast12h['by_status'] as Map<String, dynamic>?) ?? const {};

    dynamic selectFirstPresent(List<dynamic> candidates) {
      for (final candidate in candidates) {
        if (candidate != null) {
          return candidate;
        }
      }
      return null;
    }

    final totalOrders = readInt(selectFirstPresent([
      json['total_orders'],
      ordersLast12h['total'],
    ]));

    final pendingOrders = readInt(selectFirstPresent([
      json['pending_orders'],
      byStatus['Pending'],
      byStatus['pending'],
      byStatus['New'],
      byStatus['Accepted'],
    ]));

    final cancelledOrders = readInt(selectFirstPresent([
      json['cancelled_orders'],
      byStatus['Cancelled'],
      byStatus['cancelled'],
    ]));

    final totalRevenue = readDouble(selectFirstPresent([
      json['total_revenue'],
      ordersLast12h['total_revenue'],
    ]));

    return DashboardMetrics(
      totalOrders: totalOrders,
      totalRevenue: totalRevenue,
      pendingOrders: pendingOrders,
      cancelledOrders: cancelledOrders,
      supportsOnDemand: supportsOnDemand,
      supportsSubscriptions: supportsSubscriptions,
      supportsOffers: supportsOffers,
      supportsDelivery: supportsDelivery,
      outletId: extractOutletId(json),
    );
  }
}
