import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/journey_models.dart';
import 'route_map_screen.dart';

class JourneyResultsScreen extends StatefulWidget {
  final String originName;
  final String destinationName;
  final List<JourneyOption> journeys;

  const JourneyResultsScreen({
    super.key,
    required this.originName,
    required this.destinationName,
    required this.journeys,
  });

  @override
  State<JourneyResultsScreen> createState() => _JourneyResultsScreenState();
}

class _JourneyResultsScreenState extends State<JourneyResultsScreen> {
  int _selectedJourneyIndex = 0;
  StreamSubscription<Position>? _alarmSubscription;
  bool _isAlarmActive = false;
  double? _distanceToAlightMeters;
  String? _alarmTargetStop;
  bool _hasTriggeredAlarm = false;

  @override
  void dispose() {
    _alarmSubscription?.cancel();
    super.dispose();
  }

  Future<void> _toggleGeoAlarm(JourneyOption journey) async {
    if (_isAlarmActive) {
      _alarmSubscription?.cancel();
      setState(() {
        _isAlarmActive = false;
        _alarmTargetStop = null;
        _distanceToAlightMeters = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stop arrival alarm turned off.')),
      );
      return;
    }

    // Find the get off stop from the last bus leg
    final lastBusLeg = journey.legs.lastWhere(
      (l) => l.type == 'BUS',
      orElse: () => journey.legs.first,
    );

    final stopName = lastBusLeg.getOffStop ?? widget.destinationName;
    double targetLat = 0;
    double targetLon = 0;

    // Check if pathCoordinates has getOffStop
    if (lastBusLeg.pathCoordinates.isNotEmpty) {
      targetLat = lastBusLeg.pathCoordinates.last.latitude;
      targetLon = lastBusLeg.pathCoordinates.last.longitude;
    }

    bool perm = await Geolocator.isLocationServiceEnabled();
    if (!perm) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable GPS location to activate stop alarm.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (!mounted) return;
    setState(() {
      _isAlarmActive = true;
      _alarmTargetStop = stopName;
      _hasTriggeredAlarm = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        content: Text('🔔 Alarm Set! We will ring & vibrate 500m before $stopName.'),
      ),
    );

    _alarmSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15),
    ).listen((pos) {
      if (targetLat != 0 && targetLon != 0) {
        final dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, targetLat, targetLon);
        if (mounted) {
          setState(() {
            _distanceToAlightMeters = dist;
          });
        }

        if (dist <= 500 && !_hasTriggeredAlarm) {
          _hasTriggeredAlarm = true;
          _triggerWakeUpAlarm(stopName, dist);
        }
      }
    });
  }

  void _triggerWakeUpAlarm(String stopName, double dist) {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFF59E0B), width: 2)),
        title: const Row(
          children: [
            Icon(Icons.alarm_on, color: Color(0xFFF59E0B), size: 28),
            SizedBox(width: 10),
            Text('WAKE UP!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your stop "$stopName" is arriving in ~${(dist / 75).ceil()} min (${dist.toInt()}m away)!',
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 15),
            ),
            const SizedBox(height: 12),
            const Text(
              'Prepare to get down from the bus.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _toggleGeoAlarm(widget.journeys[_selectedJourneyIndex]);
            },
            child: const Text('I am Awake / Stop Alarm'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (widget.journeys.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Journey Options')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bus_alert, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'No direct or 1-transfer PMPML bus route found for this pair.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Try picking a nearby major chowk or bus terminal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Search'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentJourney = widget.journeys[_selectedJourneyIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
            const Text(
              'PMPML Step-by-Step Directions',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map, color: Color(0xFF38BDF8)),
            tooltip: 'View Route on Map',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RouteMapScreen(
                    journey: currentJourney,
                    originName: widget.originName,
                    destinationName: widget.destinationName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.map_outlined),
        label: const Text('View on Map', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RouteMapScreen(
                journey: currentJourney,
                originName: widget.originName,
                destinationName: widget.destinationName,
              ),
            ),
          );
        },
      ),
      body: Column(
        children: [
          // Category Choice Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(widget.journeys.length, (index) {
                  final j = widget.journeys[index];
                  final isSelected = index == _selectedJourneyIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      selected: isSelected,
                      selectedColor: const Color(0xFF0284C7),
                      backgroundColor: const Color(0xFFF1F5F9),
                      label: Row(
                        children: [
                          Icon(
                            _getCategoryIcon(j.category),
                            size: 16,
                            color: isSelected ? Colors.white : const Color(0xFF0F172A),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getCategoryTitle(j.category),
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white24 : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${j.totalDurationMinutes}m',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedJourneyIndex = index);
                      },
                    ),
                  );
                }),
              ),
            ),
          ),

          // Overview KPI Card with Fare
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        currentJourney.summary,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '₹${currentJourney.totalFareRupees}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildKpiItem(Icons.schedule, '${currentJourney.totalDurationMinutes} min', 'Total Time'),
                    _buildKpiItem(Icons.directions_walk, '${currentJourney.totalWalkingMeters} m', 'Walking'),
                    _buildKpiItem(Icons.alt_route, '${currentJourney.transferCount}', 'Transfers'),
                    _buildKpiItem(Icons.confirmation_number_outlined, '₹${currentJourney.totalFareRupees}', 'Ticket Fare'),
                  ],
                ),
                if (currentJourney.dailyPassTip != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Color(0xFF38BDF8), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            currentJourney.dailyPassTip!,
                            style: const TextStyle(color: Color(0xFFE0F2FE), fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _toggleGeoAlarm(currentJourney),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isAlarmActive ? const Color(0xFFF59E0B).withValues(alpha: 0.2) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isAlarmActive ? const Color(0xFFF59E0B) : const Color(0xFF475569),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isAlarmActive ? Icons.alarm_on : Icons.notifications_active_outlined,
                          color: _isAlarmActive ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isAlarmActive
                                ? (_distanceToAlightMeters != null
                                    ? '🔔 Alarm ON: ${_distanceToAlightMeters!.toInt()}m to $_alarmTargetStop'
                                    : '🔔 Alarm ON: Tracking GPS to $_alarmTargetStop...')
                                : 'Wake Me Up Before My Stop (500m GPS Alarm)',
                            style: TextStyle(
                              color: _isAlarmActive ? const Color(0xFFFDE68A) : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isAlarmActive ? const Color(0xFFEF4444) : const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _isAlarmActive ? 'DISMISS' : 'SET ALARM',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Step-by-Step Leg Details List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              itemCount: currentJourney.legs.length,
              itemBuilder: (context, index) {
                final leg = currentJourney.legs[index];
                final isLast = index == currentJourney.legs.length - 1;
                return _buildLegCard(leg, index + 1, isLast);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF38BDF8), size: 18),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
      ],
    );
  }

  Widget _buildLegCard(JourneyLeg leg, int stepNumber, bool isLast) {
    if (leg.type == 'BUS') {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0284C7).withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_bus, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'BUS ${leg.routeNumber}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Text(
                      'Fare: ₹${leg.estimatedFareRupees}',
                      style: const TextStyle(color: Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '~${leg.durationMinutes} mins (${leg.intermediateStopsCount ?? 0} stops)',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),

              // "Take Any Bus" Banner if parallel buses exist
              if (leg.alternateBuses.length > 1) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.checklist, color: Color(0xFF16A34A), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Board ANY bus: ${leg.alternateBuses.join(', ')}',
                          style: const TextStyle(
                            color: Color(0xFF15803D),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Next Departures / Headway
              if (leg.nextDepartures.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    const Text('Next at stop: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    Expanded(
                      child: Text(
                        leg.nextDepartures.take(3).join(', '),
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),
              _buildStopPoint(
                isBoarding: true,
                stopName: leg.boardStop ?? '',
                subtext: 'Board here',
              ),
              Padding(
                padding: const EdgeInsets.only(left: 11.0),
                child: Container(
                  width: 2,
                  height: 24,
                  color: const Color(0xFFCBD5E1),
                ),
              ),
              _buildStopPoint(
                isBoarding: false,
                stopName: leg.getOffStop ?? '',
                subtext: 'Get down here',
              ),

              // Expandable Intermediate Stops
              if (leg.intermediateStops.isNotEmpty) ...[
                const SizedBox(height: 10),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                    title: Text(
                      'View all ${leg.intermediateStops.length} stops on this route',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                    ),
                    children: leg.intermediateStops.map((stop) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3.0),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF94A3B8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(stop, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } else if (leg.type == 'TRANSFER_WALK') {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFFF59E0B),
              child: Icon(Icons.transfer_within_a_station, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                leg.instruction,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 13),
              ),
            ),
          ],
        ),
      );
    } else {
      // WALK leg
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFFE2E8F0),
              child: Icon(Icons.directions_walk, color: Color(0xFF475569), size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leg.instruction,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontSize: 13),
                  ),
                  Text(
                    '${leg.distanceMeters} meters (~${leg.durationMinutes} mins)',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildStopPoint({required bool isBoarding, required String stopName, required String subtext}) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isBoarding ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isBoarding ? Icons.arrow_upward : Icons.arrow_downward,
            color: Colors.white,
            size: 14,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stopName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
              ),
              Text(
                subtext,
                style: TextStyle(
                  color: isBoarding ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'FASTEST':
        return Icons.bolt;
      case 'LEAST_WALKING':
        return Icons.directions_walk;
      case 'FEWEST_TRANSFERS':
        return Icons.alt_route;
      default:
        return Icons.star_border;
    }
  }

  String _getCategoryTitle(String cat) {
    switch (cat) {
      case 'FASTEST':
        return 'Fastest';
      case 'LEAST_WALKING':
        return 'Least Walk';
      case 'FEWEST_TRANSFERS':
        return 'Fewest Changes';
      default:
        return 'Recommended';
    }
  }
}
