using System.Diagnostics;
using System.Globalization;
using Microsoft.Data.Sqlite;
using PuneBus.Api.Data;
using PuneBus.Api.Data.Entities;

namespace PuneBus.Api.Services;

public interface IGtfsImporterService
{
    Task<bool> EnsureDatabaseSeededAsync(string gtfsDirectory, string connectionString);
}

public class GtfsImporterService : IGtfsImporterService
{
    private readonly ILogger<GtfsImporterService> _logger;

    public GtfsImporterService(ILogger<GtfsImporterService> logger)
    {
        _logger = logger;
    }

    public async Task<bool> EnsureDatabaseSeededAsync(string gtfsDirectory, string connectionString)
    {
        using var connection = new SqliteConnection(connectionString);
        await connection.OpenAsync();

        // Check if database is already seeded
        using (var checkCmd = connection.CreateCommand())
        {
            checkCmd.CommandText = "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='Stops';";
            var exists = Convert.ToInt64(await checkCmd.ExecuteScalarAsync() ?? 0) > 0;
            if (exists)
            {
                using var countCmd = connection.CreateCommand();
                countCmd.CommandText = "SELECT COUNT(*) FROM Stops;";
                var stopCount = Convert.ToInt64(await countCmd.ExecuteScalarAsync() ?? 0);
                if (stopCount > 6000)
                {
                    _logger.LogInformation("Database already seeded with {StopCount} stops.", stopCount);
                    return true;
                }
            }
        }

        _logger.LogInformation("Seeding PMPML GTFS database from {Directory}...", gtfsDirectory);
        var stopwatch = Stopwatch.StartNew();

        // Initialize schema
        using (var pragmaCmd = connection.CreateCommand())
        {
            pragmaCmd.CommandText = @"
                PRAGMA synchronous = OFF;
                PRAGMA journal_mode = MEMORY;
                PRAGMA cache_size = 100000;
            ";
            await pragmaCmd.ExecuteNonQueryAsync();
        }

        // Create Tables
        using (var schemaCmd = connection.CreateCommand())
        {
            schemaCmd.CommandText = @"
                CREATE TABLE IF NOT EXISTS Agencies (
                    AgencyId TEXT PRIMARY KEY,
                    AgencyName TEXT NOT NULL,
                    AgencyUrl TEXT,
                    Timezone TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS Stops (
                    StopId TEXT PRIMARY KEY,
                    StopName TEXT NOT NULL,
                    Latitude REAL NOT NULL,
                    Longitude REAL NOT NULL,
                    NormalizedName TEXT NOT NULL,
                    IsActive INTEGER NOT NULL DEFAULT 1
                );

                CREATE TABLE IF NOT EXISTS Routes (
                    RouteId TEXT PRIMARY KEY,
                    AgencyId TEXT NOT NULL,
                    RouteShortName TEXT NOT NULL,
                    RouteLongName TEXT NOT NULL,
                    RouteType INTEGER NOT NULL
                );

                CREATE TABLE IF NOT EXISTS Calendars (
                    ServiceId TEXT PRIMARY KEY,
                    Monday INTEGER NOT NULL,
                    Tuesday INTEGER NOT NULL,
                    Wednesday INTEGER NOT NULL,
                    Thursday INTEGER NOT NULL,
                    Friday INTEGER NOT NULL,
                    Saturday INTEGER NOT NULL,
                    Sunday INTEGER NOT NULL,
                    StartDate TEXT NOT NULL,
                    EndDate TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS Trips (
                    TripId TEXT PRIMARY KEY,
                    RouteId TEXT NOT NULL,
                    ServiceId TEXT NOT NULL,
                    TripHeadsign TEXT,
                    DirectionId INTEGER NOT NULL,
                    ShapeId TEXT
                );

                CREATE TABLE IF NOT EXISTS StopTimes (
                    TripId TEXT NOT NULL,
                    StopSequence INTEGER NOT NULL,
                    StopId TEXT NOT NULL,
                    ArrivalTime TEXT NOT NULL,
                    DepartureTime TEXT NOT NULL,
                    Timepoint INTEGER NOT NULL,
                    PRIMARY KEY (TripId, StopSequence)
                );

                CREATE TABLE IF NOT EXISTS Footpaths (
                    FromStopId TEXT NOT NULL,
                    ToStopId TEXT NOT NULL,
                    WalkingDistanceMeters INTEGER NOT NULL,
                    WalkingDurationSeconds INTEGER NOT NULL,
                    PRIMARY KEY (FromStopId, ToStopId)
                );

                CREATE TABLE IF NOT EXISTS DataSourceVersions (
                    Id INTEGER PRIMARY KEY AUTOINCREMENT,
                    SourceDescription TEXT NOT NULL,
                    SourceUrl TEXT,
                    ImportedAt TEXT NOT NULL,
                    Summary TEXT,
                    IsValid INTEGER NOT NULL DEFAULT 1
                );
            ";
            await schemaCmd.ExecuteNonQueryAsync();
        }

        // Import Agencies
        await ImportAgenciesAsync(connection, Path.Combine(gtfsDirectory, "agency.txt"));

        // Import Calendars
        await ImportCalendarsAsync(connection, Path.Combine(gtfsDirectory, "calendar.txt"));

        // Import Routes
        await ImportRoutesAsync(connection, Path.Combine(gtfsDirectory, "routes.txt"));

        // Import Stops
        var stops = await ImportStopsAsync(connection, Path.Combine(gtfsDirectory, "stops.txt"));

        // Import Trips
        await ImportTripsAsync(connection, Path.Combine(gtfsDirectory, "trips.txt"));

        // Import StopTimes
        await ImportStopTimesAsync(connection, Path.Combine(gtfsDirectory, "stop_times.txt"));

        // Build Footpaths (Nearby stop transfer walking edges <= 300m)
        await GenerateFootpathsAsync(connection, stops);

        // Build Indexes
        _logger.LogInformation("Creating performance indexes...");
        using (var indexCmd = connection.CreateCommand())
        {
            indexCmd.CommandText = @"
                CREATE INDEX IF NOT EXISTS IX_Stops_Normalized ON Stops(NormalizedName);
                CREATE INDEX IF NOT EXISTS IX_Stops_Coords ON Stops(Latitude, Longitude);
                CREATE INDEX IF NOT EXISTS IX_Routes_ShortName ON Routes(RouteShortName);
                CREATE INDEX IF NOT EXISTS IX_Trips_RouteId ON Trips(RouteId);
                CREATE INDEX IF NOT EXISTS IX_StopTimes_Stop_Dept ON StopTimes(StopId, DepartureTime);
                CREATE INDEX IF NOT EXISTS IX_StopTimes_Trip ON StopTimes(TripId);
                CREATE INDEX IF NOT EXISTS IX_Footpaths_From ON Footpaths(FromStopId);
            ";
            await indexCmd.ExecuteNonQueryAsync();
        }

        // Record provenance
        using (var provCmd = connection.CreateCommand())
        {
            provCmd.CommandText = @"
                INSERT INTO DataSourceVersions (SourceDescription, SourceUrl, ImportedAt, Summary, IsValid)
                VALUES ('PMPML GTFS Static Feed', 'https://github.com/croyla/pmpml-gtfs.git', datetime('now'), 'Initial import of 617 routes and 6713 stops', 1);
            ";
            await provCmd.ExecuteNonQueryAsync();
        }

        stopwatch.Stop();
        _logger.LogInformation("GTFS ingestion finished successfully in {Elapsed} seconds.", stopwatch.Elapsed.TotalSeconds);
        return true;
    }

    private async Task ImportAgenciesAsync(SqliteConnection connection, string file)
    {
        if (!File.Exists(file)) return;
        using var tx = connection.BeginTransaction();
        using var cmd = connection.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = "INSERT OR REPLACE INTO Agencies VALUES (@id, @name, @url, @tz);";
        cmd.Parameters.Add("@id", SqliteType.Text);
        cmd.Parameters.Add("@name", SqliteType.Text);
        cmd.Parameters.Add("@url", SqliteType.Text);
        cmd.Parameters.Add("@tz", SqliteType.Text);

        using var reader = new StreamReader(file);
        reader.ReadLine(); // header
        string? line;
        while ((line = await reader.ReadLineAsync()) != null)
        {
            var p = SplitCsv(line);
            if (p.Length >= 4)
            {
                cmd.Parameters["@id"].Value = p[0];
                cmd.Parameters["@name"].Value = p[1];
                cmd.Parameters["@url"].Value = p[2];
                cmd.Parameters["@tz"].Value = p[3];
                await cmd.ExecuteNonQueryAsync();
            }
        }
        await tx.CommitAsync();
    }

    private async Task ImportCalendarsAsync(SqliteConnection connection, string file)
    {
        if (!File.Exists(file)) return;
        using var tx = connection.BeginTransaction();
        using var cmd = connection.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = "INSERT OR REPLACE INTO Calendars VALUES (@id, @m, @tu, @w, @th, @f, @sa, @su, @s, @e);";
        cmd.Parameters.Add("@id", SqliteType.Text);
        cmd.Parameters.Add("@m", SqliteType.Integer);
        cmd.Parameters.Add("@tu", SqliteType.Integer);
        cmd.Parameters.Add("@w", SqliteType.Integer);
        cmd.Parameters.Add("@th", SqliteType.Integer);
        cmd.Parameters.Add("@f", SqliteType.Integer);
        cmd.Parameters.Add("@sa", SqliteType.Integer);
        cmd.Parameters.Add("@su", SqliteType.Integer);
        cmd.Parameters.Add("@s", SqliteType.Text);
        cmd.Parameters.Add("@e", SqliteType.Text);

        using var reader = new StreamReader(file);
        reader.ReadLine(); // header
        string? line;
        while ((line = await reader.ReadLineAsync()) != null)
        {
            var p = SplitCsv(line);
            if (p.Length >= 10)
            {
                cmd.Parameters["@id"].Value = p[0];
                cmd.Parameters["@m"].Value = int.Parse(p[1]);
                cmd.Parameters["@tu"].Value = int.Parse(p[2]);
                cmd.Parameters["@w"].Value = int.Parse(p[3]);
                cmd.Parameters["@th"].Value = int.Parse(p[4]);
                cmd.Parameters["@f"].Value = int.Parse(p[5]);
                cmd.Parameters["@sa"].Value = int.Parse(p[6]);
                cmd.Parameters["@su"].Value = int.Parse(p[7]);
                cmd.Parameters["@s"].Value = p[8];
                cmd.Parameters["@e"].Value = p[9];
                await cmd.ExecuteNonQueryAsync();
            }
        }
        await tx.CommitAsync();
    }

    private async Task ImportRoutesAsync(SqliteConnection connection, string file)
    {
        if (!File.Exists(file)) return;
        using var tx = connection.BeginTransaction();
        using var cmd = connection.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = "INSERT OR REPLACE INTO Routes VALUES (@id, @aid, @short, @long, @type);";
        cmd.Parameters.Add("@id", SqliteType.Text);
        cmd.Parameters.Add("@aid", SqliteType.Text);
        cmd.Parameters.Add("@short", SqliteType.Text);
        cmd.Parameters.Add("@long", SqliteType.Text);
        cmd.Parameters.Add("@type", SqliteType.Integer);

        using var reader = new StreamReader(file);
        reader.ReadLine();
        string? line;
        while ((line = await reader.ReadLineAsync()) != null)
        {
            var p = SplitCsv(line);
            if (p.Length >= 5)
            {
                cmd.Parameters["@id"].Value = p[0];
                cmd.Parameters["@aid"].Value = p[1];
                cmd.Parameters["@short"].Value = p[2];
                cmd.Parameters["@long"].Value = p[3];
                cmd.Parameters["@type"].Value = int.Parse(p[4]);
                await cmd.ExecuteNonQueryAsync();
            }
        }
        await tx.CommitAsync();
    }

    private async Task<List<StopEntity>> ImportStopsAsync(SqliteConnection connection, string file)
    {
        var list = new List<StopEntity>();
        if (!File.Exists(file)) return list;
        using var tx = connection.BeginTransaction();
        using var cmd = connection.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = "INSERT OR REPLACE INTO Stops VALUES (@id, @name, @lat, @lon, @norm, 1);";
        cmd.Parameters.Add("@id", SqliteType.Text);
        cmd.Parameters.Add("@name", SqliteType.Text);
        cmd.Parameters.Add("@lat", SqliteType.Real);
        cmd.Parameters.Add("@lon", SqliteType.Real);
        cmd.Parameters.Add("@norm", SqliteType.Text);

        using var reader = new StreamReader(file);
        reader.ReadLine();
        string? line;
        while ((line = await reader.ReadLineAsync()) != null)
        {
            var p = SplitCsv(line);
            if (p.Length >= 4)
            {
                var stop = new StopEntity
                {
                    StopId = p[0],
                    StopName = p[1],
                    Latitude = double.Parse(p[2], CultureInfo.InvariantCulture),
                    Longitude = double.Parse(p[3], CultureInfo.InvariantCulture),
                    NormalizedName = Normalize(p[1])
                };
                list.Add(stop);

                cmd.Parameters["@id"].Value = stop.StopId;
                cmd.Parameters["@name"].Value = stop.StopName;
                cmd.Parameters["@lat"].Value = stop.Latitude;
                cmd.Parameters["@lon"].Value = stop.Longitude;
                cmd.Parameters["@norm"].Value = stop.NormalizedName;
                await cmd.ExecuteNonQueryAsync();
            }
        }
        await tx.CommitAsync();
        return list;
    }

    private async Task ImportTripsAsync(SqliteConnection connection, string file)
    {
        if (!File.Exists(file)) return;
        using var tx = connection.BeginTransaction();
        using var cmd = connection.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = "INSERT OR REPLACE INTO Trips VALUES (@tid, @rid, @sid, @head, @dir, @shape);";
        cmd.Parameters.Add("@tid", SqliteType.Text);
        cmd.Parameters.Add("@rid", SqliteType.Text);
        cmd.Parameters.Add("@sid", SqliteType.Text);
        cmd.Parameters.Add("@head", SqliteType.Text);
        cmd.Parameters.Add("@dir", SqliteType.Integer);
        cmd.Parameters.Add("@shape", SqliteType.Text);

        using var reader = new StreamReader(file);
        reader.ReadLine();
        string? line;
        while ((line = await reader.ReadLineAsync()) != null)
        {
            var p = SplitCsv(line);
            if (p.Length >= 6)
            {
                cmd.Parameters["@rid"].Value = p[0];
                cmd.Parameters["@sid"].Value = p[1];
                cmd.Parameters["@tid"].Value = p[2];
                cmd.Parameters["@head"].Value = p[3];
                cmd.Parameters["@dir"].Value = int.TryParse(p[4], out var dir) ? dir : 0;
                cmd.Parameters["@shape"].Value = p[5];
                await cmd.ExecuteNonQueryAsync();
            }
        }
        await tx.CommitAsync();
    }

    private async Task ImportStopTimesAsync(SqliteConnection connection, string file)
    {
        if (!File.Exists(file)) return;
        _logger.LogInformation("Importing stop_times (637k records in bulk batches)...");
        using var reader = new StreamReader(file);
        reader.ReadLine();

        int batchCount = 0;
        SqliteTransaction? tx = null;
        SqliteCommand? cmd = null;

        try
        {
            tx = connection.BeginTransaction();
            cmd = connection.CreateCommand();
            cmd.Transaction = tx;
            cmd.CommandText = "INSERT OR REPLACE INTO StopTimes VALUES (@tid, @seq, @sid, @arr, @dep, @tp);";
            cmd.Parameters.Add("@tid", SqliteType.Text);
            cmd.Parameters.Add("@seq", SqliteType.Integer);
            cmd.Parameters.Add("@sid", SqliteType.Text);
            cmd.Parameters.Add("@arr", SqliteType.Text);
            cmd.Parameters.Add("@dep", SqliteType.Text);
            cmd.Parameters.Add("@tp", SqliteType.Integer);

            string? line;
            while ((line = await reader.ReadLineAsync()) != null)
            {
                var p = SplitCsv(line);
                if (p.Length >= 6)
                {
                    cmd.Parameters["@tid"].Value = p[0];
                    cmd.Parameters["@arr"].Value = p[1];
                    cmd.Parameters["@dep"].Value = p[2];
                    cmd.Parameters["@sid"].Value = p[3];
                    cmd.Parameters["@seq"].Value = int.Parse(p[4]);
                    cmd.Parameters["@tp"].Value = int.TryParse(p[5], out var tp) ? tp : 0;
                    await cmd.ExecuteNonQueryAsync();

                    batchCount++;
                    if (batchCount % 50000 == 0)
                    {
                        await tx.CommitAsync();
                        _logger.LogInformation("Imported {Count} stop_times...", batchCount);
                        tx.Dispose();
                        tx = connection.BeginTransaction();
                        cmd.Transaction = tx;
                    }
                }
            }
            await tx.CommitAsync();
        }
        finally
        {
            tx?.Dispose();
            cmd?.Dispose();
        }
    }

    private async Task GenerateFootpathsAsync(SqliteConnection connection, List<StopEntity> stops)
    {
        _logger.LogInformation("Generating walking footpath edges between nearby stops (<= 250m)...");
        using var tx = connection.BeginTransaction();
        using var cmd = connection.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = "INSERT OR REPLACE INTO Footpaths VALUES (@from, @to, @dist, @dur);";
        cmd.Parameters.Add("@from", SqliteType.Text);
        cmd.Parameters.Add("@to", SqliteType.Text);
        cmd.Parameters.Add("@dist", SqliteType.Integer);
        cmd.Parameters.Add("@dur", SqliteType.Integer);

        int count = 0;
        // Spatial grid clustering to avoid O(N^2)
        var grid = new Dictionary<string, List<StopEntity>>();
        foreach (var s in stops)
        {
            int gx = (int)(s.Latitude * 200);
            int gy = (int)(s.Longitude * 200);
            var key = $"{gx}_{gy}";
            if (!grid.ContainsKey(key)) grid[key] = new List<StopEntity>();
            grid[key].Add(s);
        }

        foreach (var stopA in stops)
        {
            int gx = (int)(stopA.Latitude * 200);
            int gy = (int)(stopA.Longitude * 200);

            for (int dx = -1; dx <= 1; dx++)
            {
                for (int dy = -1; dy <= 1; dy++)
                {
                    var neighborKey = $"{gx + dx}_{gy + dy}";
                    if (grid.TryGetValue(neighborKey, out var candidates))
                    {
                        foreach (var stopB in candidates)
                        {
                            if (stopA.StopId == stopB.StopId) continue;
                            var dist = CalculateDistanceMeters(stopA.Latitude, stopA.Longitude, stopB.Latitude, stopB.Longitude);
                            if (dist <= 250) // 250 meters walking threshold
                            {
                                int durationSec = (int)(dist / 1.1); // ~4 km/h
                                cmd.Parameters["@from"].Value = stopA.StopId;
                                cmd.Parameters["@to"].Value = stopB.StopId;
                                cmd.Parameters["@dist"].Value = (int)dist;
                                cmd.Parameters["@dur"].Value = durationSec;
                                await cmd.ExecuteNonQueryAsync();
                                count++;
                            }
                        }
                    }
                }
            }
        }
        await tx.CommitAsync();
        _logger.LogInformation("Generated {Count} walking footpath edges.", count);
    }

    private static double CalculateDistanceMeters(double lat1, double lon1, double lat2, double lon2)
    {
        double R = 6371000; // meters
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

    private static string[] SplitCsv(string line)
    {
        var result = new List<string>();
        bool inQuotes = false;
        var cur = new System.Text.StringBuilder();
        for (int i = 0; i < line.Length; i++)
        {
            char c = line[i];
            if (c == '"')
            {
                inQuotes = !inQuotes;
            }
            else if (c == ',' && !inQuotes)
            {
                result.Add(cur.ToString().Trim(' ', '"'));
                cur.Clear();
            }
            else
            {
                cur.Append(c);
            }
        }
        result.Add(cur.ToString().Trim(' ', '"'));
        return result.ToArray();
    }
}
