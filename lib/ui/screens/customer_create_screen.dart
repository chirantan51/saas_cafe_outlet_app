import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:outlet_app/data/models/outlet_customer.dart';
import 'package:outlet_app/providers/customer_provider.dart';

class CustomerCreateScreen extends ConsumerStatefulWidget {
  const CustomerCreateScreen({super.key, this.customer});

  final OutletCustomer? customer;

  @override
  ConsumerState<CustomerCreateScreen> createState() =>
      _CustomerCreateScreenState();
}

class _CustomerCreateScreenState extends ConsumerState<CustomerCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  final _pinController = TextEditingController();
  String? _existingAddressId;

  final _subscriptionStatuses = const ['Active', 'Inactive', 'Pending'];

  String _subscriptionStatus = 'Active';
  bool _isSubmitting = false;

  GoogleMapController? _mapController;
  LatLng? _selectedLatLng;
  bool _isFetchingLocation = false;
  bool _locationPermissionGranted = false;
  String? _addressError;
  String? _locationError;

  static const LatLng _defaultLatLng = LatLng(23.0225, 72.5714);

  bool get _isEditing => widget.customer != null;

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _applyInitialCustomerData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedLatLng == null) {
        _fetchInitialLocation();
      }
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _labelController.dispose();
    _addressController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _applyInitialCustomerData() {
    final existing = widget.customer;
    if (existing == null) return;

    _nameController.text = existing.name;
    _mobileController.text = existing.mobile ?? '';
    _emailController.text = existing.email ?? '';
    _subscriptionStatus =
        _normalizeSubscriptionStatus(existing.subscriptionStatus);

    final initialAddress = _resolveInitialAddress(existing);
    if (initialAddress != null) {
      _existingAddressId = initialAddress.id;
      _labelController.text = initialAddress.label ?? '';
      _addressController.text = initialAddress.address ?? '';
      _pinController.text = initialAddress.pinCode ?? '';
      final lat = initialAddress.latitude;
      final lng = initialAddress.longitude;
      if (lat != null && lng != null) {
        _selectedLatLng = LatLng(lat, lng);
      }
    }
  }

  OutletCustomerAddress? _resolveInitialAddress(OutletCustomer customer) {
    if (customer.addresses.isNotEmpty) {
      final primary = customer.addresses.firstWhere((addr) => addr.isPrimary,
          orElse: () => customer.addresses.first);
      return primary;
    }
    return customer.address;
  }

  String _normalizeSubscriptionStatus(String raw) {
    final lower = raw.toLowerCase();
    for (final option in _subscriptionStatuses) {
      if (option.toLowerCase() == lower) {
        return option;
      }
    }
    return _subscriptionStatuses.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit customer' : 'New customer'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final content = isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildCustomerDetailsCard(isWide),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(
                              right: 16,
                              bottom: 120,
                            ),
                            child: _buildAddressSection(isWide),
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCustomerDetailsCard(isWide),
                          const SizedBox(height: 24),
                          _buildAddressSection(isWide),
                        ],
                      ),
                    );

              if (isWide) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  child: content,
                );
              }
              return content;
            },
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _handleSubmit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Save changes' : 'Create customer'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerDetailsCard(bool isWide) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),
            if (isWide)
              Row(
                children: [
                  Expanded(child: _buildNameField()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMobileField()),
                ],
              )
            else ...[
              _buildNameField(),
              const SizedBox(height: 16),
              _buildMobileField(),
            ],
            const SizedBox(height: 16),
            if (isWide)
              Row(
                children: [
                  Expanded(child: _buildEmailField()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSubscriptionField()),
                ],
              )
            else ...[
              _buildEmailField(),
              const SizedBox(height: 16),
              _buildSubscriptionField(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Address (optional)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildAddressFields()),
                  const SizedBox(width: 24),
                  Expanded(child: _buildMapCard()),
                ],
              )
            : Column(
                children: [
                  _buildAddressFields(),
                  const SizedBox(height: 16),
                  _buildMapCard(),
                ],
              ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Name',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Enter a name';
        }
        return null;
      },
    );
  }

  Widget _buildMobileField() {
    return TextFormField(
      controller: _mobileController,
      decoration: const InputDecoration(
        labelText: 'Mobile number',
        hintText: '10-digit number',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.phone,
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty) {
          return 'Enter mobile number';
        }
        if (trimmed.length < 6) {
          return 'Enter a valid number';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: const InputDecoration(
        labelText: 'Email (optional)',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty) return null;
        final emailRegex = RegExp(
          r'^[^@]+@[^@]+\.[^@]+$',
          caseSensitive: false,
        );
        if (!emailRegex.hasMatch(trimmed)) {
          return 'Enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildSubscriptionField() {
    return DropdownButtonFormField<String>(
      value: _subscriptionStatus,
      items: _subscriptionStatuses
          .map(
            (status) => DropdownMenuItem<String>(
              value: status,
              child: Text(status),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _subscriptionStatus = value);
        }
      },
      decoration: const InputDecoration(
        labelText: 'Subscription status',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildAddressFields() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtleColor =
        theme.textTheme.bodySmall?.color?.withOpacity(0.7) ?? Colors.black54;
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add delivery information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Leave these fields blank if you do not want to capture an address right now.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: subtleColor,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'Home / Work',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _addressError = null),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (_) => setState(() => _addressError = null),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pinController,
              decoration: const InputDecoration(
                labelText: 'PIN code',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() => _addressError = null),
            ),
            if (_addressError != null) ...[
              const SizedBox(height: 12),
              Text(
                _addressError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtleColor =
        theme.textTheme.bodySmall?.color?.withOpacity(0.7) ?? Colors.black54;
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Drop a pin',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Position the marker to capture customer location.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: subtleColor),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Clear pin',
                  icon: const Icon(Icons.clear),
                  color: colorScheme.primary,
                  onPressed: _selectedLatLng == null
                      ? null
                      : () {
                          setState(() {
                            _selectedLatLng = null;
                            _locationError = null;
                          });
                        },
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  SizedBox(
                    height: 280,
                    child: GoogleMap(
                      onMapCreated: (controller) => _mapController = controller,
                      initialCameraPosition: CameraPosition(
                        target: _selectedLatLng ?? _defaultLatLng,
                        zoom: 14,
                      ),
                      onTap: _handleMapTap,
                      markers: {
                        if (_selectedLatLng != null)
                          Marker(
                            markerId: const MarkerId('selected'),
                            position: _selectedLatLng!,
                          ),
                      },
                      myLocationEnabled: _locationPermissionGranted,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: true,
                      zoomGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      gestureRecognizers: <Factory<
                          OneSequenceGestureRecognizer>>{
                        Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                        ),
                      },
                    ),
                  ),
                  if (_isFetchingLocation)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.08),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                  ),
                  onPressed: _isFetchingLocation ? null : _fetchInitialLocation,
                  icon: const Icon(Icons.my_location_outlined),
                  label: const Text('Use my location'),
                ),
                if (_selectedLatLng != null) ...[
                  const SizedBox(width: 12),
                  Chip(
                    avatar: Icon(Icons.push_pin,
                        size: 18, color: colorScheme.onPrimaryContainer),
                    label: const Text('Pin placed'),
                    backgroundColor: colorScheme.primaryContainer,
                    labelStyle: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            if (_locationError != null) ...[
              const SizedBox(height: 6),
              Text(
                _locationError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                'Tap anywhere on the map to drop or move the pin.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: subtleColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _fetchInitialLocation() async {
    if (_isFetchingLocation) return;
    _safeSetState(() {
      _isFetchingLocation = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _safeSetState(() {
          _locationPermissionGranted = false;
          _isFetchingLocation = false;
          _locationError = 'Turn on location services to fetch your position.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _safeSetState(() {
          _locationPermissionGranted = false;
          _isFetchingLocation = false;
          _locationError = 'Location permission denied.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latLng = LatLng(position.latitude, position.longitude);
      _safeSetState(() {
        _selectedLatLng = latLng;
        _locationPermissionGranted = true;
        _isFetchingLocation = false;
        _locationError = null;
      });
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 16),
        ),
      );
    } catch (e) {
      _safeSetState(() {
        _locationError = 'Unable to fetch location. Please try again.';
        _isFetchingLocation = false;
      });
    }
  }

  void _handleMapTap(LatLng position) {
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
    _safeSetState(() {
      _selectedLatLng = position;
      _locationError = null;
    });
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final email = _emailController.text.trim().isEmpty
        ? null
        : _emailController.text.trim();

    final label = _labelController.text.trim();
    final addressLine = _addressController.text.trim();
    final pin = _pinController.text.trim();
    final hasAddressInput =
        [label, addressLine, pin].any((value) => value.isNotEmpty);

    List<Map<String, dynamic>>? addresses;
    if (hasAddressInput) {
      if (label.isEmpty || addressLine.isEmpty || pin.isEmpty) {
        _safeSetState(() {
          _addressError = 'Fill label, address and PIN to save the address.';
        });
        return;
      }
      if (_selectedLatLng == null) {
        _safeSetState(() {
          _addressError = 'Drop a pin on the map to capture location.';
        });
        return;
      }
      addresses = [
        {
          if (_isEditing && _existingAddressId != null)
            'id': _existingAddressId,
          if (_isEditing && _existingAddressId != null)
            'address_id': _existingAddressId,
          'label': label,
          'address': addressLine,
          'pin_code': pin,
          'latitude': _selectedLatLng!.latitude.toStringAsFixed(6),
          'longitude': _selectedLatLng!.longitude.toStringAsFixed(6),
          'is_primary': true,
        },
      ];
    }

    _safeSetState(() {
      _isSubmitting = true;
      _addressError = null;
    });

    final notifier = ref.read(customerListProvider.notifier);
    String? error;
    bool success = false;
    if (_isEditing) {
      final result = await notifier.updateCustomer(
        customerId: widget.customer!.customerId,
        name: name,
        mobile: mobile,
        email: email,
        subscriptionStatus: _subscriptionStatus,
        addresses: addresses,
      );
      success = result.success;
      error = result.error;
    } else {
      error = await notifier.createCustomer(
        name: name,
        mobile: mobile,
        email: email,
        subscriptionStatus: _subscriptionStatus,
        addresses: addresses,
      );
      success = error == null;
    }

    if (!mounted) return;

    _safeSetState(() => _isSubmitting = false);

    if (!success) {
      final message =
          error ?? 'Something went wrong while saving the customer.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    Navigator.of(context).pop(true);
  }
}
