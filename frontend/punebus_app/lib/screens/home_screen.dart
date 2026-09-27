import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/journey_models.dart';
import '../services/api_service.dart';
import 'bus_explorer_screen.dart';
import 'journey_results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0; // 0: Planner, 1: Bus Explorer
  final TextEditingController _fromController = TextEditingController(text: 'Aundhgaon');
  final TextEditingController _toController = TextEditingController(text: 'Dange Chowk');

  double _fromLat = 18.5657;
  double _fromLon = 73.8121;
  double _toLat = 18.6186;
  double _toLon = 73.7744;

  bool _isLoading = false;
  bool _isLocating = false;
  bool _isLoadingViableStops = false;
  String? _errorMessage;
  bool _isMarathi = false;

  List<StopItem> _fromSuggestions = [];
  List<StopItem> _toSuggestions = [];


  @override
  Widget build(BuildContext context) {
    if (_navIndex == 1) {
      return Scaffold(
        body: BusExplorerScreen(isMarathi: _isMarathi),
        bottomNavigationBar: _buildBottomNav(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions_bus, color: Colors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _isMarathi ? 'अल्टिमेट PMPL' : 'Ultimate PMPL',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            const Spacer(),
            ActionChip(
              backgroundColor: const Color(0xFF1E293B),
              side: const BorderSide(color: Color(0xFF38BDF8)),
              label: Text(
                _isMarathi ? 'EN' : 'मराठी',
                style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: () {
                setState(() => _isMarathi = !_isMarathi);
              },
            ),
            IconButton(
              icon: const Icon(Icons.mic, color: Color(0xFF38BDF8)),
              tooltip: _isMarathi ? 'बोलून शोधा' : 'Voice Search',
              onPressed: _showVoiceSearchDialog,
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Color(0xFF94A3B8)),
              onPressed: _showSettingsDialog,
              tooltip: 'Server Settings',
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isMarathi ? 'आज तुम्ही कुठे प्रवास करणार आहात?' : 'Where are you travelling today?',
                          style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt, color: Color(0xFF10B981), size: 14),
                            SizedBox(width: 2),
                            Text('Offline Ready', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isMarathi 
                      ? 'थेट GPS स्थान, इच्छित ठिकाणासाठीचे योग्य थांबे, तिकीट दर आणि अलार्म'
                      : 'Live GPS guidance, destination-connected stops, fare calculation & geo-alarm',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const SizedBox(height: 14),

                  // Live Location Hero Button
                  InkWell(
                    onTap: _isLocating ? null : _useCurrentLocation,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0369A1), Color(0xFF0284C7)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: _isLocating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isMarathi ? 'माझे थेट स्थान वापरा (Live GPS)' : 'Use My Current Location',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _isMarathi
                                      ? 'जवळचे बस थांबे शोधा आणि थेट मार्गदर्शन मिळवा'
                                      : 'Find nearest bus stops & get walking guidance',
                                  style: const TextStyle(
                                    color: Color(0xFFE0F2FE),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Search Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildLocationInput(
                          controller: _fromController,
                          label: _isMarathi ? 'येथून (From - Boarding Point)' : 'From (Boarding Point)',
                          icon: Icons.my_location,
                          iconColor: const Color(0xFF10B981),
                          onChanged: (val) => _onTextChanged(val, isOrigin: true),
                          onSubmitted: (val) => _resolveStopCoordinates(val, isOrigin: true),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.gps_fixed, color: Color(0xFF0284C7), size: 20),
                            tooltip: 'Detect My Location',
                            onPressed: _useCurrentLocation,
                          ),
                        ),

                        if (_fromSuggestions.isNotEmpty)
                          _buildSuggestionsList(_fromSuggestions, isOrigin: true),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              Container(width: 2, height: 20, color: const Color(0xFFE2E8F0)),
                              const Spacer(),
                              InkWell(
                                onTap: _swapLocations,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Icon(Icons.swap_vert, size: 18, color: Color(0xFF0284C7)),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ),

                        _buildLocationInput(
                          controller: _toController,
                          label: _isMarathi ? 'येथे (To - Destination)' : 'To (Destination)',
                          icon: Icons.location_on,
                          iconColor: const Color(0xFFEF4444),
                          onChanged: (val) => _onTextChanged(val, isOrigin: false),
                          onSubmitted: (val) => _resolveStopCoordinates(val, isOrigin: false),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.mic, color: Color(0xFF0284C7), size: 20),
                            tooltip: 'बोलून पत्ता सांगा',
                            onPressed: _showVoiceSearchDialog,
                          ),
                        ),

                        if (_toSuggestions.isNotEmpty)
                          _buildSuggestionsList(_toSuggestions, isOrigin: false),

                        const SizedBox(height: 12),

                        // USER'S REQUESTED FEATURE: Show only stops serving destination
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: InkWell(
                            onTap: _isLoadingViableStops ? null : _findViableStopsForDestination,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              child: Row(
                                children: [
                                  if (_isLoadingViableStops)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF15803D)),
                                    )
                                  else
                                    const Icon(Icons.filter_list_alt, color: Color(0xFF15803D), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _isMarathi 
                                            ? '🎯 या ठिकाणासाठीचे जाणारे थेट थांबे शोधा'
                                            : '🎯 Show Boarding Stops Serving Destination',
                                          style: const TextStyle(
                                            color: Color(0xFF15803D),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          _isMarathi
                                            ? 'फक्त तिथून बस उपलब्ध असणारेच थांबे फिल्टर करा'
                                            : 'Only show boarding stops with active buses to this destination',
                                          style: const TextStyle(color: Color(0xFF166534), fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Color(0xFF15803D), size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _findBus,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.directions_bus, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isMarathi ? 'PMPML बस आणि मार्ग शोधा' : 'FIND PMPML BUS & ROUTES',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // PMPML Pass Tip Card (Feature 3)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.confirmation_num, color: Color(0xFFD97706), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isMarathi ? '💡 PMPML ₹५० दैनिक पास (Daily Pass)' : '💡 PMPML ₹50 Unlimited Day Pass',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isMarathi 
                            ? 'दिवसभरात अनेक बसेसने प्रवास करायचा असल्यास ₹५० चा अमर्याद पास घ्या व पैसे वाचवा!'
                            : 'Unlimited rides across Pune (PMC) for ₹50, or PMC+PCMC for ₹120. Huge savings!',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Text(
                _isMarathi ? 'पुण्यातील लोकप्रिय मार्ग (Quick Routes)' : 'Popular Pune Routes',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickChip('Aundhgaon → Dange Chowk', () {
                    _fromController.text = 'Aundhgaon';
                    _toController.text = 'Dange Chowk';
                    _fromLat = 18.5657; _fromLon = 73.8121;
                    _toLat = 18.6186; _toLon = 73.7744;
                  }),
                  _buildQuickChip('Aundhgaon → DY Patil College', () {
                    _fromController.text = 'Aundhgaon';
                    _toController.text = 'DY Patil College Akurdi';
                    _fromLat = 18.5657; _fromLon = 73.8121;
                    _toLat = 18.6466; _toLon = 73.7589;
                  }),
                  _buildQuickChip('Swargate → Pune Station', () {
                    _fromController.text = 'Swargate';
                    _toController.text = 'Pune Station';
                    _fromLat = 18.5018; _fromLon = 73.8585;
                    _toLat = 18.5284; _toLon = 73.8744;
                  }),
                  _buildQuickChip('Shivaji Nagar → Hinjawadi', () {
                    _fromController.text = 'Shivaji Nagar';
                    _toController.text = 'Hinjawadi Maan Phase 3';
                    _fromLat = 18.5314; _fromLon = 73.8446;
                    _toLat = 18.5913; _toLon = 73.6938;
                  }),
                  _buildQuickChip('Katraj → Nigdi', () {
                    _fromController.text = 'Katraj';
                    _toController.text = 'Nigdi Bhakti Shakti';
                    _fromLat = 18.4468; _fromLon = 73.8576;
                    _toLat = 18.6548; _toLon = 73.7667;
                  }),
                  _buildQuickChip('Kothrud Stand → Viman Nagar', () {
                    _fromController.text = 'Kothrud Stand';
                    _toController.text = 'Viman Nagar Corner';
                    _fromLat = 18.5074; _fromLon = 73.8077;
                    _toLat = 18.5679; _toLon = 73.9143;
                  }),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_walk, color: Color(0xFF0284C7), size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _isMarathi
                        ? 'थेट मार्गदर्शन: अॅप तुम्हाला जवळच्या थांब्यापर्यंत चालण्याचा रस्ता, बस बदलण्याची जागा, आणि कुठे उतरायचे ते अचूक सांगेल.'
                        : 'Smart Navigation: Guides you walking to the closest stop, informs which bus to board, alerts where to get off, and explains any transfers step-by-step.',
                      style: const TextStyle(color: Color(0xFF0369A1), fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
    required ValueChanged<String> onSubmitted,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        prefixIcon: Icon(icon, color: iconColor, size: 20),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }

  Widget _buildSuggestionsList(List<StopItem> list, {required bool isOrigin}) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: list.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (ctx, idx) {
          final s = list[idx];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.directions_bus, size: 18, color: Color(0xFF0284C7)),
            title: Text(s.stopName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: s.servingRoutes.isNotEmpty
                ? Text('Buses: ${s.servingRoutes.take(4).join(', ')}', style: const TextStyle(fontSize: 11, color: Colors.grey))
                : null,
            onTap: () {
              setState(() {
                if (isOrigin) {
                  _fromController.text = s.stopName;
                  _fromLat = s.latitude;
                  _fromLon = s.longitude;
                  _fromSuggestions.clear();
                } else {
                  _toController.text = s.stopName;
                  _toLat = s.latitude;
                  _toLon = s.longitude;
                  _toSuggestions.clear();
                }
              });
            },
          );
        },
      ),
    );
  }

  Future<void> _onTextChanged(String text, {required bool isOrigin}) async {
    // Clear stale coordinates if user is modifying the text
    if (isOrigin) {
      _fromLat = 0;
      _fromLon = 0;
    } else {
      _toLat = 0;
      _toLon = 0;
    }

    if (text.trim().length < 2) {
      setState(() {
        if (isOrigin) {
          _fromSuggestions.clear();
        } else {
          _toSuggestions.clear();
        }
      });
      return;
    }

    try {
      final results = await ApiService.searchStops(text);
      if (mounted) {
        setState(() {
          if (isOrigin) {
            _fromSuggestions = results;
          } else {
            _toSuggestions = results;
          }
        });
      }
    } catch (_) {}
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      onPressed: onTap,
    );
  }

  void _swapLocations() {
    setState(() {
      final tmpText = _fromController.text;
      _fromController.text = _toController.text;
      _toController.text = tmpText;

      final tmpLat = _fromLat; final tmpLon = _fromLon;
      _fromLat = _toLat; _fromLon = _toLon;
      _toLat = tmpLat; _toLon = tmpLon;

      _fromSuggestions.clear();
      _toSuggestions.clear();
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _errorMessage = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLocating = false);
        _showAlertDialog(
          title: _isMarathi ? 'स्थान सेवा (GPS) बंद आहे' : 'Location Services Disabled',
          content: _isMarathi 
            ? 'कृपया आपल्या फोनचे स्थान (GPS) चालू करा.' 
            : 'Please enable Location / GPS on your device.',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLocating = false);
          _showSnackBar(_isMarathi ? 'स्थान परवानगी नाकारली गेली.' : 'Location permission denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLocating = false);
        _showAlertDialog(
          title: _isMarathi ? 'स्थान परवानगी आवश्यक आहे' : 'Permission Required',
          content: _isMarathi 
            ? 'स्थान परवानगी कायमस्वरूपी नाकारली गेली आहे. कृपया सेटिंग्जमधून परवानगी द्या.'
            : 'Location permissions are permanently denied. Please enable them in app settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      _fromLat = position.latitude;
      _fromLon = position.longitude;

      // Fetch nearby PMPML stops to user's location
      final nearby = await ApiService.getNearbyStops(position.latitude, position.longitude);

      setState(() {
        _isLocating = false;
        if (nearby.isNotEmpty) {
          _fromController.text = '📍 Live: ${nearby.first.stopName}';
        } else {
          _fromController.text = '📍 My Current Location';
        }
        _fromSuggestions.clear();
      });

      if (nearby.isNotEmpty && mounted) {
        _showNearestStopsBottomSheet(nearby, position.latitude, position.longitude);
      } else {
        _showSnackBar(_isMarathi ? 'जवळचे थेट स्थान सेट केले!' : 'Live GPS location captured!');
      }
    } catch (e) {
      setState(() {
        _isLocating = false;
        _errorMessage = 'Could not get live location: $e';
      });
    }
  }

  void _showNearestStopsBottomSheet(List<StopItem> stops, double userLat, double userLon) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.near_me, color: Color(0xFF0284C7), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isMarathi ? 'तुमच्या जवळचे PMPML बस थांबे' : 'Nearest PMPML Bus Stops to You',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          _isMarathi ? 'प्रवासासाठी इच्छित थांबा निवडा' : 'Select a stop to board from or walk directly',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: ListView.separated(
                  itemCount: stops.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final stop = stops[index];
                    final distMeters = stop.distanceMeters;
                    final walkMinutes = (distMeters / 75.0).ceil();

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFF1F5F9),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                        ),
                      ),
                      title: Text(
                        stop.stopName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.directions_walk, size: 14, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Text(
                                '${distMeters.round()} m away (~$walkMinutes min walk)',
                                style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ],
                          ),
                          if (stop.servingRoutes.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Buses: ${stop.servingRoutes.take(5).join(', ')}',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                      onTap: () {
                        setState(() {
                          _fromController.text = stop.stopName;
                          _fromLat = stop.latitude;
                          _fromLon = stop.longitude;
                        });
                        Navigator.pop(ctx);
                        _showSnackBar(_isMarathi ? 'थांबा निवडला: ${stop.stopName}' : 'Boarding stop set to: ${stop.stopName}');
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.my_location, size: 18),
                  label: Text(_isMarathi ? 'थेट सध्याच्या स्थानावरून शोध घ्या' : 'Search Directly from My Current GPS Spot'),
                  onPressed: () {
                    setState(() {
                      _fromController.text = '📍 Current Location';
                      _fromLat = userLat;
                      _fromLon = userLon;
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _resolveStopCoordinates(String query, {required bool isOrigin}) async {
    if (query.trim().isEmpty) return;
    try {
      final results = await ApiService.searchStops(query);
      if (results.isNotEmpty) {
        final best = results.first;
        setState(() {
          if (isOrigin) {
            _fromController.text = best.stopName;
            _fromLat = best.latitude;
            _fromLon = best.longitude;
            _fromSuggestions.clear();
          } else {
            _toController.text = best.stopName;
            _toLat = best.latitude;
            _toLon = best.longitude;
            _toSuggestions.clear();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _findBus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _fromSuggestions.clear();
      _toSuggestions.clear();
    });

    try {
      final journeys = await ApiService.planJourney(
        originName: _fromController.text.trim(),
        originLat: _fromLat,
        originLon: _fromLon,
        destinationName: _toController.text.trim(),
        destLat: _toLat,
        destLon: _toLon,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => JourneyResultsScreen(
            originName: _fromController.text.trim(),
            destinationName: _toController.text.trim(),
            journeys: journeys,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not connect to Ultimate PMPL server: $e\nMake sure backend is running or check server settings in top right.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAlertDialog({required String title, required String content}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  void _showSettingsDialog() {
    final serverController = TextEditingController(text: ApiService.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend Server Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set the API URL for Ultimate PMPL:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: serverController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                border: OutlineInputBorder(),
                hintText: 'http://localhost:5178 or Render URL',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '• For USB Cable Testing: Keep http://localhost:5178\n• For Render Cloud: https://<your-service>.onrender.com',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                ApiService.baseUrl = serverController.text.trim();
              });
              Navigator.pop(ctx);
              _showSnackBar('Server URL updated to: ${ApiService.baseUrl}');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _navIndex,
      onDestinationSelected: (idx) => setState(() => _navIndex = idx),
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFE0F2FE),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.explore_outlined),
          selectedIcon: const Icon(Icons.explore, color: Color(0xFF0284C7)),
          label: _isMarathi ? 'मार्ग नियोजन' : 'Trip Planner',
        ),
        NavigationDestination(
          icon: const Icon(Icons.departure_board_outlined),
          selectedIcon: const Icon(Icons.departure_board, color: Color(0xFF0284C7)),
          label: _isMarathi ? 'बस वेळापत्रक' : 'Bus Timetable',
        ),
      ],
    );
  }

  Future<void> _findViableStopsForDestination() async {
    final dest = _toController.text.trim();
    if (dest.isEmpty) {
      _showSnackBar(_isMarathi ? 'कृपया आधी गंतव्य स्थान (To) प्रविष्ट करा.' : 'Please enter destination first.');
      return;
    }

    setState(() {
      _isLoadingViableStops = true;
      _errorMessage = null;
    });

    try {
      if (_toLat == 0 || _toLon == 0) {
        final destStops = await ApiService.searchStops(dest);
        if (destStops.isNotEmpty) {
          _toLat = destStops.first.latitude;
          _toLon = destStops.first.longitude;
        } else {
          _toLat = 18.6186;
          _toLon = 73.7744;
        }
      }

      if (_fromLat == 0 || _fromLon == 0) {
        final originStops = await ApiService.searchStops(_fromController.text.trim());
        if (originStops.isNotEmpty) {
          _fromLat = originStops.first.latitude;
          _fromLon = originStops.first.longitude;
        } else {
          _fromLat = 18.5657;
          _fromLon = 73.8121;
        }
      }

      final viable = await ApiService.getViableStops(
        originName: _fromController.text.trim(),
        originLat: _fromLat,
        originLon: _fromLon,
        destinationName: dest,
        destLat: _toLat,
        destLon: _toLon,
      );

      setState(() => _isLoadingViableStops = false);

      if (viable == null || (viable.boardingStops.isEmpty && viable.dropOffStops.isEmpty)) {
        _showAlertDialog(
          title: _isMarathi ? 'थांबे सापडले नाहीत' : 'No Connected Stops Found',
          content: _isMarathi
              ? '$dest साठी थेट किंवा कनेक्टिंग बसेस असलेले जवळचे थांबे आढळले नाहीत. कृपया अंतर तपासा.'
              : 'No stops with direct or connecting buses towards $dest were found near your location. Try picking a nearby main junction.',
        );
        return;
      }

      if (mounted) {
        _showViableStopsBottomSheet(viable);
      }
    } catch (e) {
      setState(() => _isLoadingViableStops = false);
      _showSnackBar('Error loading connected stops: $e');
    }
  }

  void _showViableStopsBottomSheet(ViableStopsData viable) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.alt_route, color: Color(0xFF16A34A), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isMarathi
                                    ? 'फक्त ${viable.destinationName} साठीचे उपलब्ध थांबे'
                                    : 'Stops Serving "${viable.destinationName}"',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _isMarathi
                                    ? 'येथून तुमच्या गंतव्यस्थानासाठी थेट किंवा कनेक्टिंग बसेस धावतात'
                                    : 'Only stops with active direct or connecting buses to your destination',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    labelColor: const Color(0xFF0284C7),
                    unselectedLabelColor: const Color(0xFF64748B),
                    indicatorColor: const Color(0xFF0284C7),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: [
                      Tab(text: _isMarathi ? 'चढण्याचे थांबे (${viable.boardingStops.length})' : 'Boarding Stops (${viable.boardingStops.length})'),
                      Tab(text: _isMarathi ? 'उतरण्याचे थांबे (${viable.dropOffStops.length})' : 'Drop-off Stops (${viable.dropOffStops.length})'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: Boarding Stops
                        viable.boardingStops.isEmpty
                            ? Center(
                                child: Text(
                                  _isMarathi ? 'जवळ कोणतेही थेट थांबे सापडले नाहीत.' : 'No viable boarding stops found nearby.',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: viable.boardingStops.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final b = viable.boardingStops[index];
                                  final hasDirect = b.directBuses.isNotEmpty;

                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: hasDirect ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                                        width: hasDirect ? 1.5 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: hasDirect ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                              child: Text(
                                                '${index + 1}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: hasDirect ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                b.stopName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.directions_walk, size: 14, color: Color(0xFF64748B)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${b.walkDistanceMeters}m • ~${b.walkMinutes} min',
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        // Direct Buses
                                        if (b.directBuses.isNotEmpty) ...[
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF16A34A),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  _isMarathi ? 'थेट बस' : 'DIRECT',
                                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  children: b.directBuses.map((bus) {
                                                    return Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFDCFCE7),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: const Color(0xFF86EFAC)),
                                                      ),
                                                      child: Text(
                                                        bus,
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF15803D)),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                        ],

                                        // Connecting Buses
                                        if (b.connectingBuses.isNotEmpty) ...[
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFD97706),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  _isMarathi ? 'बदला' : 'TRANSFER',
                                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  children: b.connectingBuses.take(4).map((bus) {
                                                    return Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFFEF3C7),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: const Color(0xFFFDE68A)),
                                                      ),
                                                      child: Text(
                                                        bus,
                                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF92400E)),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                        ],

                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Total time: ~${b.bestTotalMinutes} mins',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF0284C7),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _fromController.text = b.stopName;
                                                  _fromLat = b.latitude;
                                                  _fromLon = b.longitude;
                                                });
                                                Navigator.pop(ctx);
                                                _findBus();
                                              },
                                              child: Text(
                                                _isMarathi ? 'येथून चढा आणि जा' : 'Board Here & Plan',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                        // Tab 2: Drop-off Stops
                        viable.dropOffStops.isEmpty
                            ? Center(
                                child: Text(
                                  _isMarathi ? 'उतरण्याचे थांबे सापडले नाहीत.' : 'No drop-off stops found.',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: viable.dropOffStops.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final d = viable.dropOffStops[index];
                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEE2E2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                d.stopName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${d.walkToDestMeters}m walk to destination',
                                                style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                              if (d.arrivingBuses.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Arriving Buses: ${d.arrivingBuses.join(', ')}',
                                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _toController.text = d.stopName;
                                              _toLat = d.latitude;
                                              _toLon = d.longitude;
                                            });
                                            Navigator.pop(ctx);
                                          },
                                          child: Text(
                                            _isMarathi ? 'निवडा' : 'Select',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showVoiceSearchDialog() {
    final quickVoiceRoutes = [
      {'label': 'औंधगाव → डांगे चौक (Aundhgaon → Dange Chowk)', 'from': 'Aundhgaon', 'to': 'Dange Chowk', 'flat': 18.5657, 'flon': 73.8121, 'tlat': 18.6186, 'tlon': 73.7744},
      {'label': 'स्वारगेट → पुणे स्टेशन (Swargate → Pune Station)', 'from': 'Swargate', 'to': 'Pune Station', 'flat': 18.5018, 'flon': 73.8585, 'tlat': 18.5284, 'tlon': 73.8744},
      {'label': 'शिवाजी नगर → हिंजवडी फेज ३ (Shivaji Nagar → Hinjawadi)', 'from': 'Shivaji Nagar', 'to': 'Hinjawadi Maan Phase 3', 'flat': 18.5314, 'flon': 73.8446, 'tlat': 18.5913, 'tlon': 73.6938},
      {'label': 'कात्रज → निगडी भक्ती शक्ती (Katraj → Nigdi)', 'from': 'Katraj', 'to': 'Nigdi Bhakti Shakti', 'flat': 18.4468, 'flon': 73.8576, 'tlat': 18.6548, 'tlon': 73.7667},
      {'label': 'कोथरूड स्टँड → विमान नगर (Kothrud → Viman Nagar)', 'from': 'Kothrud Stand', 'to': 'Viman Nagar Corner', 'flat': 18.5074, 'flon': 73.8077, 'tlat': 18.5679, 'tlon': 73.9143},
      {'label': 'औंधगाव → DY पाटील कॉलेज (Aundhgaon → DY Patil Akurdi)', 'from': 'Aundhgaon', 'to': 'DY Patil College Akurdi', 'flat': 18.5657, 'flon': 73.8121, 'tlat': 18.6466, 'tlon': 73.7589},
      {'label': 'हडपसर गाडीतळ → पुणे स्टेशन (Hadapsar → Station)', 'from': 'Hadapsar Gadital', 'to': 'Pune Station', 'flat': 18.5089, 'flon': 73.9260, 'tlat': 18.5284, 'tlon': 73.8744},
      {'label': 'बाणेर → स्वारगेट (Baner → Swargate)', 'from': 'Baner Gaon', 'to': 'Swargate', 'flat': 18.5590, 'flon': 73.7868, 'tlat': 18.5018, 'tlon': 73.8585},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2FE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic, color: Color(0xFF0284C7), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isMarathi ? 'बोलून बस शोधा' : 'Voice Bus Search',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  Text(
                    _isMarathi ? 'मराठी किंवा इंग्रजीत मार्ग निवडा' : 'Tap spoken shortcut or speak your destination',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.record_voice_over, color: Color(0xFF0284C7), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isMarathi ? '"मला स्वारगेटला जायचे आहे" किंवा खालील मार्ग टॅप करा' : 'Listening... Tap any common spoken route below:',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: quickVoiceRoutes.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = quickVoiceRoutes[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: const Icon(Icons.directions_bus, size: 18, color: Color(0xFF0284C7)),
                      title: Text(item['label'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onTap: () {
                        setState(() {
                          _fromController.text = item['from'] as String;
                          _toController.text = item['to'] as String;
                          _fromLat = item['flat'] as double;
                          _fromLon = item['flon'] as double;
                          _toLat = item['tlat'] as double;
                          _toLon = item['tlon'] as double;
                          _fromSuggestions.clear();
                          _toSuggestions.clear();
                        });
                        Navigator.pop(ctx);
                        _findBus();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_isMarathi ? 'बंद करा' : 'Close'),
          ),
        ],
      ),
    );
  }
}
