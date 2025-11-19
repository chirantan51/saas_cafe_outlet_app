import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/reports_provider.dart';

class ProductsReportScreen extends ConsumerStatefulWidget {
  const ProductsReportScreen({super.key});

  @override
  ConsumerState<ProductsReportScreen> createState() =>
      _ProductsReportScreenState();
}

class _ProductsReportScreenState extends ConsumerState<ProductsReportScreen> {
  String _selectedPeriod = 'today';
  DateTime? _startDate;
  DateTime? _endDate;
  final ScrollController _scrollController = ScrollController();
  bool _showFilters = true;
  final GlobalKey _tableKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Listen to scroll events to hide/show filters
    _scrollController.addListener(() {
      if (_scrollController.offset > 50 && _showFilters) {
        setState(() => _showFilters = false);
      } else if (_scrollController.offset <= 50 && !_showFilters) {
        setState(() => _showFilters = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = ReportParams(
      period: _selectedPeriod,
      startDate: _startDate?.toIso8601String().split('T')[0],
      endDate: _endDate?.toIso8601String().split('T')[0],
    );

    final reportAsync = ref.watch(productsReportProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products & Sold Qty'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF54A079), Color(0xFF3B7C5F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _captureAndShare,
            tooltip: 'Share Report',
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF6F7FB),
      body: Column(
        children: [
          // Filter Section with AnimatedContainer
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _showFilters ? null : 0,
            curve: Curves.easeInOut,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Period',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E3A2F),
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        _PeriodChip(
                          label: 'Today',
                          value: 'today',
                          isSelected: _selectedPeriod == 'today',
                          onSelected: () => setState(() {
                            _selectedPeriod = 'today';
                            _startDate = null;
                            _endDate = null;
                          }),
                        ),
                        _PeriodChip(
                          label: 'This Week',
                          value: 'week',
                          isSelected: _selectedPeriod == 'week',
                          onSelected: () => setState(() {
                            _selectedPeriod = 'week';
                            _startDate = null;
                            _endDate = null;
                          }),
                        ),
                        _PeriodChip(
                          label: 'This Month',
                          value: 'month',
                          isSelected: _selectedPeriod == 'month',
                          onSelected: () => setState(() {
                            _selectedPeriod = 'month';
                            _startDate = null;
                            _endDate = null;
                          }),
                        ),
                        _PeriodChip(
                          label: 'Custom',
                          value: 'custom',
                          isSelected: _selectedPeriod == 'custom',
                          onSelected: () => _showCustomDatePicker(),
                        ),
                      ],
                    ),
                    if (_selectedPeriod == 'custom' &&
                        _startDate != null &&
                        _endDate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${DateFormat('MMM d, yyyy').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF54A079),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),

          // Report Content - Table View
          Expanded(
            child: reportAsync.when(
              data: (products) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(productsReportProvider(params));
                },
                child: products.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 64, color: Colors.black26),
                            SizedBox(height: 16),
                            Text(
                              'No product sales data',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: RepaintBoundary(
                              key: _tableKey,
                              child: _ProductsTable(products: products),
                            ),
                          ),
                        ),
                      ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading report',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.invalidate(productsReportProvider(params));
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF54A079),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = 'custom';
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _captureAndShare() async {
    try {
      // Check if the table key has a valid context
      if (_tableKey.currentContext == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait for the report to load'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show loading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Generating report image...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      // Capture the screenshot
      RenderRepaintBoundary boundary =
          _tableKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Save to temporary directory
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/products_report_$timestamp.png');
      await file.writeAsBytes(pngBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Products & Quantity Sold Report - ${_selectedPeriod == "custom" && _startDate != null && _endDate != null ? "${DateFormat('MMM d, yyyy').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}" : _selectedPeriod}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing report: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isSelected;
  final VoidCallback onSelected;

  const _PeriodChip({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: const Color(0xFF54A079),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

class _ProductsTable extends StatelessWidget {
  final List products;

  const _ProductsTable({required this.products});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable(
          headingRowHeight: 56,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 56,
          columnSpacing: 24,
          horizontalMargin: 16,
          headingRowColor: WidgetStateProperty.all(
            const Color(0xFF54A079),
          ),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(16),
          ),
          columns: const [
            DataColumn(
              label: Text(
                'Product Name',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Quantity Sold',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              numeric: true,
            ),
            DataColumn(
              label: Text(
                'Revenue (₹)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              numeric: true,
            ),
          ],
          rows: products.asMap().entries.map((entry) {
            final index = entry.key;
            final product = entry.value;
            final isEven = index % 2 == 0;

            return DataRow(
              color: WidgetStateProperty.all(
                isEven ? Colors.grey.shade50 : Colors.white,
              ),
              cells: [
                DataCell(
                  Text(
                    product.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3A2F),
                      fontSize: 14,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF54A079),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${product.quantitySold}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    '₹${product.totalRevenue.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF54A079),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
