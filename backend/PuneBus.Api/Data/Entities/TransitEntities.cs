namespace PuneBus.Api.Data.Entities;

public class Agency
{
    public string AgencyId { get; set; } = string.Empty;
    public string AgencyName { get; set; } = string.Empty;
    public string? AgencyUrl { get; set; }
    public string Timezone { get; set; } = "Asia/Kolkata";
}

public class RouteEntity
{
    public string RouteId { get; set; } = string.Empty;
    public string AgencyId { get; set; } = string.Empty;
    public string RouteShortName { get; set; } = string.Empty;
    public string RouteLongName { get; set; } = string.Empty;
    public int RouteType { get; set; }

    public ICollection<TripEntity> Trips { get; set; } = new List<TripEntity>();
}

public class StopEntity
{
    public string StopId { get; set; } = string.Empty;
    public string StopName { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public string NormalizedName { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;

    public ICollection<StopTimeEntity> StopTimes { get; set; } = new List<StopTimeEntity>();
}

public class CalendarEntity
{
    public string ServiceId { get; set; } = string.Empty;
    public bool Monday { get; set; }
    public bool Tuesday { get; set; }
    public bool Wednesday { get; set; }
    public bool Thursday { get; set; }
    public bool Friday { get; set; }
    public bool Saturday { get; set; }
    public bool Sunday { get; set; }
    public string StartDate { get; set; } = string.Empty;
    public string EndDate { get; set; } = string.Empty;
}

public class TripEntity
{
    public string TripId { get; set; } = string.Empty;
    public string RouteId { get; set; } = string.Empty;
    public string ServiceId { get; set; } = string.Empty;
    public string? TripHeadsign { get; set; }
    public int DirectionId { get; set; }
    public string? ShapeId { get; set; }

    public RouteEntity? Route { get; set; }
    public ICollection<StopTimeEntity> StopTimes { get; set; } = new List<StopTimeEntity>();
}

public class StopTimeEntity
{
    public string TripId { get; set; } = string.Empty;
    public int StopSequence { get; set; }
    public string StopId { get; set; } = string.Empty;
    public string ArrivalTime { get; set; } = string.Empty;
    public string DepartureTime { get; set; } = string.Empty;
    public int Timepoint { get; set; }

    public TripEntity? Trip { get; set; }
    public StopEntity? Stop { get; set; }
}

public class FootpathEntity
{
    public string FromStopId { get; set; } = string.Empty;
    public string ToStopId { get; set; } = string.Empty;
    public int WalkingDistanceMeters { get; set; }
    public int WalkingDurationSeconds { get; set; }
}

public class DataSourceVersion
{
    public int Id { get; set; }
    public string SourceDescription { get; set; } = string.Empty;
    public string? SourceUrl { get; set; }
    public DateTimeOffset ImportedAt { get; set; } = DateTimeOffset.UtcNow;
    public string? Summary { get; set; }
    public bool IsValid { get; set; } = true;
}
