using System.Security.Claims;
using GeofenceSystem.Application.Interfaces;
using GeofenceSystem.Infrastructure.Data;
using GeofenceSystem.API.Hubs;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using NetTopologySuite.Geometries;

namespace GeofenceSystem.API.Controllers
{
    // [Authorize] -> Bypassed para etapa de testeo libre
    [ApiController]
    [Route("api/[controller]")]
    public class LocationController : ControllerBase
    {
        private readonly IGeofenceService _geofenceService;
        private readonly IHubContext<MonitoringHub> _hubContext;

        public LocationController(IGeofenceService geofenceService, IHubContext<MonitoringHub> hubContext)
        {
            _geofenceService = geofenceService;
            _hubContext = hubContext;
        }

        [HttpPost("ping")]
        public async Task<IActionResult> Ping([FromBody] PingRequest request)
        {
            try
            {
                // Bypass de usuario
                var userId = "admin";

                var location = new Point(request.Longitude, request.Latitude) { SRID = 4326 };
                
                // Procesa si entró o salió de un polígono registrado a "admin"
                var geofenceEvent = await _geofenceService.ProcessLocationUpdate(userId, location);

                // Transmitimos a todos los monitores web (React) conectados en vivo 
                await _hubContext.Clients.All.SendAsync("ReceiveLocationUpdate", new {
                    userId = request.DeviceId ?? "Dispositivo",
                    latitude = request.Latitude,
                    longitude = request.Longitude,
                    speed = request.Speed,
                    @event = geofenceEvent?.Type.ToString()
                });

                return Ok(new { 
                    Status = "Recibido", 
                    Event = geofenceEvent?.Type.ToString() ?? "Ninguno" 
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Error = ex.Message, Inner = ex.InnerException?.Message, StackTrace = ex.StackTrace });
            }
        }

        [HttpGet("all")]
        public async Task<IActionResult> GetAllActiveLocations([FromServices] ApplicationDbContext dbContext)
        {
            // Agrupar por UserId y tomar la más reciente
            var latestLocations = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.ToListAsync(
                dbContext.LocationHistories
                    .GroupBy(p => p.UserId)
                    .Select(g => g.OrderByDescending(p => p.Timestamp).FirstOrDefault())
            );

            var result = latestLocations.Where(l => l != null).Select(l => new {
                userId = l!.UserId,
                lat = l.Coordinate.Y,
                lon = l.Coordinate.X,
                speed = l.Speed,
                timestamp = l.Timestamp
            });

            return Ok(result);
        }
    }

    public record PingRequest(double Latitude, double Longitude, double Accuracy, double Speed, string? DeviceId);
}
