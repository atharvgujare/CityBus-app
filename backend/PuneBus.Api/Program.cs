using Microsoft.EntityFrameworkCore;
using PuneBus.Api.Data;
using PuneBus.Api.Services;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

// Dynamically bind to Render's PORT environment variable (or default 5178 for local)
var port = Environment.GetEnvironmentVariable("PORT") ?? "5178";
builder.WebHost.UseUrls($"http://0.0.0.0:{port}");

// Add Database Context (SQLite)
var dbPath = builder.Configuration.GetConnectionString("DefaultConnection") ?? "Data Source=punebus.db";
builder.Services.AddDbContext<PuneBusDbContext>(options =>
    options.UseSqlite(dbPath));

// Add Transit Services
builder.Services.AddSingleton<IGtfsImporterService, GtfsImporterService>();
builder.Services.AddSingleton<ITransitRoutingEngine, TransitRoutingEngine>();

// Add Controllers & Modern .NET 9 OpenAPI
builder.Services.AddControllers();
builder.Services.AddOpenApi();

// Configure CORS for Mobile & Web clients
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

app.MapOpenApi();
app.MapScalarApiReference(options =>
{
    options.WithTitle("PuneBus PMPML API Reference");
});

app.UseCors("AllowAll");
app.UseAuthorization();
app.MapControllers();

// Initialize In-Memory Transit Graph on startup
using (var scope = app.Services.CreateScope())
{
    var routingEngine = scope.ServiceProvider.GetRequiredService<ITransitRoutingEngine>();
    await routingEngine.InitializeAsync();
}

app.Run();
