import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/outlet_service.dart';

final deliveryConfigProvider =
    FutureProvider.family<DeliveryConfig, String>((ref, outletId) async {
  return OutletService.fetchDeliveryConfig(outletId: outletId);
});
