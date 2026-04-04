using GeofenceSystem.Domain.Entities;
using GeofenceSystem.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GeofenceSystem.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class EventController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public EventController(ApplicationDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> GetRecentEvents([FromQuery] int limit = 20)
        {
            var events = await _context.GeofenceEvents
                .Include(e => e.Geofence)
                .OrderByDescending(e => e.Timestamp)
                .Take(limit)
                .Select(e => new {
                    e.Id,
                    e.Type,
                    TypeName = e.Type.ToString(),
                    e.UserId,
                    e.GeofenceId,
                    GeofenceName = e.Geofence.Name,
                    e.Timestamp
                })
                .ToListAsync();

            return Ok(events);
        }
    }
}
