import 'package:dio/dio.dart';

import '../core/api_service.dart';
import '../data/models/offer_model.dart';

class OfferService {
  const OfferService._();

  static Future<List<OfferCampaign>> fetchCampaigns({
    bool activeOnly = false,
  }) async {
    try {
      final apiService = ApiService();
      final response = await apiService.get(
        '/api/offers/campaigns/',
        queryParameters: activeOnly ? {'active_only': 'true'} : null,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load campaigns (${response.statusCode})');
      }

      final decoded = response.data;
      final campaignsJson = decoded is Map<String, dynamic>
          ? decoded['campaigns'] as List<dynamic>? ?? const []
          : (decoded as List<dynamic>? ?? const []);
      return campaignsJson
          .map((dynamic c) => OfferCampaign.fromJson(c as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Failed to fetch campaigns: ${e.response?.statusCode} ${e.message}',
        );
      }
      rethrow;
    }
  }

  static Future<OfferCampaign> createCampaign(OfferCampaign campaign) async {
    try {
      final requestBody = campaign.toJson();
      final apiService = ApiService();
      final response = await apiService.post(
        '/api/offers/campaigns/',
        data: requestBody,
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to create campaign (${response.statusCode})');
      }

      return _decodeCampaignResponse(response.data);
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Failed to create campaign: ${e.response?.statusCode} ${e.message}',
        );
      }
      rethrow;
    }
  }

  static Future<OfferCampaign> updateCampaignPartial({
    required String campaignId,
    required Map<String, dynamic> payload,
  }) async {
    if (payload.isEmpty) {
      throw Exception('No fields provided for update');
    }

    try {
      final apiService = ApiService();
      final response = await apiService.patch(
        '/api/offers/campaigns/$campaignId/',
        data: payload,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update campaign (${response.statusCode})');
      }

      return _decodeCampaignResponse(response.data);
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Failed to update campaign: ${e.response?.statusCode} ${e.message}',
        );
      }
      rethrow;
    }
  }

  static Future<void> deleteCampaign(String campaignId) async {
    try {
      final apiService = ApiService();
      final response = await apiService.delete(
        '/api/offers/campaigns/$campaignId/',
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete campaign (${response.statusCode})');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Failed to delete campaign: ${e.response?.statusCode} ${e.message}',
        );
      }
      rethrow;
    }
  }

  static Future<OfferCampaign> setCampaignActivation({
    required String campaignId,
    required bool isActive,
  }) async {
    try {
      final apiService = ApiService();
      final response = await apiService.patch(
        '/api/offers/campaigns/$campaignId/',
        data: {'is_active': isActive},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update activation (${response.statusCode})');
      }

      return _decodeCampaignResponse(response.data);
    } catch (e) {
      if (e is DioException) {
        throw Exception(
          'Failed to update activation: ${e.response?.statusCode} ${e.message}',
        );
      }
      rethrow;
    }
  }

  static OfferCampaign _decodeCampaignResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('campaign')) {
        return OfferCampaign.fromJson(
            data['campaign'] as Map<String, dynamic>);
      }
      if (data.containsKey('campaigns')) {
        final campaigns = data['campaigns'];
        if (campaigns is List && campaigns.isNotEmpty) {
          return OfferCampaign.fromJson(
              campaigns.first as Map<String, dynamic>);
        }
      }
      return OfferCampaign.fromJson(data);
    }
    throw Exception('Unexpected campaign response shape');
  }
}
