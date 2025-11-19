import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:outlet_app/data/models/outlet_customer.dart';
import 'package:outlet_app/services/customer_service.dart';

class CustomerUpdateResult {
  const CustomerUpdateResult._({
    required this.success,
    this.customer,
    this.error,
  });

  final bool success;
  final OutletCustomer? customer;
  final String? error;

  factory CustomerUpdateResult.success(OutletCustomer customer) =>
      CustomerUpdateResult._(success: true, customer: customer);

  factory CustomerUpdateResult.failure(String error) =>
      CustomerUpdateResult._(success: false, error: error);
}

class CustomerListState {
  const CustomerListState({
    required this.customers,
    required this.isLoading,
    required this.isLoadingMore,
    required this.isRefreshing,
    required this.hasMore,
    required this.totalCount,
    required this.nextPage,
    required this.errorMessage,
    required this.initialized,
  });

  final List<OutletCustomer> customers;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isRefreshing;
  final bool hasMore;
  final int totalCount;
  final int? nextPage;
  final String? errorMessage;
  final bool initialized;

  factory CustomerListState.initial() => const CustomerListState(
        customers: [],
        isLoading: false,
        isLoadingMore: false,
        isRefreshing: false,
        hasMore: false,
        totalCount: 0,
        nextPage: 1,
        errorMessage: null,
        initialized: false,
      );

  CustomerListState copyWith({
    List<OutletCustomer>? customers,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool? hasMore,
    int? totalCount,
    int? nextPage,
    String? errorMessage,
    bool? initialized,
    bool clearError = false,
  }) {
    return CustomerListState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasMore: hasMore ?? this.hasMore,
      totalCount: totalCount ?? this.totalCount,
      nextPage: nextPage ?? this.nextPage,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      initialized: initialized ?? this.initialized,
    );
  }
}

class CustomerListNotifier extends StateNotifier<CustomerListState> {
  CustomerListNotifier() : super(CustomerListState.initial());

  bool _fetchInProgress = false;

  Future<void> loadInitial({bool force = false}) async {
    if (_fetchInProgress) return;
    if (state.initialized && !force) return;
    _fetchInProgress = true;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await CustomerService.fetchCustomers(page: 1);
      state = state.copyWith(
        customers: page.results,
        totalCount: page.count,
        hasMore: page.hasNext,
        nextPage: page.hasNext ? (page.nextPage ?? 2) : null,
        isLoading: false,
        initialized: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
        initialized: true,
      );
    } finally {
      _fetchInProgress = false;
    }
  }

  Future<void> refresh() async {
    if (_fetchInProgress) return;
    _fetchInProgress = true;
    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      final page = await CustomerService.fetchCustomers(page: 1);
      state = state.copyWith(
        customers: page.results,
        totalCount: page.count,
        hasMore: page.hasNext,
        nextPage: page.hasNext ? (page.nextPage ?? 2) : null,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: e.toString(),
      );
    } finally {
      _fetchInProgress = false;
    }
  }

  Future<void> loadMore() async {
    final nextPage = state.nextPage;
    if (_fetchInProgress || !state.hasMore || nextPage == null) {
      return;
    }
    _fetchInProgress = true;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await CustomerService.fetchCustomers(page: nextPage);
      state = state.copyWith(
        customers: [...state.customers, ...page.results],
        totalCount: page.count,
        hasMore: page.hasNext,
        nextPage: page.hasNext ? (page.nextPage ?? nextPage + 1) : null,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: e.toString(),
      );
    } finally {
      _fetchInProgress = false;
    }
  }

  Future<String?> createCustomer({
    required String name,
    required String mobile,
    String? email,
    String? subscriptionStatus,
    List<Map<String, dynamic>>? addresses,
  }) async {
    try {
      final created = await CustomerService.createCustomer(
        name: name,
        mobile: mobile,
        email: email,
        subscriptionStatus: subscriptionStatus,
        addresses: addresses,
      );
      state = state.copyWith(
        customers: [created, ...state.customers],
        totalCount: state.totalCount + 1,
        clearError: true,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateSuspension({
    required String customerId,
    required bool isSuspended,
    String? note,
  }) async {
    try {
      final updated = await CustomerService.updateSuspension(
        customerId: customerId,
        isSuspended: isSuspended,
        note: note,
      );
      final updatedList = state.customers
          .map((c) => c.customerId == customerId ? updated : c)
          .toList();
      state = state.copyWith(customers: updatedList, clearError: true);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<CustomerUpdateResult> updateCustomer({
    required String customerId,
    required String name,
    required String mobile,
    String? email,
    String? subscriptionStatus,
    List<Map<String, dynamic>>? addresses,
  }) async {
    try {
      final updated = await CustomerService.updateCustomer(
        customerId: customerId,
        name: name,
        mobile: mobile,
        email: email,
        subscriptionStatus: subscriptionStatus,
        addresses: addresses,
      );
      final merged = _mergeCustomerData(
        remote: updated,
        localAddressesPayload: addresses,
      );
      final updatedList = state.customers
          .map((c) => c.customerId == customerId ? merged : c)
          .toList();
      state = state.copyWith(
        customers: updatedList,
        clearError: true,
      );
      return CustomerUpdateResult.success(merged);
    } catch (e) {
      final message = e.toString();
      state = state.copyWith(errorMessage: message);
      return CustomerUpdateResult.failure(message);
    }
  }
}

OutletCustomer _mergeCustomerData({
  required OutletCustomer remote,
  List<Map<String, dynamic>>? localAddressesPayload,
}) {
  if (localAddressesPayload == null || localAddressesPayload.isEmpty) {
    return remote;
  }

  List<OutletCustomerAddress> parseAddresses(
      List<Map<String, dynamic>> source) {
    return source.map((raw) => OutletCustomerAddress.fromJson(raw)).toList();
  }

  String? normalize(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.toLowerCase();
  }

  final localAddresses = parseAddresses(localAddressesPayload);
  if (localAddresses.isEmpty) return remote;

  String keyFor(OutletCustomerAddress addr) {
    final id = addr.id?.toString();
    if (id != null && id.isNotEmpty) return id;

    final parts = [
      normalize(addr.label),
      normalize(addr.address),
      normalize(addr.pinCode),
    ].whereType<String>().toList();

    if (parts.isEmpty) {
      return addr.hashCode.toString();
    }
    return parts.join('|');
  }

  final localByKey = <String, OutletCustomerAddress>{};
  for (final address in localAddresses) {
    localByKey[keyFor(address)] = address;
  }

  final mergedAddresses = <OutletCustomerAddress>[];
  for (final existing in remote.addresses) {
    final key = keyFor(existing);
    if (localByKey.containsKey(key)) {
      mergedAddresses.add(localByKey.remove(key)!);
    } else {
      mergedAddresses.add(existing);
    }
  }

  mergedAddresses.addAll(localByKey.values);

  OutletCustomerAddress? mergedPrimary;
  try {
    mergedPrimary = localAddresses.firstWhere((addr) => addr.isPrimary);
  } catch (_) {
    mergedPrimary = remote.address;
  }

  mergedPrimary ??=
      mergedAddresses.isNotEmpty ? mergedAddresses.first : remote.address;

  return remote.copyWith(
    address: mergedPrimary,
    addresses: mergedAddresses,
  );
}

final customerListProvider =
    StateNotifierProvider<CustomerListNotifier, CustomerListState>(
  (ref) => CustomerListNotifier(),
);
