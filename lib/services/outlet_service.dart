import 'package:dio/dio.dart';

import '../core/api_service.dart';

class DeliveryConfig {
  final double deliveryRadiusKm;
  final DeliveryGeoPoint? outletLocation;
  final List<DeliveryDistanceCharge> distanceCharges;
  final List<DeliveryGeoFence> geoFences;

  const DeliveryConfig({
    required this.deliveryRadiusKm,
    this.outletLocation,
    required this.distanceCharges,
    this.geoFences = const [],
  });

  DeliveryConfig copyWith(
      {double? deliveryRadiusKm,
      DeliveryGeoPoint? outletLocation,
      List<DeliveryDistanceCharge>? distanceCharges,
      List<DeliveryGeoFence>? geoFences}) {
    return DeliveryConfig(
      deliveryRadiusKm: deliveryRadiusKm ?? this.deliveryRadiusKm,
      outletLocation: outletLocation ?? this.outletLocation,
      distanceCharges: distanceCharges ?? this.distanceCharges,
      geoFences: geoFences ?? this.geoFences,
    );
  }

  factory DeliveryConfig.fromJson(Map<String, dynamic> json) {
    final radiusRaw = json['delivery_radius_km'] ??
        json['radius_km'] ??
        json['delivery_radius'] ??
        0;
    final radius = DeliveryGeoPoint._toDouble(radiusRaw);
    final locationMap = json['outlet_location'] ?? json['location'];

    DeliveryGeoPoint? location = DeliveryGeoPoint.maybeFromJson(locationMap);
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    if (latitude != null && longitude != null) {
      location = DeliveryGeoPoint(
        lat: DeliveryGeoPoint._toDouble(latitude),
        lng: DeliveryGeoPoint._toDouble(longitude),
      );
    }

    final chargesRaw =
        json['delivery_distance_charges'] ?? json['distance_charges'] ?? [];
    final geoFencesRaw = json['delivery_geofence'] ??
        json['delivery_geo_fences'] ??
        json['geo_fences'] ??
        json['allowed_geo_fences'] ??
        [];
    return DeliveryConfig(
      deliveryRadiusKm: radius,
      outletLocation: location,
      distanceCharges: (chargesRaw as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DeliveryDistanceCharge.fromJson)
          .toList(),
      geoFences: DeliveryGeoFence.listFromJson(geoFencesRaw),
    );
  }

  Map<String, dynamic> toJson() => {
        'delivery_radius_km': deliveryRadiusKm,
        'outlet_location': outletLocation?.toJson(),
        'delivery_distance_charges':
            distanceCharges.map((tier) => tier.toJson()).toList(),
        'delivery_geofence':
            geoFences.map((fence) => fence.toJson()).toList(),
      };
}

class DeliveryGeoPoint {
  final double lat;
  final double lng;

  const DeliveryGeoPoint({required this.lat, required this.lng});

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  factory DeliveryGeoPoint.fromJson(Map<String, dynamic> json) {
    return DeliveryGeoPoint(
      lat: _toDouble(json['lat'] ?? json['latitude']),
      lng: _toDouble(json['lng'] ?? json['longitude']),
    );
  }

  static DeliveryGeoPoint? maybeFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return DeliveryGeoPoint.fromJson(value);
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
      };
}

class DeliveryDistanceCharge {
  final double upToKm;
  final double chargeAmount;

  const DeliveryDistanceCharge(
      {required this.upToKm, required this.chargeAmount});

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  factory DeliveryDistanceCharge.fromJson(Map<String, dynamic> json) {
    return DeliveryDistanceCharge(
      upToKm: _toDouble(
        json['max_distance_km'] ??
            json['up_to_km'] ??
            json['distance_km'] ??
            json['radius_km'],
      ),
      chargeAmount: _toDouble(
        json['fee'] ?? json['charge_amount'] ?? json['charge'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'max_distance_km': upToKm,
        'fee': chargeAmount,
      };
}

class DeliveryGeoFence {
  final String? id;
  final List<DeliveryGeoPoint> points;

  const DeliveryGeoFence({this.id, required this.points});

  factory DeliveryGeoFence.fromJson(Map<String, dynamic> json) {
    final points = _pointsFromDynamic(
      json['points'] ?? json['polygon'] ?? json['vertices'],
    );
    return DeliveryGeoFence(
      id: json['id']?.toString(),
      points: points,
    );
  }

  static List<DeliveryGeoPoint> _pointsFromDynamic(dynamic rawPoints) {
    final points = <DeliveryGeoPoint>[];
    if (rawPoints is List) {
      for (final entry in rawPoints) {
        if (entry is Map<String, dynamic>) {
          points.add(DeliveryGeoPoint.fromJson(entry));
        } else if (entry is List && entry.length >= 2) {
          points.add(
            DeliveryGeoPoint(
              lat: DeliveryGeoPoint._toDouble(entry[0]),
              lng: DeliveryGeoPoint._toDouble(entry[1]),
            ),
          );
        }
      }
    }
    return points;
  }

  static DeliveryGeoFence? maybeFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return DeliveryGeoFence.fromJson(value);
    }
    if (value is List) {
      final points = _pointsFromDynamic(value);
      if (points.isNotEmpty) {
        return DeliveryGeoFence(points: points);
      }
    }
    return null;
  }

  static List<DeliveryGeoFence> listFromJson(dynamic raw) {
    final fences = <DeliveryGeoFence>[];
    if (raw is List) {
      for (final entry in raw) {
        final fence = maybeFromJson(entry);
        if (fence != null) fences.add(fence);
      }
    } else {
      final fence = maybeFromJson(raw);
      if (fence != null) fences.add(fence);
    }
    return fences;
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'points': points.map((point) => point.toJson()).toList(),
    };
  }
}

class OutletService {
  static Future<DeliveryConfig> fetchDeliveryConfig(
      {required String outletId}) async {
    try {
      final apiService = ApiService();
      final response = await apiService.get(
        "/api/outlets/$outletId/",
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load delivery configuration');
      }

      final decoded = response.data as Map<String, dynamic>;
      return DeliveryConfig.fromJson(decoded);
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Failed to fetch delivery config: ${e.response?.statusCode} ${e.message}',
        );
      }
      rethrow;
    }
  }

  static Future<void> updateDeliveryConfig({
    required String outletId,
    required DeliveryConfig config,
  }) async {
    try {
      final apiService = ApiService();
      final response = await apiService.patch(
        "/api/outlets/$outletId/",
        data: config.toJson(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update delivery configuration');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Failed to update delivery config: ${e.response?.statusCode} ${e.message}',
        );
      }
      rethrow;
    }
  }
}
