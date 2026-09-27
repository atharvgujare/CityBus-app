using Microsoft.EntityFrameworkCore;
using PuneBus.Api.Data.Entities;

namespace PuneBus.Api.Data;

public class PuneBusDbContext : DbContext
{
    public PuneBusDbContext(DbContextOptions<PuneBusDbContext> options) : base(options)
    {
    }

    public DbSet<Agency> Agencies => Set<Agency>();
    public DbSet<RouteEntity> Routes => Set<RouteEntity>();
    public DbSet<StopEntity> Stops => Set<StopEntity>();
    public DbSet<CalendarEntity> Calendars => Set<CalendarEntity>();
    public DbSet<TripEntity> Trips => Set<TripEntity>();
    public DbSet<StopTimeEntity> StopTimes => Set<StopTimeEntity>();
    public DbSet<FootpathEntity> Footpaths => Set<FootpathEntity>();
    public DbSet<DataSourceVersion> DataSourceVersions => Set<DataSourceVersion>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Agency>(entity =>
        {
            entity.HasKey(e => e.AgencyId);
            entity.Property(e => e.AgencyName).IsRequired().HasMaxLength(255);
        });

        modelBuilder.Entity<StopEntity>(entity =>
        {
            entity.HasKey(e => e.StopId);
            entity.Property(e => e.StopName).IsRequired().HasMaxLength(255);
            entity.HasIndex(e => e.NormalizedName);
            entity.HasIndex(e => new { e.Latitude, e.Longitude });
        });

        modelBuilder.Entity<RouteEntity>(entity =>
        {
            entity.HasKey(e => e.RouteId);
            entity.Property(e => e.RouteShortName).IsRequired().HasMaxLength(50);
            entity.HasIndex(e => e.RouteShortName);
        });

        modelBuilder.Entity<CalendarEntity>(entity =>
        {
            entity.HasKey(e => e.ServiceId);
        });

        modelBuilder.Entity<TripEntity>(entity =>
        {
            entity.HasKey(e => e.TripId);
            entity.HasIndex(e => e.RouteId);
            entity.HasOne(e => e.Route)
                  .WithMany(r => r.Trips)
                  .HasForeignKey(e => e.RouteId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<StopTimeEntity>(entity =>
        {
            entity.HasKey(e => new { e.TripId, e.StopSequence });
            entity.HasIndex(e => new { e.StopId, e.DepartureTime });
            entity.HasOne(e => e.Trip)
                  .WithMany(t => t.StopTimes)
                  .HasForeignKey(e => e.TripId)
                  .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(e => e.Stop)
                  .WithMany(s => s.StopTimes)
                  .HasForeignKey(e => e.StopId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<FootpathEntity>(entity =>
        {
            entity.HasKey(e => new { e.FromStopId, e.ToStopId });
        });
    }
}
