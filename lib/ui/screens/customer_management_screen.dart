import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:outlet_app/data/models/outlet_customer.dart';
import 'package:outlet_app/providers/customer_provider.dart';
import 'package:outlet_app/ui/screens/customer_create_screen.dart';
import 'package:outlet_app/utils/navigation_helpers.dart';

const _customerAccentColor = Color(0xFF54A079);

class CustomerManagementScreen extends ConsumerStatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  ConsumerState<CustomerManagementScreen> createState() =>
      _CustomerManagementScreenState();
}

class _CustomerManagementScreenState
    extends ConsumerState<CustomerManagementScreen> {
  final _scrollController = ScrollController();
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      final next = _searchController.text.trim();
      if (next != _searchQuery) {
        setState(() => _searchQuery = next);
      }
    });
    Future.microtask(
      () => ref.read(customerListProvider.notifier).loadInitial(),
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final notifier = ref.read(customerListProvider.notifier);
    final position = _scrollController.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    final threshold = position.maxScrollExtent - 240;
    if (position.pixels >= threshold) {
      notifier.loadMore();
    }
  }

  Future<void> _refresh() async {
    await ref.read(customerListProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerListProvider);
    final theme = Theme.of(context);

    final isLoading = state.isLoading && state.customers.isEmpty;
    final hasError = state.errorMessage != null && state.customers.isEmpty;
    final query = _searchQuery.toLowerCase();
    final filteredCustomers = query.isEmpty
        ? state.customers
        : state.customers.where((customer) {
            final name = customer.name.toLowerCase();
            final mobile = customer.mobile?.toLowerCase() ?? '';
            final email = customer.email?.toLowerCase() ?? '';
            final addressText = (() {
              final address = customer.address;
              if (address == null) return '';
              final parts = <String?>[
                address.label,
                address.address,
                address.pinCode,
              ];
              return parts
                  .where((part) => part != null && part!.trim().isNotEmpty)
                  .map((part) => part!.toLowerCase())
                  .join(' ');
            })();
            return name.contains(query) ||
                mobile.contains(query) ||
                email.contains(query) ||
                addressText.contains(query);
          }).toList();
    final hasBaseCustomers = state.customers.isNotEmpty;
    final hasFilteredCustomers = filteredCustomers.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer management'),
        actions: [
          IconButton(
            onPressed: () => ref.read(customerListProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateCustomerPage(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('New customer'),
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (hasError) {
              return _ErrorState(
                message: state.errorMessage ?? 'Unable to load customers',
                onRetry: () =>
                    ref.read(customerListProvider.notifier).loadInitial(
                          force: true,
                        ),
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SearchBarHeaderDelegate(
                      controller: _searchController,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    sliver: state.customers.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 80),
                              child: Center(
                                child: Text(
                                  'No customers yet.\nCreate one to get started.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : (!hasFilteredCustomers
                            ? SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 80),
                                  child: Center(
                                    child: Text(
                                      'No customers match \"$_searchQuery\".',
                                      textAlign: TextAlign.center,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : SliverList.separated(
                                itemCount: filteredCustomers.length,
                                itemBuilder: (context, index) =>
                                    _CustomerExpandableTile(
                                  customer: filteredCustomers[index],
                                ),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                              )),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (state.errorMessage != null &&
                              state.customers.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                state.errorMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                          if (state.isLoadingMore)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else if (_searchQuery.isNotEmpty)
                            Center(
                              child: Text(
                                hasFilteredCustomers
                                    ? 'Found ${filteredCustomers.length} matching customer${filteredCustomers.length == 1 ? '' : 's'}.'
                                    : 'No matching customers',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.black54,
                                ),
                              ),
                            )
                          else if (!state.hasMore && hasBaseCustomers)
                            Center(
                              child: Text(
                                'Showing ${state.customers.length} of ${state.totalCount} customers',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openCreateCustomerPage(BuildContext context) async {
    final created = await openCustomerCreateScreen(context);

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer created')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }
}

class _SearchBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SearchBarHeaderDelegate({required this.controller});

  final TextEditingController controller;

  @override
  double get minExtent => 74;

  @override
  double get maxExtent => 74;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search customers by name, mobile, email, or address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}

class _CustomerExpandableTile extends ConsumerWidget {
  const _CustomerExpandableTile({required this.customer});

  final OutletCustomer customer;

  Color _statusColor(BuildContext context) {
    if (customer.isSuspended) {
      return Colors.redAccent;
    }
    switch (customer.subscriptionStatus.toLowerCase()) {
      case 'active':
        return const Color(0xFF54A079);
      case 'pending':
        return Colors.orangeAccent;
      default:
        return Colors.black45;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(context);
    final rawStatus = customer.subscriptionStatus.trim();
    final showSubscriptionStatus = !customer.isSuspended &&
        rawStatus.isNotEmpty &&
        rawStatus.toLowerCase() != 'inactive';
    final primaryStatusLabel = customer.isSuspended
        ? 'Suspended'
        : (showSubscriptionStatus ? rawStatus : '');

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey(customer.customerId),
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          expandedAlignment: Alignment.centerLeft,
          title: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: statusColor.withOpacity(0.16),
                child: Text(
                  customer.name.isNotEmpty
                      ? customer.name[0].toUpperCase()
                      : '#',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  customer.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          subtitle: null,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: _CustomerActions(customer: customer),
            ),
            const SizedBox(height: 8),
            _CustomerDetailBody(
              customer: customer,
              showSubscriptionStatus: showSubscriptionStatus,
              statusColor: statusColor,
              primaryStatusLabel: primaryStatusLabel,
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerDetailBody extends StatelessWidget {
  const _CustomerDetailBody({
    required this.customer,
    required this.showSubscriptionStatus,
    required this.statusColor,
    required this.primaryStatusLabel,
  });

  final OutletCustomer customer;
  final bool showSubscriptionStatus;
  final Color statusColor;
  final String primaryStatusLabel;

  String _formatCurrency(double value) {
    if (value >= 10000000) {
      return '${(value / 10000000).toStringAsFixed(2)}Cr';
    }
    if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(2)}L';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)}K';
    }
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _ContactChip(
              value: customer.mobile ?? 'No mobile',
              verified: customer.mobileVerified,
              icon: Icons.phone_iphone,
              verifiedIcon: Icons.verified,
            ),
            if (customer.email != null)
              _ContactChip(
                value: customer.email!,
                verified: customer.emailVerified,
                icon: Icons.email_outlined,
                verifiedIcon: Icons.verified,
              ),
          ],
        ),
        if (customer.createdSource != null ||
            customer.joinedOn != null ||
            customer.daysSinceLastOrder != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (customer.createdSource != null)
                _InfoChip(
                  icon: Icons.person_pin_circle_outlined,
                  label: 'Via ${customer.createdSource}',
                ),
              _InfoChip(
                icon: Icons.event_available_outlined,
                label: customer.joinedOn != null
                    ? 'Since ${DateFormat('MMM d, yyyy').format(customer.joinedOn!)}'
                    : 'Joined date unavailable',
              ),
              _InfoChip(
                icon: Icons.history_toggle_off_outlined,
                label: customer.daysSinceLastOrder != null
                    ? (customer.daysSinceLastOrder == 0
                        ? 'Ordered today'
                        : '${customer.daysSinceLastOrder} day(s) since last order')
                    : 'No orders yet',
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (customer.isSuspended || showSubscriptionStatus) ...[
          _StatusPill(
            color: customer.isSuspended ? Colors.redAccent : statusColor,
            label: primaryStatusLabel,
          ),
          const SizedBox(height: 12),
        ],
        if (customer.suspensionNote != null &&
            customer.suspensionNote!.trim().isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Suspension note: ${customer.suspensionNote}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.redAccent,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (customer.address != null &&
            (customer.address!.address?.isNotEmpty ?? false)) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.address!.label?.isNotEmpty == true
                      ? customer.address!.label!
                      : 'Primary address',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E3A2F),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  customer.address!.address!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black87,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (customer.address!.pinCode?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'PIN: ${customer.address!.pinCode}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (customer.numberOfOrders != null || customer.totalBusiness != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: _customerAccentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                if (customer.numberOfOrders != null)
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            size: 18, color: _customerAccentColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${customer.numberOfOrders} order${customer.numberOfOrders == 1 ? "" : "s"}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF1E3A2F),
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (customer.totalBusiness != null) ...[
                  if (customer.numberOfOrders != null)
                    const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.payments_outlined,
                            size: 18, color: _customerAccentColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '₹${_formatCurrency(customer.totalBusiness!)} revenue',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF1E3A2F),
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CustomerActions extends ConsumerWidget {
  const _CustomerActions({required this.customer});

  final OutletCustomer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        switch (value) {
          case 'edit':
            await _openEditCustomer(context);
            break;
          case 'suspend':
            _showSuspendDialog(context, ref, suspend: true);
            break;
          case 'unsuspend':
            _showSuspendDialog(context, ref, suspend: false);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit'),
            subtitle: Text(customer.mobile ?? 'No mobile'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (!customer.isSuspended)
          const PopupMenuItem(
            value: 'suspend',
            child: ListTile(
              leading: Icon(Icons.pause_circle_outline),
              title: Text('Suspend customer'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (customer.isSuspended)
          const PopupMenuItem(
            value: 'unsuspend',
            child: ListTile(
              leading: Icon(Icons.play_circle_outline),
              title: Text('Re-activate customer'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
      icon: const Icon(Icons.more_vert),
    );
  }

  Future<void> _openEditCustomer(BuildContext context) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerCreateScreen(customer: customer),
      ),
    );

    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer updated')),
      );
    }
  }

  Future<void> _showSuspendDialog(
    BuildContext context,
    WidgetRef ref, {
    required bool suspend,
  }) async {
    final noteController = TextEditingController(
      text: suspend ? '' : customer.suspensionNote ?? '',
    );
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(suspend ? 'Suspend customer' : 'Re-activate customer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                suspend
                    ? 'Add an optional note explaining why the customer is being suspended.'
                    : 'You can update the note before re-activating the customer.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Suspension note',
                  hintText: 'Optional',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final notifier = ref.read(customerListProvider.notifier);
                final error = await notifier.updateSuspension(
                  customerId: customer.customerId,
                  isSuspended: suspend,
                  note: noteController.text.trim(),
                );
                if (error != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        suspend
                            ? 'Customer suspended'
                            : 'Customer re-activated',
                      ),
                    ),
                  );
                }
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: Text(suspend ? 'Suspend' : 'Re-activate'),
            ),
          ],
        );
      },
    );
    noteController.dispose();
    if (result == true && context.mounted) {
      // Nothing extra for now
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? const Color(0xFF1E3A2F);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: chipColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({
    required this.value,
    required this.verified,
    required this.icon,
    required this.verifiedIcon,
  });

  final String value;
  final bool verified;
  final IconData icon;
  final IconData verifiedIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = verified ? const Color(0xFF1E3A2F) : Colors.orange;
    final badgeColor = verified ? const Color(0xFF54A079) : Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            verified ? verifiedIcon : Icons.error_outline,
            size: 14,
            color: verified ? badgeColor : Colors.orangeAccent,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
