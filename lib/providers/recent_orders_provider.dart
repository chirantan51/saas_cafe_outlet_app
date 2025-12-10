import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/order_model.dart';
import '../core/api_service.dart';

final recentOrdersProvider = FutureProvider<List<OrderModel>>((ref) async {
  try {
    final api = ApiService();

    final response = await api.get('/api/orders/dashboard-orders-ondemand/');

    if (response.statusCode == 200) {
      final decoded = response.data;
      final List orders = decoded is Map<String, dynamic>
          ? (decoded['data']?['orders'] as List? ?? const [])
          : (decoded as List? ?? const []);
      return orders.map((json) => OrderModel.fromJson(json)).toList();
    } else {
      final errorData = response.data;
      final errorMessage = errorData is Map<String, dynamic> && errorData.containsKey('detail')
          ? errorData['detail']
          : 'Failed to load recent orders';
      throw Exception(errorMessage);
    }
  } on ApiException catch (e) {
    throw Exception(e.message);
  }
});
