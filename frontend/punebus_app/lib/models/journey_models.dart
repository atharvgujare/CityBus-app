class LocationPoint {
  final String name;
  final double latitude;
  final double longitude;

  LocationPoint({required this.name, required this.latitude, required this.longitude});

  Map<String, dynamic> toJson() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory LocationPoint.fromJson(Map<String, dynamic> json) => LocationPoint(
    name: json['name'] ?? '',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
  );
}

class CoordinatesPoint {
  final double latitude;
  final double longitude;

  CoordinatesPoint({required this.latitude, required this.longitude});

  factory CoordinatesPoint.fromJson(Map<String, dynamic> json) => CoordinatesPoint(
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
  );
}

class JourneyLeg {
  final String type; // WALK, BUS, TRANSFER_WALK
  final String instruction;
  final int distanceMeters;
  final int durationMinutes;
  final String? routeNumber;
  final String? routeLongName;
  final String? boardStop;
  final String? scheduledDeparture;
  final String? getOffStop;
  final String? scheduledArrival;
  final int? intermediateStopsCount;
  final List<String> intermediateStops;
  final List<String> alternateBuses;
  final List<String> nextDepartures;
  final String? firstBusTime;
  final String? lastBusTime;
  final int estimatedFareRupees;
  final String? fromName;
  final String? toName;
  final List<CoordinatesPoint> pathCoordinates;

  JourneyLeg({
    required this.type,
    required this.instruction,
    required this.distanceMeters,
    required this.durationMinutes,
    this.routeNumber,
    this.routeLongName,
    this.boardStop,
    this.scheduledDeparture,
    this.getOffStop,
    this.scheduledArrival,
    this.intermediateStopsCount,
    this.intermediateStops = const [],
    this.alternateBuses = const [],
    this.nextDepartures = const [],
    this.firstBusTime,
    this.lastBusTime,
    this.estimatedFareRupees = 5,
    this.fromName,
    this.toName,
    this.pathCoordinates = const [],
  });

  factory JourneyLeg.fromJson(Map<String, dynamic> json) => JourneyLeg(
    type: json['type'] ?? 'BUS',
    instruction: json['instruction'] ?? '',
    distanceMeters: json['distanceMeters'] ?? 0,
    durationMinutes: json['durationMinutes'] ?? 0,
    routeNumber: json['routeNumber'],
    routeLongName: json['routeLongName'],
    boardStop: json['boardStop'],
    scheduledDeparture: json['scheduledDeparture'],
    getOffStop: json['getOffStop'],
    scheduledArrival: json['scheduledArrival'],
    intermediateStopsCount: json['intermediateStopsCount'],
    intermediateStops: (json['intermediateStops'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    alternateBuses: (json['alternateBuses'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    nextDepartures: (json['nextDepartures'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    firstBusTime: json['firstBusTime'],
    lastBusTime: json['lastBusTime'],
    estimatedFareRupees: json['estimatedFareRupees'] ?? 5,
    fromName: json['fromName'],
    toName: json['toName'],
    pathCoordinates: (json['pathCoordinates'] as List<dynamic>?)?.map((e) => CoordinatesPoint.fromJson(e)).toList() ?? [],
  );
}

class JourneyOption {
  final String journeyId;
  final String category; // FASTEST, LEAST_WALKING, FEWEST_TRANSFERS, SIMPLEST
  final String summary;
  final int totalDurationMinutes;
  final int totalWalkingMeters;
  final int totalWaitMinutes;
  final int transferCount;
  final int totalFareRupees;
  final String? dailyPassTip;
  final List<JourneyLeg> legs;
  final List<CoordinatesPoint> mapPolyline;

  JourneyOption({
    required this.journeyId,
    required this.category,
    required this.summary,
    required this.totalDurationMinutes,
    required this.totalWalkingMeters,
    required this.totalWaitMinutes,
    required this.transferCount,
    required this.totalFareRupees,
    this.dailyPassTip,
    required this.legs,
    this.mapPolyline = const [],
  });

  factory JourneyOption.fromJson(Map<String, dynamic> json) => JourneyOption(
    journeyId: json['journeyId'] ?? '',
    category: json['category'] ?? 'FASTEST',
    summary: json['summary'] ?? '',
    totalDurationMinutes: json['totalDurationMinutes'] ?? 0,
    totalWalkingMeters: json['totalWalkingMeters'] ?? 0,
    totalWaitMinutes: json['totalWaitMinutes'] ?? 0,
    transferCount: json['transferCount'] ?? 0,
    totalFareRupees: json['totalFareRupees'] ?? 10,
    dailyPassTip: json['dailyPassTip'],
    legs: (json['legs'] as List<dynamic>?)
            ?.map((e) => JourneyLeg.fromJson(e))
            .toList() ??
        [],
    mapPolyline: (json['mapPolyline'] as List<dynamic>?)
            ?.map((e) => CoordinatesPoint.fromJson(e))
            .toList() ??
        [],
  );
}

class StopItem {
  final String stopId;
  final String stopName;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final List<String> servingRoutes;

  StopItem({
    required this.stopId,
    required this.stopName,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.servingRoutes,
  });

  factory StopItem.fromJson(Map<String, dynamic> json) => StopItem(
    stopId: json['stopId'] ?? '',
    stopName: json['stopName'] ?? '',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
    servingRoutes: (json['servingRoutes'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
  );
}

class ViableBoardingStop {
  final String stopId;
  final String stopName;
  final double latitude;
  final double longitude;
  final double walkDistanceMeters;
  final int walkMinutes;
  final List<String> directBuses;
  final List<String> connectingBuses;
  final int bestTotalMinutes;

  ViableBoardingStop({
    required this.stopId,
    required this.stopName,
    required this.latitude,
    required this.longitude,
    required this.walkDistanceMeters,
    required this.walkMinutes,
    required this.directBuses,
    required this.connectingBuses,
    required this.bestTotalMinutes,
  });

  factory ViableBoardingStop.fromJson(Map<String, dynamic> json) => ViableBoardingStop(
    stopId: json['stopId'] ?? '',
    stopName: json['stopName'] ?? '',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    walkDistanceMeters: (json['walkDistanceMeters'] as num?)?.toDouble() ?? 0.0,
    walkMinutes: json['walkMinutes'] ?? 0,
    directBuses: (json['directBuses'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    connectingBuses: (json['connectingBuses'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    bestTotalMinutes: json['bestTotalMinutes'] ?? 0,
  );
}

class ViableDropOffStop {
  final String stopId;
  final String stopName;
  final double latitude;
  final double longitude;
  final double walkToDestMeters;
  final int walkMinutes;
  final List<String> arrivingBuses;

  ViableDropOffStop({
    required this.stopId,
    required this.stopName,
    required this.latitude,
    required this.longitude,
    required this.walkToDestMeters,
    required this.walkMinutes,
    required this.arrivingBuses,
  });

  factory ViableDropOffStop.fromJson(Map<String, dynamic> json) => ViableDropOffStop(
    stopId: json['stopId'] ?? '',
    stopName: json['stopName'] ?? '',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    walkToDestMeters: (json['walkToDestMeters'] as num?)?.toDouble() ?? 0.0,
    walkMinutes: json['walkMinutes'] ?? 0,
    arrivingBuses: (json['arrivingBuses'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
  );
}

class ViableStopsData {
  final String destinationName;
  final List<ViableBoardingStop> boardingStops;
  final List<ViableDropOffStop> dropOffStops;

  ViableStopsData({
    this.destinationName = '',
    required this.boardingStops,
    required this.dropOffStops,
  });

  factory ViableStopsData.fromJson(Map<String, dynamic> json, {String destinationName = ''}) => ViableStopsData(
    destinationName: json['destinationName'] ?? destinationName,
    boardingStops: (json['boardingStops'] as List<dynamic>?)
            ?.map((e) => ViableBoardingStop.fromJson(e))
            .toList() ??
        [],
    dropOffStops: (json['dropOffStops'] as List<dynamic>?)
            ?.map((e) => ViableDropOffStop.fromJson(e))
            .toList() ??
        [],
  );
}

class RouteListItem {
  final String routeId;
  final String routeShortName;
  final String routeLongName;
  final int totalStops;
  final String? firstStop;
  final String? lastStop;

  RouteListItem({
    required this.routeId,
    required this.routeShortName,
    required this.routeLongName,
    required this.totalStops,
    this.firstStop,
    this.lastStop,
  });

  factory RouteListItem.fromJson(Map<String, dynamic> json) => RouteListItem(
    routeId: json['routeId'] ?? '',
    routeShortName: json['routeShortName'] ?? '',
    routeLongName: json['routeLongName'] ?? '',
    totalStops: json['totalStops'] ?? 0,
    firstStop: json['firstStop'],
    lastStop: json['lastStop'],
  );
}

class RouteDetails extends RouteListItem {
  final List<StopItem> stops;
  final List<String> timetable;
  final String? returnRouteId;
  final String? returnRouteName;

  RouteDetails({
    required super.routeId,
    required super.routeShortName,
    required super.routeLongName,
    required super.totalStops,
    super.firstStop,
    super.lastStop,
    required this.stops,
    required this.timetable,
    this.returnRouteId,
    this.returnRouteName,
  });

  factory RouteDetails.fromJson(Map<String, dynamic> json) => RouteDetails(
    routeId: json['routeId'] ?? '',
    routeShortName: json['routeShortName'] ?? '',
    routeLongName: json['routeLongName'] ?? '',
    totalStops: json['totalStops'] ?? 0,
    firstStop: json['firstStop'],
    lastStop: json['lastStop'],
    stops: (json['stops'] as List<dynamic>?)?.map((e) => StopItem.fromJson(e)).toList() ?? [],
    timetable: (json['timetable'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    returnRouteId: json['returnRouteId'],
    returnRouteName: json['returnRouteName'],
  );
}

