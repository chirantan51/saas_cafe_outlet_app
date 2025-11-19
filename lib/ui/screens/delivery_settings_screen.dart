import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../providers/delivery_config_provider.dart';
import '../../services/outlet_service.dart';

class DeliverySettingsScreen extends ConsumerStatefulWidget {
  final String outletId;
  const DeliverySettingsScreen({required this.outletId, super.key});

  @override
  ConsumerState<DeliverySettingsScreen> createState() =>
      _DeliverySettingsScreenState();
}

class _DeliverySettingsScreenState
    extends ConsumerState<DeliverySettingsScreen> {
  static const LatLng _defaultLatLng =
      LatLng(23.0225, 72.5714); // Ahmedabad fallback

  late final TextEditingController _radiusController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  final List<_ChargeControllers> _charges = [];
  final List<_GeoFenceDraft> _geoFences = [];

  GoogleMapController? _mapController;
  LatLng _markerPosition = _defaultLatLng;
  double _radiusKm = 0;
  bool _isSaving = false;
  bool _initialised = false;
  bool _requestedDeviceLocation = false;
  BitmapDescriptor? _outletMarkerIcon;

  @override
  void initState() {
    super.initState();
    _radiusController = TextEditingController();
    _latController = TextEditingController(
        text: _markerPosition.latitude.toStringAsFixed(6));
    _lngController = TextEditingController(
        text: _markerPosition.longitude.toStringAsFixed(6));
    _charges.add(_ChargeControllers());
    _loadOutletMarkerIcon();
  }

  void _updateCoordinateControllers(LatLng position) {
    _latController.text = position.latitude.toStringAsFixed(6);
    _lngController.text = position.longitude.toStringAsFixed(6);
  }

  @override
  void dispose() {
    _radiusController.dispose();
    _latController.dispose();
    _lngController.dispose();
    for (final charge in _charges) {
      charge.dispose();
    }
    _mapController?.dispose();
    super.dispose();
  }

  void _applyConfig(DeliveryConfig config) {
    setState(() {
      _initialised = true;
      _radiusKm = config.deliveryRadiusKm;
      _radiusController.text = _radiusKm > 0 ? _radiusKm.toString() : '';

      if (config.outletLocation != null) {
        _markerPosition =
            LatLng(config.outletLocation!.lat, config.outletLocation!.lng);
      }

      for (final charge in _charges) {
        charge.dispose();
      }
      _charges
        ..clear()
        ..addAll(config.distanceCharges.isEmpty
            ? [_ChargeControllers()]
            : config.distanceCharges.map((tier) => _ChargeControllers(
                km: tier.upToKm, charge: tier.chargeAmount)));
      _geoFences
        ..clear()
        ..addAll(config.geoFences
            .map((fence) => _GeoFenceDraft(
                  id: fence.id,
                  points: fence.points
                      .map((point) => LatLng(point.lat, point.lng))
                      .toList(),
                ))
            .toList());
    });

    _updateCoordinateControllers(_markerPosition);
    if (config.outletLocation == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureDeviceLocation(),
      );
    }

    _animateCamera();
  }

  void _animateCamera() {
    final controller = _mapController;
    if (controller == null) return;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: _markerPosition, zoom: _zoomForRadius(_radiusKm)),
    ));
  }

  double _zoomForRadius(double radiusKm) {
    if (radiusKm <= 0) return 15;
    final clamped = radiusKm.clamp(0.2, 20.0);
    final zoom = 16 - math.log(clamped) / math.ln2;
    return zoom.clamp(11.0, 18.0);
  }

  void _onRadiusChanged(String value) {
    final parsed = double.tryParse(value.trim());
    setState(() {
      _radiusKm = (parsed != null && parsed > 0) ? parsed : 0;
    });
    _animateCamera();
  }

  void _addChargeRow() {
    setState(() => _charges.add(_ChargeControllers()));
  }

  void _removeChargeRow(int index) {
    if (_charges.length == 1) {
      _charges.first
        ..kmController.clear()
        ..chargeController.clear();
      setState(() {});
      return;
    }
    setState(() {
      _charges.removeAt(index).dispose();
    });
  }

  Future<void> _openGeoFenceDialog({int? editingIndex}) async {
    final existing = editingIndex != null ? _geoFences[editingIndex] : null;
    final initialPoints =
        existing != null ? List<LatLng>.from(existing.points) : <LatLng>[];
    final initialCenter = initialPoints.isNotEmpty
        ? initialPoints.first
        : _markerPosition;

    final result = await showDialog<List<LatLng>>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _GeoFenceEditorDialog(
        initialCenter: initialCenter,
        initialPoints: initialPoints,
      ),
    );

    if (result == null || result.length < 3) {
      return;
    }

    final updatedPoints = List<LatLng>.from(result);

    setState(() {
      if (editingIndex != null) {
        final existingFence = _geoFences[editingIndex];
        _geoFences[editingIndex] = _GeoFenceDraft(
          id: existingFence.id,
          points: updatedPoints,
        );
      } else {
        _geoFences.add(_GeoFenceDraft(points: updatedPoints));
      }
    });
  }

  void _removeGeoFence(int index) {
    setState(() {
      _geoFences.removeAt(index);
    });
  }

  Future<void> _loadOutletMarkerIcon() async {
    try {
      final icon = await _buildOutletMarkerBitmap();
      if (!mounted) return;
      setState(() => _outletMarkerIcon = icon);
    } catch (err) {
      if (kDebugMode) {
        debugPrint('Failed to build outlet marker icon: $err');
      }
    }
  }

  Future<BitmapDescriptor> _buildOutletMarkerBitmap() async {
    const double width = 200;
    const double height = 84;
    const double pointerHeight = 26;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = const Color(0xFF2E7D32);

    final bodyRect =
        Rect.fromLTWH(0, 0, width, height - pointerHeight);
    const borderRadius = Radius.circular(22);
    final body = RRect.fromRectAndRadius(bodyRect, borderRadius);
    canvas.drawRRect(body, paint);

    final pointer = Path()
      ..moveTo(width / 2 - 18, height - pointerHeight)
      ..lineTo(width / 2 + 18, height - pointerHeight)
      ..lineTo(width / 2, height)
      ..close();
    canvas.drawPath(pointer, paint);

    final textStyle = ui.TextStyle(
      color: Colors.white,
      fontSize: 26,
      fontWeight: FontWeight.w600,
    );
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        maxLines: 1,
      ),
    )..pushStyle(textStyle)
     ..addText('Chaimates');

    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: width));

    final textOffset = Offset(
      0,
      ((height - pointerHeight) - paragraph.height) / 2,
    );
    canvas.drawParagraph(paragraph, textOffset);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final bytes =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _ensureDeviceLocation() async {
    if (_requestedDeviceLocation) return;
    _requestedDeviceLocation = true;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Turn on location services to detect your outlet position.');
        _requestedDeviceLocation = false;
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnack(
          'Location permission denied. Drag the pin to set your outlet location.',
        );
        _requestedDeviceLocation = false;
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() => _markerPosition = latLng);
      _updateCoordinateControllers(latLng);
      _animateCamera();
    } catch (err) {
      _requestedDeviceLocation = false;
      if (kDebugMode) {
        debugPrint('Failed to acquire device location: $err');
      }
    }
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);

    final radiusText = _radiusController.text.trim();
    final radius = double.tryParse(radiusText);
    if (radius == null || radius <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid delivery radius (km).')),
      );
      return;
    }

    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Enter valid latitude & longitude values.')),
      );
      return;
    }

    final charges = <DeliveryDistanceCharge>[];
    for (var i = 0; i < _charges.length; i++) {
      final row = _charges[i];
      final kmText = row.kmController.text.trim();
      final chargeText = row.chargeController.text.trim();
      if (kmText.isEmpty && chargeText.isEmpty) {
        continue;
      }
      final km = double.tryParse(kmText);
      final charge = double.tryParse(chargeText);
      if (km == null || km <= 0 || charge == null || charge < 0) {
        messenger.showSnackBar(
          SnackBar(
              content: Text('Invalid distance charge entry at row ${i + 1}.')),
        );
        return;
      }
      charges.add(DeliveryDistanceCharge(upToKm: km, chargeAmount: charge));
    }

    for (var i = 0; i < _geoFences.length; i++) {
      if (_geoFences[i].points.length < 3) {
        messenger.showSnackBar(
          SnackBar(
              content: Text(
                  'Geo-fence ${i + 1} needs at least three points to form a polygon.')),
        );
        return;
      }
    }

    final geoFences = _geoFences
        .map(
          (fence) => DeliveryGeoFence(
            id: fence.id,
            points: fence.points
                .map((latLng) =>
                    DeliveryGeoPoint(lat: latLng.latitude, lng: latLng.longitude))
                .toList(),
          ),
        )
        .toList();

    charges.sort((a, b) => a.upToKm.compareTo(b.upToKm));

    setState(() => _isSaving = true);
    try {
      final config = DeliveryConfig(
        deliveryRadiusKm: radius,
        outletLocation: DeliveryGeoPoint(lat: lat, lng: lng),
        distanceCharges: charges,
        geoFences: geoFences,
      );
      await OutletService.updateDeliveryConfig(
        outletId: widget.outletId,
        config: config,
      );
      if (!mounted) return;
      ref.invalidate(deliveryConfigProvider(widget.outletId));
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Delivery settings updated.')),
      );
    } catch (err) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update settings: $err')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(deliveryConfigProvider(widget.outletId));
    configAsync.whenData((config) {
      if (!_initialised) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _applyConfig(config));
      }
    });

    final isLoading = !_initialised && configAsync.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Settings'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MapPreview(
                      position: _markerPosition,
                      radiusKm: _radiusKm,
                      markerIcon: _outletMarkerIcon,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _animateCamera();
                      },
                      onMarkerDragged: (latLng) {
                        setState(() => _markerPosition = latLng);
                        _updateCoordinateControllers(latLng);
                        _mapController
                            ?.animateCamera(CameraUpdate.newLatLng(latLng));
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Outlet Location',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                              border: OutlineInputBorder(),
                            ),
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lngController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                              border: OutlineInputBorder(),
                            ),
                            readOnly: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Delivery Radius (km)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _radiusController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'e.g. 3.5',
                      ),
                      onChanged: _onRadiusChanged,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Geo-fencing',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Define specific delivery zones by drawing polygons on the map. Orders outside these areas will be ignored even if within the radius.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    if (_geoFences.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Text(
                          'No geo-fences configured yet.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (var i = 0; i < _geoFences.length; i++) ...[
                            _GeoFenceTile(
                              index: i,
                              fence: _geoFences[i],
                              onEdit: () => _openGeoFenceDialog(
                                editingIndex: i,
                              ),
                              onDelete: () => _removeGeoFence(i),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => _openGeoFenceDialog(),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Add geo-fencing'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Distance-based charges',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addChargeRow,
                          icon: const Icon(Icons.add),
                          label: const Text('Add tier'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_charges.isEmpty)
                      const Text(
                        'No tiers added. Deliveries will be free unless a tier is configured.',
                        style: TextStyle(color: Colors.black54),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _charges.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final row = _charges[index];
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: row.kmController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Up to (km)',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: row.chargeController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Charge (₹)',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove',
                                    onPressed: () => _removeChargeRow(index),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ChargeControllers {
  final TextEditingController kmController;
  final TextEditingController chargeController;

  _ChargeControllers({double? km, double? charge})
      : kmController = TextEditingController(
            text: km != null ? km.toStringAsFixed(2) : ''),
        chargeController = TextEditingController(
            text: charge != null ? charge.toStringAsFixed(2) : '');

  void dispose() {
    kmController.dispose();
    chargeController.dispose();
  }
}

class _GeoFenceDraft {
  final String? id;
  final List<LatLng> points;

  _GeoFenceDraft({this.id, required List<LatLng> points})
      : points = List<LatLng>.from(points);

  bool get isValid => points.length >= 3;
}

class _GeoFenceTile extends StatelessWidget {
  const _GeoFenceTile({
    required this.index,
    required this.fence,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final _GeoFenceDraft fence;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Zone ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  backgroundColor: fence.isValid
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  label: Text(
                    '${fence.points.length} points',
                    style: TextStyle(
                      color: fence.isValid
                          ? Colors.green.shade800
                          : Colors.orange.shade800,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Edit geo-fence',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_location_alt_outlined),
                ),
                IconButton(
                  tooltip: 'Remove geo-fence',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Vertices',
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in fence.points.asMap().entries)
                  Chip(
                    avatar: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.green.shade600,
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    label: Text(
                      '${entry.value.latitude.toStringAsFixed(5)}, ${entry.value.longitude.toStringAsFixed(5)}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Use the edit action to adjust or reorder points on the map.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeoFenceEditorDialog extends StatefulWidget {
  const _GeoFenceEditorDialog({
    required this.initialCenter,
    required this.initialPoints,
  });

  final LatLng initialCenter;
  final List<LatLng> initialPoints;

  @override
  State<_GeoFenceEditorDialog> createState() => _GeoFenceEditorDialogState();
}

class _GeoFenceEditorDialogState extends State<_GeoFenceEditorDialog> {
  late List<LatLng> _points;
  GoogleMapController? _controller;

  @override
  void initState() {
    super.initState();
    _points = widget.initialPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _addPoint(LatLng latLng) {
    setState(() {
      _points = [..._points, latLng];
    });
    _controller?.animateCamera(CameraUpdate.newLatLng(latLng));
  }

  void _updatePoint(int index, LatLng latLng) {
    if (index < 0 || index >= _points.length) return;
    setState(() {
      final updated = [..._points];
      updated[index] = latLng;
      _points = updated;
    });
  }

  void _removePoint(int index) {
    if (index < 0 || index >= _points.length) return;
    setState(() {
      final updated = [..._points]..removeAt(index);
      _points = updated;
    });
  }

  void _clearPoints() {
    setState(() => _points = []);
  }

  Set<Polygon> _buildPolygons() {
    if (_points.length < 3) return const {};
    return {
      Polygon(
        polygonId: const PolygonId('geo-fence'),
        points: _points,
        strokeColor: const Color(0xFF2E7D32),
        strokeWidth: 2,
        fillColor: const Color(0x332E7D32),
      ),
    };
  }

  Set<Polyline> _buildPolylines() {
    if (_points.length < 2) return const {};
    final path = [..._points];
    if (_points.length >= 2) {
      path.add(_points.first);
    }
    return {
      Polyline(
        polylineId: const PolylineId('geo-fence-outline'),
        points: path,
        color: const Color(0xFF2E7D32),
        width: 2,
      ),
    };
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    for (final entry in _points.asMap().entries) {
      markers.add(
        Marker(
          markerId: MarkerId('vertex-${entry.key}'),
          position: entry.value,
          draggable: true,
          onDragEnd: (latLng) => _updatePoint(entry.key, latLng),
          infoWindow: InfoWindow(
            title: 'Point ${entry.key + 1}',
          ),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final hasChanges = _points.length >= 3;
    final mapCenter =
        _points.isNotEmpty ? _points.first : widget.initialCenter;

    return AlertDialog(
      title: Text(
        _points.isEmpty && widget.initialPoints.isEmpty
            ? 'Add geo-fence'
            : 'Edit geo-fence',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 320,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.antiAlias,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: mapCenter,
                  zoom: 15,
                ),
                onMapCreated: (controller) {
                  _controller = controller;
                  if (_points.length >= 2) {
                    _controller?.animateCamera(
                      CameraUpdate.newLatLngBounds(
                        _boundsFromPoints(_points),
                        48,
                      ),
                    );
                  } else if (_points.length == 1) {
                    _controller?.animateCamera(
                      CameraUpdate.newLatLngZoom(_points.first, 16),
                    );
                  }
                },
                onTap: _addPoint,
                markers: _buildMarkers(),
                polygons: _buildPolygons(),
                polylines: _buildPolylines(),
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tap to add points. Drag markers to adjust. Remove a point using the delete icon on its chip.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_points.isEmpty)
                  const Text(
                    'No points added yet.',
                    style: TextStyle(color: Colors.black54),
                  )
                else
                  for (final entry in _points.asMap().entries)
                    Chip(
                      avatar: CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.green.shade600,
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      label: Text(
                        '${entry.value.latitude.toStringAsFixed(5)}, ${entry.value.longitude.toStringAsFixed(5)}',
                      ),
                      onDeleted: () => _removePoint(entry.key),
                    ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _points.isEmpty ? null : _clearPoints,
          child: const Text('Clear all'),
        ),
        FilledButton(
          onPressed: hasChanges
              ? () => Navigator.of(context).pop(List<LatLng>.from(_points))
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }

  static LatLngBounds _boundsFromPoints(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    if (minLat == maxLat) {
      minLat -= 0.0001;
      maxLat += 0.0001;
    }
    if (minLng == maxLng) {
      minLng -= 0.0001;
      maxLng += 0.0001;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.position,
    required this.radiusKm,
    required this.markerIcon,
    required this.onMapCreated,
    required this.onMarkerDragged,
  });

  final LatLng position;
  final double radiusKm;
  final BitmapDescriptor? markerIcon;
  final void Function(GoogleMapController controller) onMapCreated;
  final ValueChanged<LatLng> onMarkerDragged;

  @override
  Widget build(BuildContext context) {
    final circles = <Circle>{};
    if (radiusKm > 0) {
      circles.add(
        Circle(
          circleId: const CircleId('delivery-radius'),
          center: position,
          radius: radiusKm * 1000,
          strokeColor: const Color(0x8054A079),
          strokeWidth: 2,
          fillColor: const Color(0x3354A079),
        ),
      );
    }

    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: position,
          zoom: 15,
        ),
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<OneSequenceGestureRecognizer>(
            () => EagerGestureRecognizer(),
          ),
        },
        markers: {
          Marker(
            markerId: const MarkerId('outlet'),
            position: position,
            icon: markerIcon ?? BitmapDescriptor.defaultMarker,
            draggable: true,
            onDragEnd: onMarkerDragged,
          ),
        },
        onTap: onMarkerDragged,
        circles: circles,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        onMapCreated: onMapCreated,
      ),
    );
  }
}
