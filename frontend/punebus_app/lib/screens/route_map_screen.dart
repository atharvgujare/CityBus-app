import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/journey_models.dart';

class RouteMapScreen extends StatefulWidget {
  final JourneyOption journey;
  final String originName;
  final String destinationName;

  const RouteMapScreen({
    super.key,
    required this.journey,
    required this.originName,
    required this.destinationName,
  });

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  int _activeStepIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchLiveLocation();
  }

  Future<void> _fetchLiveLocation() async {
    try {
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.always || hasPermission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        if (mounted) {
          setState(() {
            _currentPosition = pos;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final busLegs = widget.journey.legs.where((l) => l.type == 'BUS').toList();
    final walkLegs = widget.journey.legs.where((l) => l.type == 'WALK' || l.type == 'TRANSFER_WALK').toList();

    // Collect all points for map bounds
    final allPoints = <LatLng>[];
    for (final leg in widget.journey.legs) {
      for (final p in leg.pathCoordinates) {
        allPoints.add(LatLng(p.latitude, p.longitude));
      }
    }

    if (allPoints.isEmpty && widget.journey.mapPolyline.isNotEmpty) {
      allPoints.addAll(widget.journey.mapPolyline.map((p) => LatLng(p.latitude, p.longitude)));
    }

    final initialCenter = allPoints.isNotEmpty
        ? LatLng(
            allPoints.map((p) => p.latitude).reduce((a, b) => a + b) / allPoints.length,
            allPoints.map((p) => p.longitude).reduce((a, b) => a + b) / allPoints.length,
          )
        : const LatLng(18.5204, 73.8567);

    final currentLeg = widget.journey.legs.isNotEmpty && _activeStepIndex < widget.journey.legs.length
        ? widget.journey.legs[_activeStepIndex]
        : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.originName} → ${widget.destinationName}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${widget.journey.totalDurationMinutes} min • ₹${widget.journey.totalFareRupees} • ${widget.journey.transferCount == 0 ? "Direct Bus" : "1 Transfer"}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'recenter_user',
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            tooltip: 'My Live GPS Location',
            onPressed: () {
              if (_currentPosition != null) {
                _mapController.move(
                  LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                  16.0,
                );
              } else {
                _fetchLiveLocation();
              }
            },
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'fit_bounds',
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: Colors.white,
            tooltip: 'Fit Whole Route',
            onPressed: () {
              if (allPoints.isNotEmpty) {
                _mapController.move(initialCenter, 13.0);
              }
            },
            child: const Icon(Icons.fullscreen),
          ),
          const SizedBox(height: 120), // padding above bottom guidance card
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.punebus.app',
              ),

              // Polyline Layers for Each Leg
              PolylineLayer(
                polylines: [
                  // Walking Polylines (Dashed Amber/Orange)
                  for (final leg in walkLegs)
                    if (leg.pathCoordinates.length >= 2)
                      Polyline(
                        points: leg.pathCoordinates.map((p) => LatLng(p.latitude, p.longitude)).toList(),
                        color: const Color(0xFFF59E0B),
                        strokeWidth: 4.0,
                        pattern: const StrokePattern.dotted(),
                      ),

                  // Bus Polylines
                  for (int i = 0; i < busLegs.length; i++)
                    if (busLegs[i].pathCoordinates.length >= 2)
                      Polyline(
                        points: busLegs[i].pathCoordinates.map((p) => LatLng(p.latitude, p.longitude)).toList(),
                        color: i == 0 ? const Color(0xFF0284C7) : const Color(0xFF7C3AED),
                        strokeWidth: 5.5,
                      ),
                ],
              ),

              // Markers Layer
              MarkerLayer(
                markers: [
                  // 1. Live User GPS Position
                  if (_currentPosition != null)
                    Marker(
                      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 2. Boarding Stop Markers
                  for (int i = 0; i < busLegs.length; i++) ...[
                    if (busLegs[i].pathCoordinates.isNotEmpty)
                      Marker(
                        point: LatLng(
                          busLegs[i].pathCoordinates.first.latitude,
                          busLegs[i].pathCoordinates.first.longitude,
                        ),
                        width: 140,
                        height: 50,
                        child: _buildStopBadge(
                          title: i == 0 ? 'BOARD HERE' : 'CHANGE BUS',
                          subtitle: busLegs[i].boardStop ?? 'Stop',
                          badgeColor: i == 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          icon: Icons.directions_bus,
                        ),
                      ),

                    // 3. Get Off Stop Marker
                    if (busLegs[i].pathCoordinates.isNotEmpty)
                      Marker(
                        point: LatLng(
                          busLegs[i].pathCoordinates.last.latitude,
                          busLegs[i].pathCoordinates.last.longitude,
                        ),
                        width: 140,
                        height: 50,
                        child: _buildStopBadge(
                          title: i == busLegs.length - 1 ? 'GET DOWN HERE' : 'TRANSFER',
                          subtitle: busLegs[i].getOffStop ?? 'Stop',
                          badgeColor: i == busLegs.length - 1 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                          icon: i == busLegs.length - 1 ? Icons.pin_drop : Icons.sync,
                        ),
                      ),
                  ],
                ],
              ),
            ],
          ),

          // Top Guidance Legend
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem(const Color(0xFFF59E0B), 'Walking Path'),
                  _buildLegendItem(const Color(0xFF0284C7), 'Bus Route'),
                  if (widget.journey.transferCount > 0)
                    _buildLegendItem(const Color(0xFF7C3AED), 'Bus 2 Route'),
                  _buildLegendItem(const Color(0xFF10B981), 'Board'),
                  _buildLegendItem(const Color(0xFFEF4444), 'Get Off'),
                ],
              ),
            ),
          ),

          // Bottom Step-by-Step Navigation HUD
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step Indicator & Navigation Arrows
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Step ${_activeStepIndex + 1} of ${widget.journey.legs.length}',
                          style: const TextStyle(
                            color: Color(0xFF0284C7),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.arrow_back_ios, size: 16),
                            onPressed: _activeStepIndex > 0
                                ? () => _focusStep(_activeStepIndex - 1)
                                : null,
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.arrow_forward_ios, size: 16),
                            onPressed: _activeStepIndex < widget.journey.legs.length - 1
                                ? () => _focusStep(_activeStepIndex + 1)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Current Step Guidance
                  if (currentLeg != null) ...[
                    if (currentLeg.type == 'WALK' || currentLeg.type == 'TRANSFER_WALK') ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.directions_walk, color: Color(0xFFD97706), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentLeg.instruction,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  'Distance: ${currentLeg.distanceMeters}m • ~${currentLeg.durationMinutes} min walk',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.directions_bus, color: Color(0xFF0284C7), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'BOARD BUS ${currentLeg.routeNumber}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0284C7)),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '₹${currentLeg.estimatedFareRupees}',
                                        style: const TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Board at ${currentLeg.boardStop} → Get off at ${currentLeg.getOffStop}',
                                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                                if (currentLeg.alternateBuses.length > 1)
                                  Text(
                                    'Can also take: ${currentLeg.alternateBuses.where((b) => b != currentLeg.routeNumber).take(3).join(', ')}',
                                    style: const TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _focusStep(int index) {
    setState(() => _activeStepIndex = index);
    final leg = widget.journey.legs[index];
    if (leg.pathCoordinates.isNotEmpty) {
      final first = leg.pathCoordinates.first;
      _mapController.move(LatLng(first.latitude, first.longitude), 15.0);
    }
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ],
    );
  }

  Widget _buildStopBadge({
    required String title,
    required String subtitle,
    required Color badgeColor,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 12),
              const SizedBox(width: 4),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: badgeColor, width: 1.5),
          ),
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
