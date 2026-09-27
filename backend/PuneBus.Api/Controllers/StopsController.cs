using Microsoft.AspNetCore.Mvc;
using PuneBus.Api.Models.Dtos;
using PuneBus.Api.Services;

namespace PuneBus.Api.Controllers;

[ApiController]
[Route("api/v1/[controller]")]
public class StopsController : ControllerBase
{
    private readonly ITransitRoutingEngine _routingEngine;

    public StopsController(ITransitRoutingEngine routingEngine)
    {
        _routingEngine = routingEngine;
    }

    /// <summary>
    /// Finds nearby PMPML stops given GPS coordinates.
    /// </summary>
    [HttpGet("nearby")]
    [ProducesResponseType(typeof(List<StopDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetNearbyStops([FromQuery] double lat, [FromQuery] double lon, [FromQuery] double radius = 800)
    {
        var stops = await _routingEngine.GetNearbyStopsAsync(lat, lon, radius);
        return Ok(stops);
    }

    /// <summary>
    /// Searches stops by name or landmark.
    /// </summary>
    [HttpGet("search")]
    [ProducesResponseType(typeof(List<StopDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> SearchStops([FromQuery] string q, [FromQuery] int limit = 15)
    {
        var stops = await _routingEngine.SearchStopsAsync(q, limit);
        return Ok(stops);
    }
}
