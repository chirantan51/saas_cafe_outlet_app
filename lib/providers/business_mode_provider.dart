import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Defines the business mode for the outlet
enum BusinessMode {
  onDemandOnly,
  subscriptionOnly,
  both,
}

extension BusinessModeCodec on BusinessMode {
  String get asKey {
    switch (this) {
      case BusinessMode.onDemandOnly:
        return 'on_demand_only';
      case BusinessMode.subscriptionOnly:
        return 'subscription_only';
      case BusinessMode.both:
        return 'both';
    }
  }

  static BusinessMode fromKey(String? key) {
    switch (key) {
      case 'on_demand_only':
        return BusinessMode.onDemandOnly;
      case 'subscription_only':
        return BusinessMode.subscriptionOnly;
      case 'both':
      default:
        return BusinessMode.both;
    }
  }
}

class BusinessModeNotifier extends StateNotifier<BusinessMode> {
  static const _prefsKey = 'business_mode';
  BusinessModeNotifier() : super(BusinessMode.both) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_prefsKey);
      state = BusinessModeCodec.fromKey(v);
    } catch (_) {
      // ignore and use default
    }
  }

  Future<void> setMode(BusinessMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.asKey);
    } catch (_) {
      // ignore persistence failure
    }
  }
}

final businessModeProvider =
    StateNotifierProvider<BusinessModeNotifier, BusinessMode>((ref) {
  return BusinessModeNotifier();
});

