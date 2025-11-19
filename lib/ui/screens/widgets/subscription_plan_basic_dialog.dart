import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:outlet_app/data/models/subscription_plan.dart';

class SubscriptionPlanBasicDialog extends StatelessWidget {
  const SubscriptionPlanBasicDialog({super.key, required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    final product = plan.product;
    final currencyFormatter =
        NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return AlertDialog(
      title: Text(product?.name ?? 'Subscription plan'),
      content: SingleChildScrollView(
        child: ListBody(
          children: [
            _line('Status', product?.status ?? 'Unknown'),
            _line(
                'Price',
                product?.price != null && product!.price!.isNotEmpty
                    ? currencyFormatter
                        .format(double.tryParse(product.price!) ?? 0)
                    : 'Not set'),
            _line('Minimum days', plan.minDays?.toString() ?? '—'),
            _line('Veg type', plan.vegType ?? 'Not specified'),
            _line(
                'Jain compatible', plan.jainCompatible == true ? 'Yes' : 'No'),
            _line('Allow Sundays', plan.allowSundays == true ? 'Yes' : 'No'),
            _line('Daily quantity limit',
                plan.dailyQtyLimit?.toString() ?? 'Unlimited'),
            if ((product?.description ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  product!.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}
