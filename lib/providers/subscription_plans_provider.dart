import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outlet_app/data/models/subscription_plan.dart';
import 'package:outlet_app/services/subscription_service.dart';

final subscriptionPlansProvider =
    FutureProvider<List<SubscriptionPlan>>((ref) async {
  return SubscriptionService.fetchPlans();
});
