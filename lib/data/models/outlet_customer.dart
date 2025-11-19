class OutletCustomer {
  const OutletCustomer({
    required this.id,
    required this.customerId,
    required this.name,
    required this.mobile,
    required this.email,
    required this.subscriptionStatus,
    required this.isSuspended,
    required this.suspensionNote,
    required this.createdSource,
    required this.mobileVerified,
    required this.emailVerified,
    this.address,
    this.addresses = const [],
    this.joinedOn,
    this.numberOfOrders,
    this.totalBusiness,
    this.daysSinceLastOrder,
  });

  final int id;
  final String customerId;
  final String name;
  final String? mobile;
  final String? email;
  final String subscriptionStatus;
  final bool isSuspended;
  final String? suspensionNote;
  final String? createdSource;
  final bool mobileVerified;
  final bool emailVerified;
  final OutletCustomerAddress? address;
  final List<OutletCustomerAddress> addresses;
  final DateTime? joinedOn;
  final int? numberOfOrders;
  final double? totalBusiness;
  final int? daysSinceLastOrder;

  factory OutletCustomer.fromJson(Map<String, dynamic> json) {
    return OutletCustomer(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      customerId: json['customer_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed customer',
      mobile: _stringOrNull(json['mobile']),
      email: _stringOrNull(json['email']),
      subscriptionStatus:
          json['subscription_status']?.toString() ?? 'Unknown',
      isSuspended: json['is_suspended'] == true,
      suspensionNote: _stringOrNull(json['suspension_note']),
      createdSource: _stringOrNull(json['created_source']),
      mobileVerified: json['mobile_verified'] == true,
      emailVerified: json['email_verified'] == true,
      address: OutletCustomerAddress.maybeFromJson(json['address']),
      addresses: OutletCustomerAddress.listFromJson(json['addresses']),
      joinedOn: _parseDate(json['joined_on']),
      numberOfOrders: _asInt(json['number_of_orders']),
      totalBusiness: _toDouble(json['total_business']),
      daysSinceLastOrder: _asInt(json['days_since_last_order']),
    );
  }

  OutletCustomer copyWith({
    bool? isSuspended,
    String? suspensionNote,
    bool? mobileVerified,
    bool? emailVerified,
    String? subscriptionStatus,
    OutletCustomerAddress? address,
    List<OutletCustomerAddress>? addresses,
    DateTime? joinedOn,
    int? numberOfOrders,
    double? totalBusiness,
    int? daysSinceLastOrder,
  }) {
    return OutletCustomer(
      id: id,
      customerId: customerId,
      name: name,
      mobile: mobile,
      email: email,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      isSuspended: isSuspended ?? this.isSuspended,
      suspensionNote: suspensionNote ?? this.suspensionNote,
      createdSource: createdSource,
      mobileVerified: mobileVerified ?? this.mobileVerified,
      emailVerified: emailVerified ?? this.emailVerified,
      address: address ?? this.address,
      addresses: addresses ?? this.addresses,
      joinedOn: joinedOn ?? this.joinedOn,
      numberOfOrders: numberOfOrders ?? this.numberOfOrders,
      totalBusiness: totalBusiness ?? this.totalBusiness,
      daysSinceLastOrder: daysSinceLastOrder ?? this.daysSinceLastOrder,
    );
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return null;
    return str;
  }

  static DateTime? _parseDate(dynamic value) {
    final str = _stringOrNull(value);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class OutletCustomerPage {
  const OutletCustomerPage({
    required this.results,
    required this.count,
    required this.next,
    required this.previous,
  });

  final List<OutletCustomer> results;
  final int count;
  final String? next;
  final String? previous;

  bool get hasNext => next != null && next!.isNotEmpty;
  bool get hasPrevious => previous != null && previous!.isNotEmpty;

  int? get nextPage => _extractPage(next);
  int? get previousPage => _extractPage(previous);

  factory OutletCustomerPage.fromJson(Map<String, dynamic> json) {
    final resultsRaw = json['results'];
    final results = (resultsRaw is List
            ? resultsRaw.whereType<Map<String, dynamic>>()
            : const Iterable<Map<String, dynamic>>.empty())
        .map(OutletCustomer.fromJson)
        .toList();
    return OutletCustomerPage(
      results: results,
      count: json['count'] is int
          ? json['count'] as int
          : int.tryParse(json['count']?.toString() ?? '') ?? results.length,
      next: json['next']?.toString(),
      previous: json['previous']?.toString(),
    );
  }

  static int? _extractPage(String? url) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    for (final entry in uri.queryParameters.entries) {
      if (entry.key.toLowerCase() == 'page') {
        return int.tryParse(entry.value);
      }
    }
    return null;
  }
}

class OutletCustomerAddress {
  const OutletCustomerAddress({
    this.id,
    required this.label,
    required this.address,
    required this.pinCode,
    required this.latitude,
    required this.longitude,
    required this.isPrimary,
  });

  final String? id;
  final String? label;
  final String? address;
  final String? pinCode;
  final double? latitude;
  final double? longitude;
  final bool isPrimary;

  factory OutletCustomerAddress.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return OutletCustomerAddress(
      id: OutletCustomer._stringOrNull(json['id'] ?? json['address_id']),
      label: OutletCustomer._stringOrNull(json['label']),
      address: OutletCustomer._stringOrNull(json['address']),
      pinCode: OutletCustomer._stringOrNull(json['pin_code']),
      latitude: asDouble(json['latitude']),
      longitude: asDouble(json['longitude']),
      isPrimary: json['is_primary'] == true,
    );
  }


  static List<OutletCustomerAddress> listFromJson(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map<String, dynamic>>()
          .map(OutletCustomerAddress.fromJson)
          .toList();
    }
    return const [];
  }
  static OutletCustomerAddress? maybeFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return OutletCustomerAddress.fromJson(value);
    }
    return null;
  }
}
