using Microsoft.AspNetCore.Identity;
using NetTopologySuite.Geometries;

namespace GeofenceSystem.Domain.Entities
{
    public class User : IdentityUser
    {
        public string? FullName { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }

    public class Geofence
    {
        public Guid Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public Geometry Boundary { get; set; } = default!; // Polygon or Point for circle
        public double? Radius { get; set; } // If circle
        public string OwnerId { get; set; } = string.Empty;
        public User Owner { get; set; } = default!;
        public bool IsActive { get; set; } = true;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }

    public class LocationPing
    {
        public long Id { get; set; }
        public Point Coordinate { get; set; } = default!;
        public double Speed { get; set; }
        public double Accuracy { get; set; }
        public string UserId { get; set; } = string.Empty;
        public User User { get; set; } = default!;
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    }

    public enum EventType
    {
        Enter,
        Exit,
        OutsideTooLong,
        SuspiciousMovement
    }

    public class GeofenceEvent
    {
        public Guid Id { get; set; }
        public EventType Type { get; set; }
        public string UserId { get; set; } = string.Empty;
        public User User { get; set; } = default!;
        public Guid GeofenceId { get; set; }
        public Geofence Geofence { get; set; } = default!;
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    }
}
