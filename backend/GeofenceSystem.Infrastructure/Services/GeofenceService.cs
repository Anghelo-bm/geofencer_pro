using GeofenceSystem.Application.Interfaces;
using GeofenceSystem.Domain.Entities;
using GeofenceSystem.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;

namespace GeofenceSystem.Infrastructure.Services
{
    public class GeofenceService : IGeofenceService
    {
        private readonly ApplicationDbContext _context;

        public GeofenceService(ApplicationDbContext context)
        {
            _context = context;
        }

        public async Task<List<Geofence>> GetActiveGeofencesForUser(string userId)
        {
            return await _context.Geofences
                .Where(g => g.OwnerId == userId && g.IsActive)
                .ToListAsync();
        }

        public async Task<bool> IsWithinGeofence(Point location, Geofence geofence)
        {
            if (geofence.Boundary == null) return false;
            
            // Check if boundary contains location
            // NTS Contains works for polygons
            return geofence.Boundary.Contains(location);
        }

        public async Task<GeofenceEvent?> ProcessLocationUpdate(string userId, Point location)
        {
            // 1. Get previous location to detect state change
            var lastPing = await _context.LocationHistories
                .Where(l => l.UserId == userId)
                .OrderByDescending(l => l.Timestamp)
                .FirstOrDefaultAsync();

            // 2. Log current location
            var ping = new LocationPing
            {
                UserId = userId,
                Coordinate = location,
                Timestamp = DateTime.UtcNow
            };
            _context.LocationHistories.Add(ping);
            await _context.SaveChangesAsync();

            // 3. Check geofences
            var activeGeofences = await GetActiveGeofencesForUser("admin"); // Assume admin owns all for testing
            
            foreach (var gf in activeGeofences)
            {
                bool isCurrentlyInside = await IsWithinGeofence(location, gf);
                bool wasInsideBefore = lastPing != null && await IsWithinGeofence(lastPing.Coordinate, gf);

                if (isCurrentlyInside && !wasInsideBefore)
                {
                    // ENTER Event
                    var geofenceEvent = new GeofenceEvent
                    {
                        UserId = userId,
                        GeofenceId = gf.Id,
                        Type = EventType.Enter,
                        Timestamp = DateTime.UtcNow
                    };
                    _context.GeofenceEvents.Add(geofenceEvent);
                    await _context.SaveChangesAsync();
                    return geofenceEvent;
                }
                else if (!isCurrentlyInside && wasInsideBefore)
                {
                    // EXIT Event
                    var geofenceEvent = new GeofenceEvent
                    {
                        UserId = userId,
                        GeofenceId = gf.Id,
                        Type = EventType.Exit,
                        Timestamp = DateTime.UtcNow
                    };
                    _context.GeofenceEvents.Add(geofenceEvent);
                    await _context.SaveChangesAsync();
                    return geofenceEvent;
                }
            }

            return null;
        }
    }
}
