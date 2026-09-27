using Microsoft.AspNetCore.Mvc;
using PuneBus.Api.Models.Dtos;
using PuneBus.Api.Services;

namespace PuneBus.Api.Controllers;

[ApiController]
[Route("api/v1/[controller]")]
public class RoutesController : ControllerBase
{
    private readonly ITransitRoutingEngine _routingEngine;

    public RoutesController(ITransitRoutingEngine routingEngine)
    {
        _routingEngine = routingEngine;
    }

    /// <summary>
    /// Searches bus routes by number or terminal names.
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(List<RouteDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetRoutes([FromQuery] string? q = null, [FromQuery] int limit = 20)
    {
        var routes = await _routingEngine.GetRoutesAsync(q, limit);
        return Ok(routes);
    }

    /// <summary>
    /// Gets route details including full stops and scheduled timetable.
    /// </summary>
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(RouteDetailsDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetRouteDetails(string id)
    {
        var details = await _routingEngine.GetRouteDetailsAsync(id);
        if (details == null) return NotFound($"Route '{id}' not found.");
        return Ok(details);
    }
}
