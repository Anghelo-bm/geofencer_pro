using Microsoft.AspNetCore.SignalR;

namespace GeofenceSystem.API.Hubs
{
    public class MonitoringHub : Hub
    {
        public async Task JoinMonitoringGroup(string adminId)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, "Administrators");
        }

        public async Task SendLocationUpdate(string userId, double lat, double lon, string? eventType)
        {
            await Clients.Group("Administrators").SendAsync("ReceiveLocationUpdate", new
            {
                UserId = userId,
                Latitude = lat,
                Longitude = lon,
                Event = eventType,
                Timestamp = DateTime.UtcNow
            });
        }
    }
}
