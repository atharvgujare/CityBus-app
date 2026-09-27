namespace PuneBus.Api.Models.Dtos;

public class CoordinatesDto
{
    public double Latitude { get; set; }
    public double Longitude { get; set; }

    public CoordinatesDto() { }
    public CoordinatesDto(double lat, double lon)
    {
        Latitude = lat;
        Longitude = lon;
    }
}

public class LocationPointDto
{
    public string Name { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
}

public class JourneyPlanRequest
{
    public LocationPointDto Origin { get; set; } = new();
    public LocationPointDto Destination { get; set; } = new();
    public DateTime? DepartureTime { get; set; }
    public int MaxWalkDistanceMeters { get; set; } = 800;
}

public class JourneyLegDto
{
    public string Type { get; set; } = "BUS"; // WALK, BUS, TRANSFER_WALK
    public string Instruction { get; set; } = string.Empty;
    public int DistanceMeters { get; set; }
    public int DurationMinutes { get; set; }
    
    // For bus leg
    public string? RouteNumber { get; set; }
    public string? RouteLongName { get; set; }
    public string? BoardStop { get; set; }
    public CoordinatesDto? BoardStopCoords { get; set; }
    public string? ScheduledDeparture { get; set; }
    public string? GetOffStop { get; set; }
    public CoordinatesDto? GetOffStopCoords { get; set; }
    public string? ScheduledArrival { get; set; }
    public int? IntermediateStopsCount { get; set; }
    public List<string> IntermediateStops { get; set; } = new();
    public List<string> AlternateBuses { get; set; } = new(); // Parallel routes sharing this exact leg
    public List<string> NextDepartures { get; set; } = new();
    public string? FirstBusTime { get; set; }
    public string? LastBusTime { get; set; }
    public int EstimatedFareRupees { get; set; } = 5;

    // For walk / transfer
    public string? FromName { get; set; }
    public string? ToName { get; set; }
    public List<CoordinatesDto> PathCoordinates { get; set; } = new();
}

public class JourneyOptionDto
{
    public string JourneyId { get; set; } = Guid.NewGuid().ToString("N");
    public string Category { get; set; } = "FASTEST"; // FASTEST, LEAST_WALKING, FEWEST_TRANSFERS, SIMPLEST
    public string Summary { get; set; } = string.Empty;
    public int TotalDurationMinutes { get; set; }
    public int TotalWalkingMeters { get; set; }
    public int TotalWaitMinutes { get; set; }
    public int TransferCount { get; set; }
    public int TotalFareRupees { get; set; } = 15;
    public string? DailyPassTip { get; set; }
    public List<JourneyLegDto> Legs { get; set; } = new();
    public List<CoordinatesDto> MapPolyline { get; set; } = new();
}

public class JourneyPlanResponse
{
    public LocationPointDto Origin { get; set; } = new();
    public LocationPointDto Destination { get; set; } = new();
    public List<JourneyOptionDto> Journeys { get; set; } = new();
}

public class StopDto
{
    public string StopId { get; set; } = string.Empty;
    public string StopName { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double DistanceMeters { get; set; }
    public List<string> ServingRoutes { get; set; } = new();
}

public class RouteDto
{
    public string RouteId { get; set; } = string.Empty;
    public string RouteShortName { get; set; } = string.Empty;
    public string RouteLongName { get; set; } = string.Empty;
    public int TotalStops { get; set; }
    public string? FirstStop { get; set; }
    public string? LastStop { get; set; }
}

public class RouteDetailsDto : RouteDto
{
    public List<StopDto> Stops { get; set; } = new();
    public List<string> Timetable { get; set; } = new();
    public string? ReturnRouteId { get; set; }
    public string? ReturnRouteName { get; set; }
}

public class ViableStopsResponse
{
    public List<ViableBoardingStopDto> BoardingStops { get; set; } = new();
    public List<ViableDropOffStopDto> DropOffStops { get; set; } = new();
}

public class ViableBoardingStopDto
{
    public string StopId { get; set; } = string.Empty;
    public string StopName { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double WalkDistanceMeters { get; set; }
    public int WalkMinutes { get; set; }
    public List<string> DirectBuses { get; set; } = new();
    public List<string> ConnectingBuses { get; set; } = new();
    public int BestTotalMinutes { get; set; }
}

public class ViableDropOffStopDto
{
    public string StopId { get; set; } = string.Empty;
    public string StopName { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double WalkToDestMeters { get; set; }
    public int WalkMinutes { get; set; }
    public List<string> ArrivingBuses { get; set; } = new();
}

