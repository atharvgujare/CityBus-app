using Microsoft.AspNetCore.Mvc;
using PuneBus.Api.Models.Dtos;
using PuneBus.Api.Services;

namespace PuneBus.Api.Controllers;

[ApiController]
[Route("api/v1/[controller]")]
public class JourneysController : ControllerBase
{
    private readonly ITransitRoutingEngine _routingEngine;
    private readonly ILogger<JourneysController> _logger;

    public JourneysController(ITransitRoutingEngine routingEngine, ILogger<JourneysController> logger)
    {
        _routingEngine = routingEngine;
        _logger = logger;
    }

    /// <summary>
    /// Plans a journey between an origin and destination using PMPML bus routes.
    /// </summary>
    [HttpPost("plan")]
    [ProducesResponseType(typeof(JourneyPlanResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> PlanJourney([FromBody] JourneyPlanRequest request, CancellationToken cancellationToken)
    {
        if (request == null ||
            (string.IsNullOrWhiteSpace(request.Origin.Name) && request.Origin.Latitude == 0) ||
            (string.IsNullOrWhiteSpace(request.Destination.Name) && request.Destination.Latitude == 0))
        {
            return BadRequest("Both Origin and Destination must be provided.");
        }

        var result = await _routingEngine.PlanJourneyAsync(request, cancellationToken);
        return Ok(result);
    }

    /// <summary>
    /// Returns only the boarding stops near origin that have buses to destination,
    /// and drop-off stops near destination where those buses arrive.
    /// </summary>
    [HttpPost("viable-stops")]
    [ProducesResponseType(typeof(ViableStopsResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetViableStops([FromBody] JourneyPlanRequest request, CancellationToken cancellationToken)
    {
        if (request == null) return BadRequest("Request body is required.");
        var result = await _routingEngine.GetViableStopsAsync(request, cancellationToken);
        return Ok(result);
    }
}
