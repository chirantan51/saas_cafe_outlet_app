import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outlet_app/data/models/plan_subscription.dart';
import 'package:outlet_app/services/subscription_service.dart';

final planSubscriptionsProvider = FutureProvider.family
    .autoDispose<List<PlanSubscription>, int>((ref, planId) async {
  return SubscriptionService.fetchPlanSubscriptions(planId);
});
