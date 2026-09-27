import 'package:flutter/material.dart';
import '../models/journey_models.dart';
import '../services/api_service.dart';

class BusExplorerScreen extends StatefulWidget {
  final bool isMarathi;
  const BusExplorerScreen({super.key, this.isMarathi = false});

  @override
  State<BusExplorerScreen> createState() => _BusExplorerScreenState();
}

class _BusExplorerScreenState extends State<BusExplorerScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<RouteListItem> _allRoutes = [];
  RouteDetails? _selectedRoute;
  bool _isLoading = false;
  int _activeSubTab = 0; // 0: Stops, 1: Timetable

  final List<String> _popularBuses = ['204', '333', '126', '276', '105', '305A', '368', '208'];

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes({String? query}) async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getRoutes(query: query);
      setState(() {
        _allRoutes = list;
        _isLoading = false;
      });
      if (_selectedRoute == null && list.isNotEmpty) {
        _selectRoute(list.first.routeId);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectRoute(String routeId) async {
    setState(() => _isLoading = true);
    try {
      final details = await ApiService.getRouteDetails(routeId);
      setState(() {
        _selectedRoute = details;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.isMarathi;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.departure_board, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              m ? 'बस वेळापत्रक व मार्ग' : 'PMPML Bus & Timetable',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Quick Chips Bar
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: m ? 'बस क्रमांक टाका (उदा. 204, 333, 105)' : 'Search bus number or route (e.g. 204, 333)',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF38BDF8), size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadRoutes();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      _loadRoutes(query: val.trim());
                    }
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _popularBuses.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (ctx, idx) {
                      final b = _popularBuses[idx];
                      return ActionChip(
                        label: Text('Bus $b', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        backgroundColor: const Color(0xFF334155),
                        side: const BorderSide(color: Color(0xFF475569)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onPressed: () {
                          _searchController.text = b;
                          _loadRoutes(query: b);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          if (_allRoutes.length > 1)
            Container(
              height: 38,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _allRoutes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final r = _allRoutes[i];
                  final isCur = _selectedRoute?.routeId == r.routeId;
                  return ChoiceChip(
                    label: Text(
                      r.routeShortName.isNotEmpty ? 'Bus ${r.routeShortName}' : r.routeId,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCur ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    selected: isCur,
                    selectedColor: const Color(0xFF0284C7),
                    backgroundColor: Colors.white,
                    onSelected: (_) => _selectRoute(r.routeId),
                  );
                },
              ),
            ),

          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF0284C7))))
          else if (_selectedRoute == null)
            Expanded(
              child: Center(
                child: Text(
                  m ? 'कोणतीही बस निवडली नाही' : 'Search or tap a bus number above',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            )
          else ...[
            // Route Header Card
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'BUS ${_selectedRoute!.routeShortName}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_selectedRoute!.totalStops} ${m ? "थांबे" : "Stops"}',
                          style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      if (_selectedRoute!.returnRouteId != null)
                        TextButton.icon(
                          icon: const Icon(Icons.swap_horiz, size: 16, color: Color(0xFF0284C7)),
                          label: Text(m ? 'परतीचा मार्ग' : 'Return', style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7))),
                          onPressed: () {
                            _selectRoute(_selectedRoute!.returnRouteId!);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _selectedRoute!.routeLongName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${_selectedRoute!.firstStop ?? ""} ➔ ${_selectedRoute!.lastStop ?? ""}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab bar (Stops / Timetable)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activeSubTab = 0),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _activeSubTab == 0 ? const Color(0xFF0284C7) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _activeSubTab == 0 ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1)),
                        ),
                        child: Center(
                          child: Text(
                            m ? 'थांबे यादी (${_selectedRoute!.stops.length})' : 'All Stops (${_selectedRoute!.stops.length})',
                            style: TextStyle(
                              color: _activeSubTab == 0 ? Colors.white : const Color(0xFF475569),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activeSubTab = 1),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _activeSubTab == 1 ? const Color(0xFF0284C7) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _activeSubTab == 1 ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1)),
                        ),
                        child: Center(
                          child: Text(
                            m ? 'वेळापत्रक (Timetable)' : 'Timetable (Departures)',
                            style: TextStyle(
                              color: _activeSubTab == 1 ? Colors.white : const Color(0xFF475569),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: _activeSubTab == 0
                  ? ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _selectedRoute!.stops.length,
                      itemBuilder: (ctx, idx) {
                        final stop = _selectedRoute!.stops[idx];
                        final isFirst = idx == 0;
                        final isLast = idx == _selectedRoute!.stops.length - 1;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: isFirst
                                        ? const Color(0xFF10B981)
                                        : isLast
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFFE2E8F0),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isFirst || isLast ? Colors.white : const Color(0xFF94A3B8),
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${idx + 1}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isFirst || isLast ? Colors.white : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ),
                                if (!isLast)
                                  Container(
                                    width: 2,
                                    height: 38,
                                    color: const Color(0xFFCBD5E1),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stop.stopName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isFirst || isLast ? FontWeight.bold : FontWeight.w600,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                    if (isFirst)
                                      Text(m ? 'प्रारंभिक थांबा (Origin)' : 'Starting Depot', style: const TextStyle(fontSize: 11, color: Color(0xFF10B981)))
                                    else if (isLast)
                                      Text(m ? 'अंतिम थांबा (Terminal)' : 'Final Terminal', style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Color(0xFF16A34A), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    m
                                        ? 'वारंवारता: दर १५ ते २० मिनिटांनी बस उपलब्ध असते. पहिली बस: ${_selectedRoute!.timetable.firstOrNull ?? "06:00 AM"}'
                                        : 'Frequency: Buses depart every 15-20 mins. First departure: ${_selectedRoute!.timetable.firstOrNull ?? "06:00 AM"}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            m ? 'दैनंदिन सुटण्याच्या वेळा (Daily Departures):' : 'Daily Departures from Origin Terminal:',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedRoute!.timetable.map((time) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.access_time, size: 14, color: Color(0xFF0284C7)),
                                    const SizedBox(width: 6),
                                    Text(
                                      time,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
