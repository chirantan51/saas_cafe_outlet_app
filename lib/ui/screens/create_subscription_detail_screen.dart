import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:outlet_app/data/models/subscription_plan.dart';
import 'package:outlet_app/utils/common_utils.dart';

class CreateSubscriptionDetailScreen extends StatelessWidget {
  /// Displays the detail view for a single [SubscriptionPlan].
  final SubscriptionPlan plan;

  const CreateSubscriptionDetailScreen({super.key, required this.plan});

  Color get primary => const Color(0xFF54A079);

  @override
  Widget build(BuildContext context) {
    final product = plan.product;
    final name = product?.name ?? 'Subscription Plan';
    final description = (product?.description ?? '').trim();
    final productId =
        plan.productId.isNotEmpty ? plan.productId : product?.productId ?? '';
    final unitPrice = () {
      final raw = product?.price?.trim();
      if (raw == null || raw.isEmpty) return 0.0;
      return double.tryParse(raw.replaceAll(',', '')) ?? 0.0;
    }();

    final menuItems = (product?.itemsIncluded ?? const <String>[])
        .map((e) => e.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final vegType = plan.vegType?.trim();
    final jainCompatible = plan.jainCompatible;
    final minDays = plan.minDays ?? 1;
    final allowSundays = plan.allowSundays;
    final holidaysList = plan.holidaysList
        .map((e) => e.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    String? discountLabel(SubscriptionDiscountTier tier) {
      if (tier.percentOff != null && tier.percentOff! > 0) {
        final value = tier.percentOff!;
        final formatted =
            value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
        return '$formatted% off';
      }
      if (tier.flatOff != null && tier.flatOff! > 0) {
        final value = tier.flatOff!;
        final formatted =
            value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
        return '₹$formatted off/day';
      }
      return null;
    }

    final discountTiers = plan.discountTiers
        .map((tier) {
          final qty = tier.qty;
          final label = discountLabel(tier);
          if (qty == null || label == null) return null;
          return {'min': qty, 'label': label};
        })
        .whereType<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) => (a['min'] as int).compareTo(b['min'] as int));

    final servingArea = (() {
      final raw = plan.servingArea?.trim() ?? '';
      if (raw.isNotEmpty) return raw;
      return 'Check availability at your address';
    })();

    final imageUrl = resolveImageUrl(product?.displayImage) ?? '';

    final chips = <_ChipData>[];
    if (vegType != null && vegType.isNotEmpty) {
      chips.add(
        _ChipData(
          label: vegType,
          icon: vegType.toLowerCase().contains('non') ? Icons.restaurant : Icons.eco,
        ),
      );
    }
    if (jainCompatible != null) {
      chips.add(
        _ChipData(
          label: jainCompatible ? 'Jain Friendly' : 'Non-Jain',
          icon: Icons.spa_outlined,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Subscription", style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        centerTitle: true,
        elevation: 0.5,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
            color: Colors.white,
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  "/create-subscription",
                  arguments: {
                    "plan": plan,
                    "plan_id": plan.id,
                    "product_id": productId,
                    "min_days": minDays,
                  },
                );
              },
              child: Text(
                "Continue",
                style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _HeaderCard(
            name: name,
            description: description,
            imageUrl: imageUrl,
            primary: primary,
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ChipsRow(
              chips: chips,
              primary: primary,
            ),
          ],
          const SizedBox(height: 16),
          _SectionCard(
            title: "What’s included",
            primary: primary,
            child: menuItems.isEmpty
                ? Text("See description for details.", style: GoogleFonts.dmSans(fontSize: 14.5))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: menuItems.map((e) => _MenuItemPill(text: e)).toList(),
                  ),
          ),
          const SizedBox(height: 4),
          _SectionCard(
            title: "Pricing",
            primary: primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unitPrice > 0) ...[
                  Row(
                    children: [
                      const Icon(Icons.currency_rupee, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Basic Price: ₹ ${unitPrice % 1 == 0 ? unitPrice.toStringAsFixed(0) : unitPrice.toStringAsFixed(2)} per unit',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ] else
                  Text(
                    'Pricing information unavailable',
                    style: GoogleFonts.dmSans(color: Colors.black54),
                  ),
                if (discountTiers.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Discounts', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: discountTiers
                            .map((t) => _DiscountPill(minDays: t['min'] as int, label: t['label'] as String))
                            .toList(),
                      ),
                    ],
                  )
                else
                  Text('No discounts available', style: GoogleFonts.dmSans(color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: "Serving Area",
            primary: primary,
            child: Text(
              servingArea,
              style: GoogleFonts.dmSans(fontSize: 14.5, color: Colors.black87, height: 1.3),
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: "Minimum Days to Select",
            primary: primary,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _alphaFactor(primary, 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _alphaFactor(primary, 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 16),
                      const SizedBox(width: 8),
                      Text("$minDays day${minDays > 1 ? 's' : ''}",
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "You’ll be able to pick any $minDays+ dates on the next screen.",
                    style: GoogleFonts.dmSans(fontSize: 13.5, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: "Scheduling Rules",
            primary: primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      () {
                        if (allowSundays == null) return Icons.help_outline;
                        return allowSundays ? Icons.check_circle_outline : Icons.block;
                      }(),
                      size: 16,
                      color: allowSundays == null ? Colors.grey : primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      () {
                        if (allowSundays == null) return 'Sunday availability not specified';
                        return allowSundays ? 'Sundays Working' : 'Sundays Off';
                      }(),
                      style: GoogleFonts.dmSans(),
                    ),
                  ],
                ),
                if (holidaysList.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Holidays:', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: holidaysList.map((h) => _HolidayPill(h)).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String name;
  final String description;
  final String imageUrl;
  final Color primary;

  const _HeaderCard({
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade100,
                  child: const Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: GoogleFonts.dmSans(fontSize: 14.5, color: Colors.black87, height: 1.35),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Color primary;

  const _SectionCard({
    required this.title,
    required this.child,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w800, color: primary)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ChipData {
  final String label;
  final IconData icon;
  _ChipData({required this.label, required this.icon});
}

class _ChipsRow extends StatelessWidget {
  final List<_ChipData> chips;
  final Color primary;

  const _ChipsRow({required this.chips, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _alphaFactor(primary, 0.08),
            border: Border.all(
              color: _alphaFactor(primary, 0.2),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(c.icon, size: 16, color: primary),
              const SizedBox(width: 6),
              Text(c.label, style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: primary)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _IncludedItemText extends StatelessWidget {
  final String raw;
  const _IncludedItemText(this.raw);

  @override
  Widget build(BuildContext context) {
    final text = raw.trim();
    // Support "Label:Value" → render with a bold label for readability
    final parts = text.split(':');
    if (parts.length >= 2) {
      final label = parts.first.trim();
      final value = parts.sublist(1).join(':').trim();
      return RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style.merge(GoogleFonts.dmSans(fontSize: 14.5)),
          children: [
            TextSpan(text: label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(text: ': '),
            TextSpan(text: value),
          ],
        ),
      );
    }
    return Text(
      text,
      style: GoogleFonts.dmSans(fontSize: 14.5),
    );
  }
}

class _MenuItemPill extends StatelessWidget {
  final String text;
  const _MenuItemPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          //const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF54A079)),
          //const SizedBox(width: 6),
          _IncludedItemText(text),
        ],
      ),
    );
  }
}

class _DiscountPill extends StatelessWidget {
  final int minDays;
  final String label;
  const _DiscountPill({required this.minDays, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_offer_outlined, size: 14),
          const SizedBox(width: 6),
          Text('$minDays+ days • $label', style: GoogleFonts.dmSans(fontSize: 12)),
        ],
      ),
    );
  }
}

class _HolidayPill extends StatelessWidget {
  final String text;
  const _HolidayPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFE0B2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_busy, size: 14, color: Color(0xFFFB8C00)),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF8D6E63))),
        ],
      ),
    );
  }
}

Color _alphaFactor(Color color, double factor) {
  final computed = ((color.a * 255.0) * factor).round();
  final safe = computed.clamp(0, 255).toInt();
  return color.withAlpha(safe);
}
