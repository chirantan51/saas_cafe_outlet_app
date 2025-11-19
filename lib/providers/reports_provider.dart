import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/report_models.dart';
import '../services/report_service.dart';

final reportServiceProvider = Provider<ReportService>((ref) => ReportService());

/// Sales Report Provider
final salesReportProvider = FutureProvider.family<SalesReport, SalesReportParams>(
  (ref, params) async {
    final service = ref.read(reportServiceProvider);
    final data = await service.getSalesReport(
      period: params.period,
      startDate: params.startDate,
      endDate: params.endDate,
    );
    return SalesReport.fromJson(data);
  },
);

/// Products Report Provider
final productsReportProvider = FutureProvider.family<List<ProductSalesReport>, ReportParams>(
  (ref, params) async {
    final service = ref.read(reportServiceProvider);
    final data = await service.getProductsReport(
      period: params.period,
      startDate: params.startDate,
      endDate: params.endDate,
    );
    return data.map((e) => ProductSalesReport.fromJson(e)).toList()
      ..sort((a, b) => b.quantitySold.compareTo(a.quantitySold)); // Descending order
  },
);

/// Customer Sales Report Provider
final customerSalesReportProvider = FutureProvider.family<List<CustomerSalesReport>, ReportParams>(
  (ref, params) async {
    final service = ref.read(reportServiceProvider);
    final data = await service.getCustomerSalesReport(
      period: params.period,
      startDate: params.startDate,
      endDate: params.endDate,
    );
    return data.map((e) => CustomerSalesReport.fromJson(e)).toList()
      ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent)); // Descending order
  },
);

/// Report Parameters
class ReportParams {
  final String period; // 'today', 'week', 'month', 'custom'
  final String? startDate;
  final String? endDate;

  ReportParams({
    required this.period,
    this.startDate,
    this.endDate,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReportParams &&
        other.period == period &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(period, startDate, endDate);
}

/// Sales Report Parameters (extends ReportParams for future extensibility)
class SalesReportParams extends ReportParams {
  SalesReportParams({
    required super.period,
    super.startDate,
    super.endDate,
  });
}
