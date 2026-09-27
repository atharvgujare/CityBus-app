import os
import csv
import sqlite3
import time
import math

base_gtfs = r"d:\Ultimate PMPL\gtfs-data\extracted"
db_path = r"d:\Ultimate PMPL\backend\PuneBus.Api\punebus.db"

if os.path.exists(db_path):
    os.remove(db_path)

print(f"Creating database at {db_path}...")
conn = sqlite3.connect(db_path)
cur = conn.cursor()

cur.execute("PRAGMA synchronous = OFF;")
cur.execute("PRAGMA journal_mode = MEMORY;")
cur.execute("PRAGMA cache_size = 100000;")

cur.executescript("""
CREATE TABLE Agencies (
    AgencyId TEXT PRIMARY KEY,
    AgencyName TEXT NOT NULL,
    AgencyUrl TEXT,
    Timezone TEXT NOT NULL
);

CREATE TABLE Stops (
    StopId TEXT PRIMARY KEY,
    StopName TEXT NOT NULL,
    Latitude REAL NOT NULL,
    Longitude REAL NOT NULL,
    NormalizedName TEXT NOT NULL,
    IsActive INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE Routes (
    RouteId TEXT PRIMARY KEY,
    AgencyId TEXT NOT NULL,
    RouteShortName TEXT NOT NULL,
    RouteLongName TEXT NOT NULL,
    RouteType INTEGER NOT NULL
);

CREATE TABLE Calendars (
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

CREATE TABLE Trips (
    TripId TEXT PRIMARY KEY,
    RouteId TEXT NOT NULL,
    ServiceId TEXT NOT NULL,
    TripHeadsign TEXT,
    DirectionId INTEGER NOT NULL,
    ShapeId TEXT
);

CREATE TABLE StopTimes (
    TripId TEXT NOT NULL,
    StopSequence INTEGER NOT NULL,
    StopId TEXT NOT NULL,
    ArrivalTime TEXT NOT NULL,
    DepartureTime TEXT NOT NULL,
    Timepoint INTEGER NOT NULL,
    PRIMARY KEY (TripId, StopSequence)
);

CREATE TABLE Footpaths (
    FromStopId TEXT NOT NULL,
    ToStopId TEXT NOT NULL,
    WalkingDistanceMeters INTEGER NOT NULL,
    WalkingDurationSeconds INTEGER NOT NULL,
    PRIMARY KEY (FromStopId, ToStopId)
);

CREATE TABLE DataSourceVersions (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    SourceDescription TEXT NOT NULL,
    SourceUrl TEXT,
    ImportedAt TEXT NOT NULL,
    Summary TEXT,
    IsValid INTEGER NOT NULL DEFAULT 1
);
""")

def norm(s):
    return "".join(c for c in s.lower() if c.isalnum())

# 1. Agency
print("Importing agency.txt...")
with open(os.path.join(base_gtfs, "agency.txt"), encoding="utf-8") as f:
    r = csv.DictReader(f)
    cur.executemany("INSERT INTO Agencies VALUES (?, ?, ?, ?)",
                    [(row['agency_id'], row['agency_name'], row.get('agency_url'), row['agency_timezone']) for row in r])

# 2. Calendar
print("Importing calendar.txt...")
with open(os.path.join(base_gtfs, "calendar.txt"), encoding="utf-8") as f:
    r = csv.DictReader(f)
    cur.executemany("INSERT INTO Calendars VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    [(row['service_id'], int(row['monday']), int(row['tuesday']), int(row['wednesday']),
                      int(row['thursday']), int(row['friday']), int(row['saturday']), int(row['sunday']),
                      row['start_date'], row['end_date']) for row in r])

# 3. Routes
print("Importing routes.txt...")
with open(os.path.join(base_gtfs, "routes.txt"), encoding="utf-8") as f:
    r = csv.DictReader(f)
    cur.executemany("INSERT INTO Routes VALUES (?, ?, ?, ?, ?)",
                    [(row['route_id'], row['agency_id'], row['route_short_name'], row['route_long_name'], int(row['route_type'])) for row in r])

# 4. Stops
print("Importing stops.txt...")
stops_data = []
with open(os.path.join(base_gtfs, "stops.txt"), encoding="utf-8") as f:
    r = csv.DictReader(f)
    for row in r:
        stops_data.append((row['stop_id'], row['stop_name'], float(row['stop_lat']), float(row['stop_lon']), norm(row['stop_name']), 1))
cur.executemany("INSERT INTO Stops VALUES (?, ?, ?, ?, ?, ?)", stops_data)

# 5. Trips
print("Importing trips.txt...")
trips_data = []
with open(os.path.join(base_gtfs, "trips.txt"), encoding="utf-8") as f:
    r = csv.DictReader(f)
    for row in r:
        trips_data.append((row['trip_id'], row['route_id'], row['service_id'], row.get('trip_headsign'), int(row.get('direction_id', 0)), row.get('shape_id')))
cur.executemany("INSERT INTO Trips VALUES (?, ?, ?, ?, ?, ?)", trips_data)

# 6. StopTimes
print("Importing stop_times.txt (637k records)...")
t0 = time.time()
with open(os.path.join(base_gtfs, "stop_times.txt"), encoding="utf-8") as f:
    r = csv.DictReader(f)
    batch = []
    count = 0
    for row in r:
        batch.append((row['trip_id'], int(row['stop_sequence']), row['stop_id'], row['arrival_time'], row['departure_time'], int(row.get('timepoint', 0))))
        count += 1
        if len(batch) >= 50000:
            cur.executemany("INSERT INTO StopTimes VALUES (?, ?, ?, ?, ?, ?)", batch)
            batch = []
    if batch:
        cur.executemany("INSERT INTO StopTimes VALUES (?, ?, ?, ?, ?, ?)", batch)
print(f"StopTimes imported ({count} rows) in {time.time() - t0:.2f}s")

# 7. Footpaths (Walk transfer edges <= 300m)
print("Computing walking transfer footpaths (<= 300m)...")
def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon/2)**2
    return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a))

grid = {}
for sid, name, lat, lon, nname, _ in stops_data:
    gx = int(lat * 200)
    gy = int(lon * 200)
    key = f"{gx}_{gy}"
    grid.setdefault(key, []).append((sid, lat, lon))

footpaths = []
for sid1, name, lat1, lon1, nname, _ in stops_data:
    gx = int(lat1 * 200)
    gy = int(lon1 * 200)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            cand_key = f"{gx + dx}_{gy + dy}"
            for sid2, lat2, lon2 in grid.get(cand_key, []):
                if sid1 != sid2:
                    dist = haversine(lat1, lon1, lat2, lon2)
                    if dist <= 300: # 300 meters max transfer walk
                        dur = int(dist / 1.1)
                        footpaths.append((sid1, sid2, int(dist), dur))

cur.executemany("INSERT INTO Footpaths VALUES (?, ?, ?, ?)", footpaths)
print(f"Created {len(footpaths)} transfer footpaths.")

# 8. Indexes
print("Creating indexes...")
cur.executescript("""
CREATE INDEX IX_Stops_Normalized ON Stops(NormalizedName);
CREATE INDEX IX_Stops_Coords ON Stops(Latitude, Longitude);
CREATE INDEX IX_Routes_ShortName ON Routes(RouteShortName);
CREATE INDEX IX_Trips_RouteId ON Trips(RouteId);
CREATE INDEX IX_StopTimes_Stop_Dept ON StopTimes(StopId, DepartureTime);
CREATE INDEX IX_StopTimes_Trip ON StopTimes(TripId);
CREATE INDEX IX_Footpaths_From ON Footpaths(FromStopId);

INSERT INTO DataSourceVersions (SourceDescription, SourceUrl, ImportedAt, Summary, IsValid)
VALUES ('PMPML GTFS Static Feed', 'https://github.com/croyla/pmpml-gtfs.git', datetime('now'), 'Initial SQLite seed', 1);
""")

conn.commit()
conn.close()

db_size_mb = os.path.getsize(db_path) / (1024 * 1024)
print(f"SUCCESS! Database created at {db_path} (Size: {db_size_mb:.2f} MB)")
