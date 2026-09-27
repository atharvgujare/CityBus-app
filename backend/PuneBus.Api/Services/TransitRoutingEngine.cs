using System.Globalization;
using Microsoft.EntityFrameworkCore;
using PuneBus.Api.Data;
using PuneBus.Api.Data.Entities;
using PuneBus.Api.Models.Dtos;

namespace PuneBus.Api.Services;

public interface ITransitRoutingEngine
{
    Task InitializeAsync(CancellationToken cancellationToken = default);
    Task<JourneyPlanResponse> PlanJourneyAsync(JourneyPlanRequest request, CancellationToken cancellationToken = default);
    Task<ViableStopsResponse> GetViableStopsAsync(JourneyPlanRequest request, CancellationToken cancellationToken = default);
    Task<List<StopDto>> GetNearbyStopsAsync(double latitude, double longitude, double radiusMeters = 800);
    Task<List<StopDto>> SearchStopsAsync(string query, int limit = 15);
    Task<List<RouteDto>> GetRoutesAsync(string? query = null, int limit = 20);
    Task<RouteDetailsDto?> GetRouteDetailsAsync(string routeId);
}

public class TransitRoutingEngine : ITransitRoutingEngine
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<TransitRoutingEngine> _logger;

    // In-memory cache structures
    private readonly Dictionary<string, StopEntity> _stops = new();
    private readonly Dictionary<string, RouteEntity> _routes = new();
    private readonly Dictionary<string, List<string>> _stopToRoutes = new(); // StopId -> RouteIds
    private readonly Dictionary<string, List<string>> _routeToStops = new();  // RouteId -> ordered StopIds
    private readonly Dictionary<string, List<(string ToStopId, int DistMeters, int DurSec)>> _footpaths = new();
    private readonly Dictionary<string, List<StopTimeSchedule>> _routeSchedules = new();
    private bool _isInitialized = false;
    private readonly SemaphoreSlim _initLock = new(1, 1);

    public record StopTimeSchedule(int Sequence, string StopId, TimeSpan DepartureTime);

    public TransitRoutingEngine(IServiceProvider serviceProvider, ILogger<TransitRoutingEngine> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        if (_isInitialized) return;
        await _initLock.WaitAsync(cancellationToken);
        try
        {
            if (_isInitialized) return;
            _logger.LogInformation("Initializing In-Memory Transit Routing Graph...");
            using var scope = _serviceProvider.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<PuneBusDbContext>();

            // 1. Load Stops
            var allStops = await db.Stops.AsNoTracking().ToListAsync(cancellationToken);
            foreach (var s in allStops)
            {
                _stops[s.StopId] = s;
                _stopToRoutes[s.StopId] = new List<string>();
            }

            // 2. Load Routes
            var allRoutes = await db.Routes.AsNoTracking().ToListAsync(cancellationToken);
            foreach (var r in allRoutes)
            {
                _routes[r.RouteId] = r;
            }

            // 3. Load Trips with StopTimes (representative trip per route)
            var trips = await db.Trips.AsNoTracking().ToListAsync(cancellationToken);
            var representativeTrips = trips.GroupBy(t => t.RouteId).ToDictionary(g => g.Key, g => g.First().TripId);

            var repTripIds = representativeTrips.Values.ToHashSet();
            var stopTimes = await db.StopTimes.AsNoTracking()
                                    .Where(st => repTripIds.Contains(st.TripId))
                                    .OrderBy(st => st.TripId)
                                    .ThenBy(st => st.StopSequence)
                                    .ToListAsync(cancellationToken);

            var tripStopGroups = stopTimes.GroupBy(st => st.TripId);
            foreach (var group in tripStopGroups)
            {
                var tripId = group.Key;
                var routeId = trips.First(t => t.TripId == tripId).RouteId;
                var orderedStops = group.OrderBy(g => g.StopSequence).Select(g => g.StopId).ToList();
                _routeToStops[routeId] = orderedStops;

                var schedules = group.OrderBy(g => g.StopSequence)
                                     .Select(g => new StopTimeSchedule(
                                         g.StopSequence,
                                         g.StopId,
                                         TimeSpan.TryParse(g.DepartureTime, out var ts) ? ts : TimeSpan.FromHours(8)))
                                     .ToList();
                _routeSchedules[routeId] = schedules;

                foreach (var stopId in orderedStops)
                {
                    if (_stopToRoutes.TryGetValue(stopId, out var rList))
                    {
                        if (!rList.Contains(routeId)) rList.Add(routeId);
                    }
                }
            }

            // 4. Load Footpaths
            var footpaths = await db.Footpaths.AsNoTracking().ToListAsync(cancellationToken);
            foreach (var fp in footpaths)
            {
                if (!_footpaths.ContainsKey(fp.FromStopId)) _footpaths[fp.FromStopId] = new();
                _footpaths[fp.FromStopId].Add((fp.ToStopId, fp.WalkingDistanceMeters, fp.WalkingDurationSeconds));
            }

            _isInitialized = true;
            _logger.LogInformation("Transit Routing Graph loaded: {Stops} stops, {Routes} routes.", _stops.Count, _routes.Count);
        }
        finally
        {
            _initLock.Release();
        }
    }

    public async Task<List<StopDto>> GetNearbyStopsAsync(double latitude, double longitude, double radiusMeters = 800)
    {
        if (!_isInitialized) await InitializeAsync();

        // 1. Initial filter within aerial reach
        var initialCandidates = _stops.Values
            .Select(s => new
            {
                Stop = s,
                AirDist = CalculateDistanceMeters(latitude, longitude, s.Latitude, s.Longitude)
            })
            .Where(x => x.AirDist <= Math.Max(radiusMeters * 2.5, 2500))
            .OrderBy(x => x.AirDist)
            .Take(25)
            .Select(x => x.Stop)
            .ToList();

        // 2. Real street walking distances (OSRM + River barrier fallback)
        var realDistances = await GetRealStreetWalkingDistancesAsync(latitude, longitude, initialCandidates);

        return initialCandidates
            .Select(s => new
            {
                Stop = s,
                RealDist = realDistances.TryGetValue(s.StopId, out var d) ? d : CalculateDistanceMeters(latitude, longitude, s.Latitude, s.Longitude)
            })
            .OrderBy(x => x.RealDist)
            .Take(15)
            .Select(x => new StopDto
            {
                StopId = x.Stop.StopId,
                StopName = x.Stop.StopName,
                Latitude = x.Stop.Latitude,
                Longitude = x.Stop.Longitude,
                DistanceMeters = Math.Round(x.RealDist, 0),
                ServingRoutes = _stopToRoutes.TryGetValue(x.Stop.StopId, out var rList)
                    ? rList.Select(rid => _routes.TryGetValue(rid, out var r) ? r.RouteShortName : rid).Distinct().Take(8).ToList()
                    : new()
            })
            .ToList();
    }

    public async Task<List<StopDto>> SearchStopsAsync(string query, int limit = 15)
    {
        if (!_isInitialized) await InitializeAsync();
        if (string.IsNullOrWhiteSpace(query)) return new();

        var q = query.Trim().ToLowerInvariant();
        var direct = _stops.Values
            .Where(s => s.StopName.ToLowerInvariant().Contains(q) || s.NormalizedName.Contains(q))
            .Take(limit)
            .ToList();

        if (direct.Count > 0)
        {
            return direct.Select(MapToStopDto).ToList();
        }

        // Multi-token fallback (e.g., "DY Patil Talegaon", "dr. D.Y. patil Institute of Management... Talegaon")
        var noise = new HashSet<string>(StringComparer.OrdinalIgnoreCase) 
            { "dr", "the", "near", "opp", "opposite", "chowk", "road", "institute", "of", "and", "for", "development", "entrepreneur", "management", "college", "collage" };
        var rawTokens = System.Text.RegularExpressions.Regex.Matches(q, @"[a-z0-9]+")
            .Select(m => m.Value)
            .ToList();
        
        var tokens = rawTokens.Where(t => !noise.Contains(t) && t.Length > 1).ToList();
        if (rawTokens.Contains("d") && rawTokens.Contains("y") && !tokens.Contains("dy"))
        {
            tokens.Add("dy");
        }

        if (tokens.Count == 0) return new();

        var scored = _stops.Values
            .Select(s =>
            {
                var sLower = s.StopName.ToLowerInvariant();
                int score = tokens.Count(t => sLower.Contains(t));
                return (Stop: s, Score: score);
            })
            .Where(x => x.Score > 0)
            .OrderByDescending(x => x.Score)
            .Take(limit)
            .Select(x => x.Stop)
            .ToList();

        return scored.Select(MapToStopDto).ToList();
    }

    private StopDto MapToStopDto(StopEntity s) => new StopDto
    {
        StopId = s.StopId,
        StopName = s.StopName,
        Latitude = s.Latitude,
        Longitude = s.Longitude,
        ServingRoutes = _stopToRoutes.TryGetValue(s.StopId, out var rList)
            ? rList.Select(rid => _routes.TryGetValue(rid, out var r) ? r.RouteShortName : rid).Distinct().Take(8).ToList()
            : new()
    };

    public async Task<List<RouteDto>> GetRoutesAsync(string? query = null, int limit = 20)
    {
        if (!_isInitialized) await InitializeAsync();

        var q = _routes.Values.AsEnumerable();
        if (!string.IsNullOrWhiteSpace(query))
        {
            var match = query.Trim().ToLowerInvariant();
            q = q.Where(r => r.RouteShortName.ToLowerInvariant().Contains(match) || r.RouteLongName.ToLowerInvariant().Contains(match));
        }

        return q.Take(limit).Select(r =>
        {
            var stops = _routeToStops.TryGetValue(r.RouteId, out var sList) ? sList : new List<string>();
            return new RouteDto
            {
                RouteId = r.RouteId,
                RouteShortName = r.RouteShortName,
                RouteLongName = r.RouteLongName,
                TotalStops = stops.Count,
                FirstStop = stops.Count > 0 && _stops.TryGetValue(stops[0], out var first) ? first.StopName : null,
                LastStop = stops.Count > 0 && _stops.TryGetValue(stops[^1], out var last) ? last.StopName : null
            };
        }).ToList();
    }

    public async Task<RouteDetailsDto?> GetRouteDetailsAsync(string routeId)
    {
        if (!_isInitialized) await InitializeAsync();

        if (!_routes.TryGetValue(routeId, out var route))
        {
            var match = _routes.Values.FirstOrDefault(r => r.RouteShortName.Equals(routeId, StringComparison.OrdinalIgnoreCase));
            if (match == null) return null;
            route = match;
            routeId = route.RouteId;
        }

        var stopsList = _routeToStops.TryGetValue(routeId, out var sList) ? sList : new List<string>();
        var stops = stopsList
            .Where(sid => _stops.ContainsKey(sid))
            .Select(sid => MapToStopDto(_stops[sid]))
            .ToList();

        var timetable = new List<string>
        {
            "06:00 AM", "06:30 AM", "07:00 AM", "07:30 AM", "08:00 AM", "08:30 AM",
            "09:00 AM", "09:30 AM", "10:00 AM", "10:45 AM", "11:30 AM", "12:15 PM",
            "01:00 PM", "01:45 PM", "02:30 PM", "03:15 PM", "04:00 PM", "04:30 PM",
            "05:00 PM", "05:30 PM", "06:00 PM", "06:30 PM", "07:00 PM", "07:30 PM",
            "08:00 PM", "08:30 PM", "09:15 PM", "10:00 PM"
        };

        var opposite = _routes.Values.FirstOrDefault(r => 
            r.RouteShortName.Equals(route.RouteShortName, StringComparison.OrdinalIgnoreCase) && 
            r.RouteId != route.RouteId);

        return new RouteDetailsDto
        {
            RouteId = route.RouteId,
            RouteShortName = route.RouteShortName,
            RouteLongName = route.RouteLongName,
            TotalStops = stops.Count,
            FirstStop = stops.Count > 0 ? stops[0].StopName : null,
            LastStop = stops.Count > 0 ? stops[^1].StopName : null,
            Stops = stops,
            Timetable = timetable,
            ReturnRouteId = opposite?.RouteId,
            ReturnRouteName = opposite?.RouteLongName
        };
    }


    public async Task<JourneyPlanResponse> PlanJourneyAsync(JourneyPlanRequest request, CancellationToken cancellationToken = default)
    {
        if (!_isInitialized) await InitializeAsync(cancellationToken);

        var response = new JourneyPlanResponse
        {
            Origin = request.Origin,
            Destination = request.Destination
        };

        var originStops = await ResolveCandidateStopsAsync(request.Origin, request.MaxWalkDistanceMeters);
        var destStops = await ResolveCandidateStopsAsync(request.Destination, request.MaxWalkDistanceMeters);

        if (originStops.Count == 0 || destStops.Count == 0)
        {
            _logger.LogWarning("No candidate stops found near origin or destination.");
            return response;
        }

        var candidateJourneys = new List<JourneyOptionDto>();

        // 1. Direct Routes (0 Transfers)
        candidateJourneys.AddRange(FindDirectJourneys(originStops, destStops, request));

        // 2. One-Transfer Routes (1 Transfer)
        candidateJourneys.AddRange(FindTransferJourneys(originStops, destStops, request));

        if (candidateJourneys.Count == 0)
        {
            var expandedOriginStops = await ResolveCandidateStopsAsync(request.Origin, request.MaxWalkDistanceMeters * 2);
            var expandedDestStops = await ResolveCandidateStopsAsync(request.Destination, request.MaxWalkDistanceMeters * 2);
            candidateJourneys.AddRange(FindTransferJourneys(expandedOriginStops, expandedDestStops, request));
        }

        // Deduplicate & Classify
        var distinctJourneys = candidateJourneys
            .GroupBy(j => j.Summary)
            .Select(g => g.OrderBy(j => j.TotalDurationMinutes).First())
            .ToList();

        if (distinctJourneys.Count > 0)
        {
            // 1. Fastest
            var fastest = distinctJourneys.OrderBy(j => j.TotalDurationMinutes).First();
            fastest.Category = "FASTEST";
            response.Journeys.Add(fastest);

            // 2. Least Walking
            var leastWalking = distinctJourneys
                .Where(j => j.JourneyId != fastest.JourneyId)
                .OrderBy(j => j.TotalWalkingMeters)
                .FirstOrDefault();
            if (leastWalking != null)
            {
                leastWalking.Category = "LEAST_WALKING";
                response.Journeys.Add(leastWalking);
            }

            // 3. Fewest Transfers
            var fewestTransfers = distinctJourneys
                .Where(j => response.Journeys.All(x => x.JourneyId != j.JourneyId))
                .OrderBy(j => j.TransferCount)
                .ThenBy(j => j.TotalDurationMinutes)
                .FirstOrDefault();
            if (fewestTransfers != null)
            {
                fewestTransfers.Category = "FEWEST_TRANSFERS";
                response.Journeys.Add(fewestTransfers);
            }

            // 4. Simplest / Alternative
            var alternative = distinctJourneys
                .Where(j => response.Journeys.All(x => x.JourneyId != j.JourneyId))
                .OrderBy(j => j.TotalWaitMinutes)
                .FirstOrDefault();
            if (alternative != null)
            {
                alternative.Category = "SIMPLEST";
                response.Journeys.Add(alternative);
            }

            foreach (var j in response.Journeys)
            {
                if (j.TotalFareRupees >= 25)
                {
                    j.DailyPassTip = "💡 PMPML ₹50 Daily Pass (एकदिवसीय पास) gives unlimited travel across Pune & PCMC today!";
                }
            }
        }

        return response;
    }

    public async Task<ViableStopsResponse> GetViableStopsAsync(JourneyPlanRequest request, CancellationToken cancellationToken = default)
    {
        if (!_isInitialized) await InitializeAsync(cancellationToken);

        var response = new ViableStopsResponse();
        var journeys = await PlanJourneyAsync(request, cancellationToken);
        if (journeys.Journeys.Count == 0) return response;

        var boardingMap = new Dictionary<string, ViableBoardingStopDto>();
        var dropOffMap = new Dictionary<string, ViableDropOffStopDto>();

        foreach (var j in journeys.Journeys)
        {
            var firstBusLeg = j.Legs.FirstOrDefault(l => l.Type == "BUS");
            if (firstBusLeg != null && !string.IsNullOrEmpty(firstBusLeg.BoardStop))
            {
                var stopName = firstBusLeg.BoardStop;
                if (!boardingMap.TryGetValue(stopName, out var bDto))
                {
                    var coords = firstBusLeg.BoardStopCoords;
                    var walkLeg = j.Legs.FirstOrDefault(l => l.Type == "WALK");
                    bDto = new ViableBoardingStopDto
                    {
                        StopName = stopName,
                        Latitude = coords?.Latitude ?? 0,
                        Longitude = coords?.Longitude ?? 0,
                        WalkDistanceMeters = walkLeg?.DistanceMeters ?? 0,
                        WalkMinutes = walkLeg?.DurationMinutes ?? 0,
                        BestTotalMinutes = j.TotalDurationMinutes
                    };
                    boardingMap[stopName] = bDto;
                }

                if (j.TransferCount == 0)
                {
                    if (!string.IsNullOrEmpty(firstBusLeg.RouteNumber) && !bDto.DirectBuses.Contains(firstBusLeg.RouteNumber))
                        bDto.DirectBuses.Add(firstBusLeg.RouteNumber);
                }
                else
                {
                    if (!string.IsNullOrEmpty(firstBusLeg.RouteNumber) && !bDto.ConnectingBuses.Contains(firstBusLeg.RouteNumber))
                        bDto.ConnectingBuses.Add(firstBusLeg.RouteNumber);
                }

                if (j.TotalDurationMinutes < bDto.BestTotalMinutes)
                {
                    bDto.BestTotalMinutes = j.TotalDurationMinutes;
                }
            }

            var lastBusLeg = j.Legs.LastOrDefault(l => l.Type == "BUS");
            if (lastBusLeg != null && !string.IsNullOrEmpty(lastBusLeg.GetOffStop))
            {
                var stopName = lastBusLeg.GetOffStop;
                if (!dropOffMap.TryGetValue(stopName, out var dDto))
                {
                    var coords = lastBusLeg.GetOffStopCoords;
                    var finalWalk = j.Legs.LastOrDefault(l => l.Type == "WALK");
                    dDto = new ViableDropOffStopDto
                    {
                        StopName = stopName,
                        Latitude = coords?.Latitude ?? 0,
                        Longitude = coords?.Longitude ?? 0,
                        WalkToDestMeters = finalWalk?.DistanceMeters ?? 0,
                        WalkMinutes = finalWalk?.DurationMinutes ?? 0
                    };
                    dropOffMap[stopName] = dDto;
                }

                if (!string.IsNullOrEmpty(lastBusLeg.RouteNumber) && !dDto.ArrivingBuses.Contains(lastBusLeg.RouteNumber))
                    dDto.ArrivingBuses.Add(lastBusLeg.RouteNumber);
            }
        }

        response.BoardingStops = boardingMap.Values.OrderBy(b => b.WalkDistanceMeters).ToList();
        response.DropOffStops = dropOffMap.Values.OrderBy(d => d.WalkToDestMeters).ToList();

        return response;
    }


    private static readonly HttpClient _httpClient = CreateHttpClient();

    private static HttpClient CreateHttpClient()
    {
        var client = new HttpClient { Timeout = TimeSpan.FromSeconds(3) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("PuneBus/1.0 (transit-app; contact@punebus.local)");
        return client;
    }

    private async Task<List<(StopEntity Stop, double WalkDistMeters)>> ResolveCandidateStopsAsync(LocationPointDto location, int maxWalkDistance)
    {
        bool isLiveGps = (location.Latitude != 0 && location.Longitude != 0) &&
                         (string.IsNullOrWhiteSpace(location.Name) ||
                          location.Name.Contains("Location", StringComparison.OrdinalIgnoreCase) ||
                          location.Name.Contains("स्थान", StringComparison.OrdinalIgnoreCase) ||
                          location.Name.Contains("GPS", StringComparison.OrdinalIgnoreCase) ||
                          location.Name.Contains("Current", StringComparison.OrdinalIgnoreCase) ||
                          location.Name.Contains("My", StringComparison.OrdinalIgnoreCase));

        if (!isLiveGps && !string.IsNullOrWhiteSpace(location.Name))
        {
            var clean = Normalize(location.Name);
            var exactMatches = _stops.Values.Where(s => s.NormalizedName.Contains(clean) || clean.Contains(s.NormalizedName)).ToList();
            if (exactMatches.Count > 0)
            {
                return exactMatches.Select(s => (s, 50.0)).Take(5).ToList();
            }
        }

        if (location.Latitude != 0 && location.Longitude != 0)
        {
            var initialCandidates = _stops.Values
                .Select(s => new
                {
                    Stop = s,
                    AirDist = CalculateDistanceMeters(location.Latitude, location.Longitude, s.Latitude, s.Longitude)
                })
                .Where(x => x.AirDist <= Math.Max(maxWalkDistance * 2.5, 2500))
                .OrderBy(x => x.AirDist)
                .Take(25)
                .Select(x => x.Stop)
                .ToList();

            var realDistances = await GetRealStreetWalkingDistancesAsync(location.Latitude, location.Longitude, initialCandidates);

            var nearby = initialCandidates
                .Select(s => (
                    Stop: s,
                    Dist: realDistances.TryGetValue(s.StopId, out var d) ? d : CalculateDistanceMeters(location.Latitude, location.Longitude, s.Latitude, s.Longitude)
                ))
                .OrderBy(x => x.Dist)
                .Take(6)
                .ToList();

            return nearby;
        }

        return new List<(StopEntity Stop, double WalkDistMeters)>();
    }

    private async Task<Dictionary<string, double>> GetRealStreetWalkingDistancesAsync(double userLat, double userLon, List<StopEntity> candidates)
    {
        var result = new Dictionary<string, double>();
        if (candidates.Count == 0) return result;

        // Try OpenStreetMap Free Foot Routing Table
        try
        {
            var coords = $"{userLon.ToString(CultureInfo.InvariantCulture)},{userLat.ToString(CultureInfo.InvariantCulture)};" +
                         string.Join(";", candidates.Select(c => $"{c.Longitude.ToString(CultureInfo.InvariantCulture)},{c.Latitude.ToString(CultureInfo.InvariantCulture)}"));
            var url = $"https://routing.openstreetmap.de/routed-foot/table/v1/foot/{coords}?sources=0";

            var response = await _httpClient.GetStringAsync(url);
            using var doc = System.Text.Json.JsonDocument.Parse(response);
            if (doc.RootElement.TryGetProperty("durations", out var durationsProp) && durationsProp.GetArrayLength() > 0)
            {
                var row = durationsProp[0];
                for (int i = 0; i < candidates.Count && i + 1 < row.GetArrayLength(); i++)
                {
                    if (row[i + 1].ValueKind == System.Text.Json.JsonValueKind.Number)
                    {
                        double durSec = row[i + 1].GetDouble();
                        double streetMeters = durSec * 1.25; // ~4.5 km/h pedestrian pace
                        result[candidates[i].StopId] = streetMeters;
                    }
                }
                if (result.Count > 0) return result;
            }
        }
        catch (Exception ex)
        {
            _logger.LogDebug("OSRM street distance query fallback: {Msg}", ex.Message);
        }

        // River-Barrier Fallback if OSRM is unreachable
        foreach (var s in candidates)
        {
            double dist = CalculateDistanceMeters(userLat, userLon, s.Latitude, s.Longitude);
            if (IsCrossingMulaRiver(userLat, userLon, s.Latitude, s.Longitude))
            {
                dist += 2000.0; // 2km river detour penalty
            }
            result[s.StopId] = dist;
        }

        return result;
    }

    private static bool IsCrossingMulaRiver(double lat1, double lon1, double lat2, double lon2)
    {
        if (lon1 < 73.76 || lon1 > 73.83 || lon2 < 73.76 || lon2 > 73.83) return false;
        double RiverLat(double lon) => 18.565 + (lon - 73.800) * 0.2;
        bool side1 = lat1 > RiverLat(lon1);
        bool side2 = lat2 > RiverLat(lon2);
        return side1 != side2;
    }

    private List<JourneyOptionDto> FindDirectJourneys(
        List<(StopEntity Stop, double WalkDistMeters)> origins,
        List<(StopEntity Stop, double WalkDistMeters)> destinations,
        JourneyPlanRequest request)
    {
        var result = new List<JourneyOptionDto>();

        foreach (var (origStop, origWalk) in origins)
        {
            if (!_stopToRoutes.TryGetValue(origStop.StopId, out var origRoutes)) continue;

            foreach (var (destStop, destWalk) in destinations)
            {
                if (!_stopToRoutes.TryGetValue(destStop.StopId, out var destRoutes)) continue;

                var commonRoutes = origRoutes.Intersect(destRoutes).ToList();
                if (commonRoutes.Count == 0) continue;

                foreach (var routeId in commonRoutes)
                {
                    if (!_routes.TryGetValue(routeId, out var route)) continue;
                    if (!_routeToStops.TryGetValue(routeId, out var stopsList)) continue;

                    int origIdx = stopsList.IndexOf(origStop.StopId);
                    int destIdx = stopsList.IndexOf(destStop.StopId);

                    if (origIdx >= 0 && destIdx > origIdx)
                    {
                        int intermediateCount = destIdx - origIdx - 1;
                        var intermediateStopNames = stopsList.Skip(origIdx + 1).Take(intermediateCount)
                            .Select(sid => _stops.TryGetValue(sid, out var s) ? s.StopName : sid)
                            .ToList();

                        // Coordinates for full route polyline
                        var pathCoords = stopsList.Skip(origIdx).Take(destIdx - origIdx + 1)
                            .Where(sid => _stops.ContainsKey(sid))
                            .Select(sid => new CoordinatesDto(_stops[sid].Latitude, _stops[sid].Longitude))
                            .ToList();

                        double busDistMeters = CalculatePathDistance(pathCoords);
                        int busDurationMin = Math.Max(5, (destIdx - origIdx) * 2 + 2);
                        int walk1Min = (int)Math.Ceiling(origWalk / 75.0);
                        int walk2Min = (int)Math.Ceiling(destWalk / 75.0);
                        int totalMin = walk1Min + busDurationMin + walk2Min + 2;
                        int fare = CalculateFareRupees(busDistMeters);

                        // Find ALL parallel buses running this exact segment!
                        var parallelBuses = FindParallelBuses(origStop.StopId, destStop.StopId);

                        var busSummary = parallelBuses.Count > 1
                            ? $"Bus {route.RouteShortName} (or {string.Join(", ", parallelBuses.Where(b => b != route.RouteShortName).Take(3))})"
                            : $"Direct Bus {route.RouteShortName}";

                        var journey = new JourneyOptionDto
                        {
                            Summary = $"{busSummary} ({origStop.StopName} → {destStop.StopName})",
                            TransferCount = 0,
                            TotalDurationMinutes = totalMin,
                            TotalWalkingMeters = (int)(origWalk + destWalk),
                            TotalWaitMinutes = 3,
                            TotalFareRupees = fare,
                            DailyPassTip = fare >= 40 ? "💡 A ₹40 (PMC/PCMC) or ₹50 (All Pune) Day Pass may be cheaper if returning!" : null,
                            MapPolyline = pathCoords,
                            Legs = new List<JourneyLegDto>
                            {
                                new()
                                {
                                    Type = "WALK",
                                    Instruction = $"Walk to {origStop.StopName}",
                                    DistanceMeters = (int)origWalk,
                                    DurationMinutes = walk1Min,
                                    FromName = request.Origin.Name,
                                    ToName = origStop.StopName,
                                    PathCoordinates = new()
                                    {
                                        new(request.Origin.Latitude, request.Origin.Longitude),
                                        new(origStop.Latitude, origStop.Longitude)
                                    }
                                },
                                new()
                                {
                                    Type = "BUS",
                                    RouteNumber = route.RouteShortName,
                                    RouteLongName = route.RouteLongName,
                                    BoardStop = origStop.StopName,
                                    BoardStopCoords = new(origStop.Latitude, origStop.Longitude),
                                    GetOffStop = destStop.StopName,
                                    GetOffStopCoords = new(destStop.Latitude, destStop.Longitude),
                                    IntermediateStopsCount = intermediateCount,
                                    IntermediateStops = intermediateStopNames,
                                    AlternateBuses = parallelBuses,
                                    DurationMinutes = busDurationMin,
                                    EstimatedFareRupees = fare,
                                    NextDepartures = GenerateUpcomingDepartures(),
                                    FirstBusTime = "06:15 AM",
                                    LastBusTime = "10:30 PM",
                                    ScheduledDeparture = "Every 10-15 mins",
                                    ScheduledArrival = $"+{busDurationMin} mins",
                                    PathCoordinates = pathCoords
                                },
                                new()
                                {
                                    Type = "WALK",
                                    Instruction = $"Walk to {request.Destination.Name}",
                                    DistanceMeters = (int)destWalk,
                                    DurationMinutes = walk2Min,
                                    FromName = destStop.StopName,
                                    ToName = request.Destination.Name,
                                    PathCoordinates = new()
                                    {
                                        new(destStop.Latitude, destStop.Longitude),
                                        new(request.Destination.Latitude, request.Destination.Longitude)
                                    }
                                }
                            }
                        };
                        result.Add(journey);
                    }
                }
            }
        }
        return result;
    }

    private List<JourneyOptionDto> FindTransferJourneys(
        List<(StopEntity Stop, double WalkDistMeters)> origins,
        List<(StopEntity Stop, double WalkDistMeters)> destinations,
        JourneyPlanRequest request)
    {
        var result = new List<JourneyOptionDto>();

        foreach (var (origStop, origWalk) in origins)
        {
            if (!_stopToRoutes.TryGetValue(origStop.StopId, out var r1List)) continue;

            foreach (var r1Id in r1List)
            {
                if (!_routes.TryGetValue(r1Id, out var route1)) continue;
                if (!_routeToStops.TryGetValue(r1Id, out var r1Stops)) continue;
                int r1OrigIdx = r1Stops.IndexOf(origStop.StopId);
                if (r1OrigIdx < 0) continue;

                for (int tIdx = r1OrigIdx + 1; tIdx < r1Stops.Count; tIdx++)
                {
                    var tStopId1 = r1Stops[tIdx];
                    if (!_stops.TryGetValue(tStopId1, out var transferStop1)) continue;

                    var transferOptions = new List<(string TransferStopId2, int TransferWalkMeters, int TransferWalkSec)>
                    {
                        (tStopId1, 0, 0)
                    };

                    if (_footpaths.TryGetValue(tStopId1, out var fpList))
                    {
                        foreach (var fp in fpList)
                        {
                            transferOptions.Add((fp.ToStopId, fp.DistMeters, fp.DurSec));
                        }
                    }

                    foreach (var (tStopId2, tWalkDist, tWalkSec) in transferOptions)
                    {
                        if (!_stopToRoutes.TryGetValue(tStopId2, out var r2List)) continue;

                        foreach (var r2Id in r2List)
                        {
                            if (r2Id == r1Id) continue;
                            if (!_routes.TryGetValue(r2Id, out var route2)) continue;
                            if (!_routeToStops.TryGetValue(r2Id, out var r2Stops)) continue;

                            int r2TIdx = r2Stops.IndexOf(tStopId2);
                            if (r2TIdx < 0) continue;

                            foreach (var (destStop, destWalk) in destinations)
                            {
                                int r2DestIdx = r2Stops.IndexOf(destStop.StopId);
                                if (r2DestIdx > r2TIdx)
                                {
                                    var transferStop2 = _stops.TryGetValue(tStopId2, out var s2) ? s2 : transferStop1;

                                    var r1Path = r1Stops.Skip(r1OrigIdx).Take(tIdx - r1OrigIdx + 1)
                                        .Where(sid => _stops.ContainsKey(sid))
                                        .Select(sid => new CoordinatesDto(_stops[sid].Latitude, _stops[sid].Longitude))
                                        .ToList();

                                    var r2Path = r2Stops.Skip(r2TIdx).Take(r2DestIdx - r2TIdx + 1)
                                        .Where(sid => _stops.ContainsKey(sid))
                                        .Select(sid => new CoordinatesDto(_stops[sid].Latitude, _stops[sid].Longitude))
                                        .ToList();

                                    double bus1Dist = CalculatePathDistance(r1Path);
                                    double bus2Dist = CalculatePathDistance(r2Path);

                                    int fare1 = CalculateFareRupees(bus1Dist);
                                    int fare2 = CalculateFareRupees(bus2Dist);
                                    int totalFare = fare1 + fare2;

                                    int bus1Duration = Math.Max(8, (tIdx - r1OrigIdx) * 2 + 2);
                                    int bus2Duration = Math.Max(8, (r2DestIdx - r2TIdx) * 2 + 2);
                                    int walk1Min = (int)Math.Ceiling(origWalk / 75.0);
                                    int transferWalkMin = Math.Max(1, (int)Math.Ceiling(tWalkDist / 75.0));
                                    int walk2Min = (int)Math.Ceiling(destWalk / 75.0);
                                    int waitMin = 6;
                                    int totalDuration = walk1Min + bus1Duration + transferWalkMin + waitMin + bus2Duration + walk2Min;

                                    var r1Parallel = FindParallelBuses(origStop.StopId, transferStop1.StopId);
                                    var r2Parallel = FindParallelBuses(transferStop2.StopId, destStop.StopId);

                                    var intermediate1 = r1Stops.Skip(r1OrigIdx + 1).Take(tIdx - r1OrigIdx - 1)
                                        .Select(sid => _stops.TryGetValue(sid, out var s) ? s.StopName : sid).ToList();

                                    var intermediate2 = r2Stops.Skip(r2TIdx + 1).Take(r2DestIdx - r2TIdx - 1)
                                        .Select(sid => _stops.TryGetValue(sid, out var s) ? s.StopName : sid).ToList();

                                    var fullMapPath = new List<CoordinatesDto>();
                                    fullMapPath.AddRange(r1Path);
                                    fullMapPath.AddRange(r2Path);

                                    var journey = new JourneyOptionDto
                                    {
                                        Summary = $"Bus {route1.RouteShortName} → Bus {route2.RouteShortName} via {transferStop1.StopName}",
                                        TransferCount = 1,
                                        TotalDurationMinutes = totalDuration,
                                        TotalWalkingMeters = (int)(origWalk + tWalkDist + destWalk),
                                        TotalWaitMinutes = waitMin,
                                        TotalFareRupees = totalFare,
                                        DailyPassTip = totalFare >= 40 ? "💡 A ₹40/₹50 PMPML Day Pass might save money for your journey today!" : null,
                                        MapPolyline = fullMapPath,
                                        Legs = new List<JourneyLegDto>
                                        {
                                            new()
                                            {
                                                Type = "WALK",
                                                Instruction = $"Walk to {origStop.StopName}",
                                                DistanceMeters = (int)origWalk,
                                                DurationMinutes = walk1Min,
                                                FromName = request.Origin.Name,
                                                ToName = origStop.StopName,
                                                PathCoordinates = new()
                                                {
                                                    new(request.Origin.Latitude != 0 ? request.Origin.Latitude : origStop.Latitude,
                                                        request.Origin.Longitude != 0 ? request.Origin.Longitude : origStop.Longitude),
                                                    new(origStop.Latitude, origStop.Longitude)
                                                }
                                            },
                                            new()
                                            {
                                                Type = "BUS",
                                                RouteNumber = route1.RouteShortName,
                                                RouteLongName = route1.RouteLongName,
                                                BoardStop = origStop.StopName,
                                                BoardStopCoords = new(origStop.Latitude, origStop.Longitude),
                                                GetOffStop = transferStop1.StopName,
                                                GetOffStopCoords = new(transferStop1.Latitude, transferStop1.Longitude),
                                                IntermediateStopsCount = tIdx - r1OrigIdx - 1,
                                                IntermediateStops = intermediate1,
                                                AlternateBuses = r1Parallel,
                                                DurationMinutes = bus1Duration,
                                                EstimatedFareRupees = fare1,
                                                NextDepartures = GenerateUpcomingDepartures(),
                                                FirstBusTime = "06:00 AM",
                                                LastBusTime = "10:45 PM",
                                                ScheduledDeparture = "Every 10-15 mins",
                                                ScheduledArrival = $"+{bus1Duration} mins",
                                                PathCoordinates = r1Path
                                            },
                                            new()
                                            {
                                                Type = "TRANSFER_WALK",
                                                Instruction = tWalkDist > 10
                                                    ? $"Walk {tWalkDist}m across {transferStop1.StopName} to Bus {route2.RouteShortName} stop"
                                                    : $"Change at {transferStop1.StopName} for Bus {route2.RouteShortName}",
                                                DistanceMeters = tWalkDist,
                                                DurationMinutes = transferWalkMin,
                                                FromName = transferStop1.StopName,
                                                ToName = transferStop2.StopName,
                                                PathCoordinates = new()
                                                {
                                                    new(transferStop1.Latitude, transferStop1.Longitude),
                                                    new(transferStop2.Latitude, transferStop2.Longitude)
                                                }
                                            },
                                            new()
                                            {
                                                Type = "BUS",
                                                RouteNumber = route2.RouteShortName,
                                                RouteLongName = route2.RouteLongName,
                                                BoardStop = transferStop2.StopName,
                                                BoardStopCoords = new(transferStop2.Latitude, transferStop2.Longitude),
                                                GetOffStop = destStop.StopName,
                                                GetOffStopCoords = new(destStop.Latitude, destStop.Longitude),
                                                IntermediateStopsCount = r2DestIdx - r2TIdx - 1,
                                                IntermediateStops = intermediate2,
                                                AlternateBuses = r2Parallel,
                                                DurationMinutes = bus2Duration,
                                                EstimatedFareRupees = fare2,
                                                NextDepartures = GenerateUpcomingDepartures(15),
                                                FirstBusTime = "06:30 AM",
                                                LastBusTime = "10:15 PM",
                                                ScheduledDeparture = "Scheduled transfer",
                                                ScheduledArrival = $"+{bus2Duration} mins",
                                                PathCoordinates = r2Path
                                            },
                                            new()
                                            {
                                                Type = "WALK",
                                                Instruction = $"Walk to {request.Destination.Name}",
                                                DistanceMeters = (int)destWalk,
                                                DurationMinutes = walk2Min,
                                                FromName = destStop.StopName,
                                                ToName = request.Destination.Name,
                                                PathCoordinates = new()
                                                {
                                                    new(destStop.Latitude, destStop.Longitude),
                                                    new(request.Destination.Latitude != 0 ? request.Destination.Latitude : destStop.Latitude,
                                                        request.Destination.Longitude != 0 ? request.Destination.Longitude : destStop.Longitude)
                                                }
                                            }
                                        }
                                    };
                                    result.Add(journey);
                                    if (result.Count >= 50) return result;
                                }
                            }
                        }
                    }
                }
            }
        }
        return result;
    }

    private List<string> FindParallelBuses(string fromStopId, string toStopId)
    {
        if (!_stopToRoutes.TryGetValue(fromStopId, out var routesAtFrom)) return new();
        var parallel = new List<string>();

        foreach (var rid in routesAtFrom)
        {
            if (!_routeToStops.TryGetValue(rid, out var stops)) continue;
            int idx1 = stops.IndexOf(fromStopId);
            int idx2 = stops.IndexOf(toStopId);
            if (idx1 >= 0 && idx2 > idx1)
            {
                if (_routes.TryGetValue(rid, out var r) && !parallel.Contains(r.RouteShortName))
                {
                    parallel.Add(r.RouteShortName);
                }
            }
        }
        return parallel.OrderBy(x => x).ToList();
    }

    private static int CalculateFareRupees(double distanceMeters)
    {
        double km = distanceMeters / 1000.0;
        if (km <= 2.0) return 5;
        if (km <= 4.0) return 10;
        if (km <= 8.0) return 15;
        if (km <= 12.0) return 20;
        if (km <= 16.0) return 25;
        if (km <= 20.0) return 30;
        return 35;
    }

    private static double CalculatePathDistance(List<CoordinatesDto> points)
    {
        double total = 0;
        for (int i = 0; i < points.Count - 1; i++)
        {
            total += CalculateDistanceMeters(points[i].Latitude, points[i].Longitude, points[i + 1].Latitude, points[i + 1].Longitude);
        }
        return total;
    }

    private static List<string> GenerateUpcomingDepartures(int offsetMinutes = 3)
    {
        var now = DateTime.Now.AddMinutes(offsetMinutes);
        return new List<string>
        {
            now.ToString("hh:mm tt"),
            now.AddMinutes(8).ToString("hh:mm tt"),
            now.AddMinutes(17).ToString("hh:mm tt"),
            now.AddMinutes(28).ToString("hh:mm tt")
        };
    }

    private static double CalculateDistanceMeters(double lat1, double lon1, double lat2, double lon2)
    {
        double R = 6371000;
        double dLat = (lat2 - lat1) * Math.PI / 180.0;
        double dLon = (lon2 - lon1) * Math.PI / 180.0;
        double a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                   Math.Cos(lat1 * Math.PI / 180.0) * Math.Cos(lat2 * Math.PI / 180.0) *
                   Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        double c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return R * c;
    }

    private static string Normalize(string input) =>
        new string(input.ToLowerInvariant().Where(char.IsLetterOrDigit).ToArray());
}
