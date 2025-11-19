import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/offer_model.dart';
import '../../providers/offers_provider.dart';
import 'offer_editor_screen.dart';

class ManageOffersScreen extends ConsumerWidget {
  const ManageOffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offerCampaignsProvider);
    final notifier = ref.read(offerCampaignsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offers & Discounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.loadCampaigns(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<OfferEditorResult>(
            context,
            MaterialPageRoute(
              builder: (_) => const OfferEditorScreen(),
            ),
          );
          if (result != null) {
            await notifier.saveCampaign(result.campaign, patch: result.patch);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Offer'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Builder(
            builder: (context) {
              if (state.isLoading && state.campaigns.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.errorMessage != null && state.campaigns.isEmpty) {
                return _InfoPlaceholder(
                  icon: Icons.error_outline,
                  message: state.errorMessage!,
                  trailing: TextButton(
                    onPressed: () => notifier.loadCampaigns(),
                    child: const Text('Retry'),
                  ),
                );
              }

              if (state.campaigns.isEmpty) {
                return const _InfoPlaceholder(
                  icon: Icons.local_offer_outlined,
                  message: 'No offers yet. Tap “New Offer” to create one.',
                );
              }

              return ListView.separated(
                itemBuilder: (context, index) {
                  final campaign = state.campaigns[index];
                  return _OfferCard(
                    campaign: campaign,
                    onEdit: () async {
                      final edited = await Navigator.push<OfferEditorResult>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OfferEditorScreen(
                            initialCampaign: campaign,
                          ),
                        ),
                      );
                      if (edited != null) {
                        await notifier.saveCampaign(edited.campaign,
                            patch: edited.patch);
                      }
                    },
                    onToggle: () async {
                      await notifier.toggleActivation(
                        campaign.campaignId!,
                        !campaign.isActive,
                      );
                    },
                    onDelete: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete offer?'),
                          content: const Text('This cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && campaign.campaignId != null) {
                        await notifier.deleteCampaign(campaign.campaignId!);
                      }
                    },
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: state.campaigns.length,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.campaign,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final OfferCampaign campaign;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('d MMM, HH:mm');
    final validity = StringBuffer();
    if (campaign.startAt != null) {
      validity.write('From ${formatter.format(campaign.startAt!.toLocal())}');
    }
    if (campaign.endAt != null) {
      if (validity.isNotEmpty) validity.write(' · ');
      validity.write('Until ${formatter.format(campaign.endAt!.toLocal())}');
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        campaign.displayOfferType,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: campaign.isActive
                        ? Colors.green[100]
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    campaign.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: campaign.isActive
                          ? Colors.green[800]
                          : Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (campaign.description != null &&
                campaign.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(campaign.description!),
            ],
            if (validity.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                validity.toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: campaign.campaignId == null ? null : onToggle,
                  icon: Icon(campaign.isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline),
                  label: Text(campaign.isActive ? 'Deactivate' : 'Activate'),
                ),
                TextButton.icon(
                  onPressed: campaign.campaignId == null ? null : onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPlaceholder extends StatelessWidget {
  const _InfoPlaceholder({
    required this.icon,
    required this.message,
    this.trailing,
  });

  final IconData icon;
  final String message;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey[500]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(height: 16),
            trailing!,
          ],
        ],
      ),
    );
  }
}
