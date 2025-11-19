import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outlet_app/data/models/subscription_detail.dart';
import 'package:outlet_app/services/subscription_service.dart';

final subscriptionDetailProvider =
    FutureProvider.family.autoDispose<SubscriptionDetail, int>(
  (ref, subscriptionId) async {
    return SubscriptionService.fetchSubscriptionDetail(subscriptionId);
  },
);
