using System.Security.Claims;
using GeofenceSystem.Application.Interfaces;
using GeofenceSystem.Domain.Entities;
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

        // Caché en memoria para evitar caídas por la base de datos y sobrevivir a los F5
        private static readonly System.Collections.Concurrent.ConcurrentDictionary<string, object> _activeLocations = new();

        [HttpPost("ping")]
        public async Task<IActionResult> Ping([FromBody] PingRequest request)
        {
            try
            {
                var userId = "admin";
                var deviceId = request.DeviceId ?? "Dispositivo";

                var location = new Point(request.Longitude, request.Latitude) { SRID = 4326 };
                
                GeofenceEvent? geofenceEvent = null;

                try 
                {
                    geofenceEvent = await _geofenceService.ProcessLocationUpdate(userId, location);
                } 
                catch (Exception dbEx) 
                {
                    Console.WriteLine($"[Geofence DB Error] {dbEx.Message}");
                }

                var locationData = new {
                    userId = deviceId,
                    latitude = request.Latitude,
                    longitude = request.Longitude,
                    speed = request.Speed,
                    @event = geofenceEvent?.Type.ToString() ?? "Ninguno",
                    timestamp = DateTime.UtcNow
                };

                // Guardar en RAM para F5
                _activeLocations[deviceId] = locationData;

                await _hubContext.Clients.All.SendAsync("ReceiveLocationUpdate", locationData);

                return Ok(new { 
                    Status = "Recibido", 
                    Event = geofenceEvent?.Type.ToString() ?? "Ninguno" 
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Error = ex.Message });
            }
        }

        [HttpGet("all")]
        public IActionResult GetAllActiveLocations()
        {
            // Devolver directamente la RAM sin tocar la BD rota
            return Ok(_activeLocations.Values);
        }
    }

    public record PingRequest(double Latitude, double Longitude, double Accuracy, double Speed, string? DeviceId);
}
