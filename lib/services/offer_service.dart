import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../data/models/offer_model.dart';

class OfferService {
  const OfferService._();

  static Future<String> _requireToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      throw Exception('Missing auth token');
    }
    return token;
  }

  static Future<List<OfferCampaign>> fetchCampaigns({
    bool activeOnly = false,
  }) async {
    final token = await _requireToken();
    final uri = activeOnly
        ? Uri.parse('$BASE_URL/api/offers/campaigns/?active_only=true')
        : Uri.parse('$BASE_URL/api/offers/campaigns/');
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load campaigns (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    final campaignsJson = decoded is Map<String, dynamic>
        ? decoded['campaigns'] as List<dynamic>? ?? const []
        : (decoded as List<dynamic>? ?? const []);
    return campaignsJson
        .map((dynamic c) => OfferCampaign.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  static Future<OfferCampaign> createCampaign(OfferCampaign campaign) async {
    final token = await _requireToken();
    final uri = Uri.parse('$BASE_URL/api/offers/campaigns/');
    final requestBody = campaign.toJson();
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to create campaign (${response.statusCode})');
    }

    return _decodeCampaignResponse(response.body);
  }

  static Future<OfferCampaign> updateCampaignPartial({
    required String campaignId,
    required Map<String, dynamic> payload,
  }) async {
    if (payload.isEmpty) {
      throw Exception('No fields provided for update');
    }
    final token = await _requireToken();
    final uri = Uri.parse('$BASE_URL/api/offers/campaigns/$campaignId/');
    final response = await http.patch(
      uri,
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update campaign (${response.statusCode})');
    }

    return _decodeCampaignResponse(response.body);
  }

  static Future<void> deleteCampaign(String campaignId) async {
    final token = await _requireToken();
    final uri = Uri.parse('$BASE_URL/api/offers/campaigns/$campaignId/');
    final response = await http.delete(
      uri,
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete campaign (${response.statusCode})');
    }
  }

  static Future<OfferCampaign> setCampaignActivation({
    required String campaignId,
    required bool isActive,
  }) async {
    final token = await _requireToken();
    final uri = Uri.parse('$BASE_URL/api/offers/campaigns/$campaignId/');
    final response = await http.patch(
      uri,
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'is_active': isActive}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update activation (${response.statusCode})');
    }

    return _decodeCampaignResponse(response.body);
  }

  static OfferCampaign _decodeCampaignResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('campaign')) {
        return OfferCampaign.fromJson(
            decoded['campaign'] as Map<String, dynamic>);
      }
      if (decoded.containsKey('campaigns')) {
        final campaigns = decoded['campaigns'];
        if (campaigns is List && campaigns.isNotEmpty) {
          return OfferCampaign.fromJson(
              campaigns.first as Map<String, dynamic>);
        }
      }
      return OfferCampaign.fromJson(decoded);
    }
    throw Exception('Unexpected campaign response shape');
  }
}
