import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/journey_models.dart';

class ApiService {
  // ✅ Live Render Cloud Backend (no localhost needed!)
  static String baseUrl = "https://citybus-app.onrender.com";

  static Future<List<JourneyOption>> planJourney({
    required String originName,
    required double originLat,
    required double originLon,
    required String destinationName,
    required double destLat,
    required double destLon,
  }) async {
    final url = Uri.parse('$baseUrl/api/v1/journeys/plan');
    final payload = {
      'origin': {
        'name': originName,
        'latitude': originLat,
        'longitude': originLon,
      },
      'destination': {
        'name': destinationName,
        'latitude': destLat,
        'longitude': destLon,
      },
      'departureTime': DateTime.now().toIso8601String(),
      'maxWalkDistanceMeters': 900,
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = (data['journeys'] as List<dynamic>?)
              ?.map((e) => JourneyOption.fromJson(e))
              .toList() ??
          [];
      return list;
    } else {
      throw Exception('Server returned error: ${response.statusCode}');
    }
  }

  static Future<List<StopItem>> searchStops(String query) async {
    if (query.trim().isEmpty) return [];
    final url = Uri.parse('$baseUrl/api/v1/stops/search?q=${Uri.encodeComponent(query)}&limit=10');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final list = (jsonDecode(response.body) as List<dynamic>?)
              ?.map((e) => StopItem.fromJson(e))
              .toList() ??
          [];
      return list;
    }
    return [];
  }

  static Future<List<StopItem>> getNearbyStops(double lat, double lon) async {
    final url = Uri.parse('$baseUrl/api/v1/stops/nearby?lat=$lat&lon=$lon&radius=1000');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final list = (jsonDecode(response.body) as List<dynamic>?)
              ?.map((e) => StopItem.fromJson(e))
              .toList() ??
          [];
      return list;
    }
    return [];
  }

  static final Map<String, dynamic> _offlineCache = {};

  static Future<ViableStopsData?> getViableStops({
    required String originName,
    required double originLat,
    required double originLon,
    required String destinationName,
    required double destLat,
    required double destLon,
  }) async {
    final url = Uri.parse('$baseUrl/api/v1/journeys/viable-stops');
    final payload = {
      'origin': {
        'name': originName,
        'latitude': originLat,
        'longitude': originLon,
      },
      'destination': {
        'name': destinationName,
        'latitude': destLat,
        'longitude': destLon,
      },
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ViableStopsData.fromJson(data, destinationName: destinationName);
      }
    } catch (_) {}
    return null;
  }

  static Future<List<RouteListItem>> getRoutes({String? query}) async {
    final cacheKey = 'routes_${query ?? ''}';
    final qParam = query != null && query.isNotEmpty ? '?q=${Uri.encodeComponent(query)}' : '';
    final url = Uri.parse('$baseUrl/api/v1/routes$qParam');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final list = (jsonDecode(response.body) as List<dynamic>?)
                ?.map((e) => RouteListItem.fromJson(e))
                .toList() ??
            [];
        _offlineCache[cacheKey] = list;
        return list;
      }
    } catch (_) {
      if (_offlineCache.containsKey(cacheKey)) {
        return _offlineCache[cacheKey] as List<RouteListItem>;
      }
    }
    return [];
  }

  static Future<RouteDetails?> getRouteDetails(String routeId) async {
    final cacheKey = 'route_details_$routeId';
    final url = Uri.parse('$baseUrl/api/v1/routes/${Uri.encodeComponent(routeId)}');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final details = RouteDetails.fromJson(data);
        _offlineCache[cacheKey] = details;
        return details;
      }
    } catch (_) {
      if (_offlineCache.containsKey(cacheKey)) {
        return _offlineCache[cacheKey] as RouteDetails;
      }
    }
    return null;
  }
}

