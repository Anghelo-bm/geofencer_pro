using System.Security.Claims;
using GeofenceSystem.Application.Interfaces;
using GeofenceSystem.Domain.Entities;
using GeofenceSystem.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;
using NetTopologySuite.IO;

namespace GeofenceSystem.API.Controllers
{
    // [Authorize] -> Bypassed
    [ApiController]
    [Route("api/[controller]")]
    public class GeofenceController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly WKTReader _wktReader;

        public GeofenceController(ApplicationDbContext context)
        {
            _context = context;
            _wktReader = new WKTReader();
        }

        [HttpGet]
        public async Task<IActionResult> GetGeofences()
        {
            var userId = "admin"; // Bypass
            var geofences = await _context.Geofences
                .Where(g => g.OwnerId == userId)
                .Select(g => new
                {
                    g.Id,
                    g.Name,
                    g.Description,
                    g.Radius,
                    Wkt = g.Boundary.ToText()
                })
                .ToListAsync();

            return Ok(geofences);
        }

        [HttpPost]
        public async Task<IActionResult> CreateGeofence([FromBody] CreateGeofenceRequest request)
        {
            var userId = "admin"; // Bypass

            try
            {
                var boundary = _wktReader.Read(request.Wkt);
                var geofence = new Geofence
                {
                    Name = request.Name,
                    Description = request.Description,
                    Boundary = boundary,
                    Radius = request.Radius,
                    OwnerId = userId
                };

                _context.Geofences.Add(geofence);
                await _context.SaveChangesAsync();

                return Ok(new { Id = geofence.Id });
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = "WKT Inválido: " + ex.Message });
            }
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateGeofence(Guid id, [FromBody] UpdateGeofenceRequest request)
        {
            var userId = "admin"; // Bypass
            var geofence = await _context.Geofences.FirstOrDefaultAsync(g => g.Id == id && g.OwnerId == userId);
            if (geofence == null) return NotFound();

            try
            {
                if (!string.IsNullOrEmpty(request.Wkt))
                {
                    geofence.Boundary = _wktReader.Read(request.Wkt);
                }
                
                await _context.SaveChangesAsync();
                return Ok();
            }
            catch (Exception ex)
            {
                return BadRequest(new { Message = "Error al actualizar WKT: " + ex.Message });
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteGeofence(Guid id)
        {
            var userId = "admin"; // Bypass
            var geofence = await _context.Geofences.FirstOrDefaultAsync(g => g.Id == id && g.OwnerId == userId);
            if (geofence == null) return NotFound();

            _context.Geofences.Remove(geofence);
            await _context.SaveChangesAsync();

            return Ok();
        }
    }

    public record CreateGeofenceRequest(string Name, string Description, string Wkt, double? Radius);
    public record UpdateGeofenceRequest(string Wkt);
}
