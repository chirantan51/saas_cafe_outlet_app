import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/offer_model.dart';
import '../services/offer_service.dart';

const Object _noValue = Object();

class OfferCampaignsState {
  final List<OfferCampaign> campaigns;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  const OfferCampaignsState({
    required this.campaigns,
    required this.isLoading,
    required this.isSaving,
    required this.errorMessage,
  });

  factory OfferCampaignsState.initial() => const OfferCampaignsState(
        campaigns: [],
        isLoading: false,
        isSaving: false,
        errorMessage: null,
      );

  OfferCampaignsState copyWith({
    List<OfferCampaign>? campaigns,
    bool? isLoading,
    bool? isSaving,
    Object? errorMessage = _noValue,
  }) {
    return OfferCampaignsState(
      campaigns: campaigns ?? this.campaigns,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: identical(errorMessage, _noValue)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  OfferCampaign? get activeCampaign {
    for (final campaign in campaigns) {
      if (campaign.isActive) return campaign;
    }
    return null;
  }
}

class OfferCampaignsNotifier extends StateNotifier<OfferCampaignsState> {
  OfferCampaignsNotifier() : super(OfferCampaignsState.initial());

  bool _bootstrapped = false;

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await loadCampaigns();
  }

  Future<void> loadCampaigns({bool activeOnly = false}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final campaigns = await OfferService.fetchCampaigns(
        activeOnly: activeOnly,
      );
      state = state.copyWith(
        campaigns: campaigns,
        isLoading: false,
        errorMessage: null,
      );
    } catch (err) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: err.toString(),
      );
    }
  }

  Future<OfferCampaign?> saveCampaign(OfferCampaign campaign,
      {Map<String, dynamic>? patch}) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      OfferCampaign result;
      if (campaign.campaignId == null) {
        result = await OfferService.createCampaign(campaign);
      } else {
        final updatePayload = patch ?? {};
        if (updatePayload.isEmpty) {
          result = campaign;
        } else {
          result = await OfferService.updateCampaignPartial(
            campaignId: campaign.campaignId!,
            payload: updatePayload,
          );
        }
      }
      await loadCampaigns();
      state = state.copyWith(isSaving: false);
      return result;
    } catch (err) {
      state = state.copyWith(isSaving: false, errorMessage: err.toString());
      rethrow;
    }
  }

  Future<void> deleteCampaign(String campaignId) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await OfferService.deleteCampaign(campaignId);
      await loadCampaigns();
      state = state.copyWith(isSaving: false);
    } catch (err) {
      state = state.copyWith(isSaving: false, errorMessage: err.toString());
      rethrow;
    }
  }

  Future<OfferCampaign?> toggleActivation(
      String campaignId, bool isActive) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final updated = await OfferService.setCampaignActivation(
        campaignId: campaignId,
        isActive: isActive,
      );
      await loadCampaigns();
      state = state.copyWith(isSaving: false);
      return updated;
    } catch (err) {
      state = state.copyWith(isSaving: false, errorMessage: err.toString());
      rethrow;
    }
  }
}

final offerCampaignsProvider =
    StateNotifierProvider<OfferCampaignsNotifier, OfferCampaignsState>((ref) {
  final notifier = OfferCampaignsNotifier();
  notifier.bootstrap();
  return notifier;
});
