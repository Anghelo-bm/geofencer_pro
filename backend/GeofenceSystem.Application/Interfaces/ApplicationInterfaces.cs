using GeofenceSystem.Domain.Entities;
using NetTopologySuite.Geometries;

namespace GeofenceSystem.Application.Interfaces
{
    public interface IGeofenceService
    {
        Task<bool> IsWithinGeofence(Point location, Geofence geofence);
        Task<List<Geofence>> GetActiveGeofencesForUser(string userId);
        Task<GeofenceEvent?> ProcessLocationUpdate(string userId, Point location);
    }

    public interface IAuthService
    {
        Task<(bool success, string token, string? error)> Login(string email, string password);
        Task<(bool success, string? error)> Register(string email, string password, string fullName);
    }
}
