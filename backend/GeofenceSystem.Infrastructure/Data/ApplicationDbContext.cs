using GeofenceSystem.Domain.Entities;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace GeofenceSystem.Infrastructure.Data
{
    public class ApplicationDbContext : IdentityDbContext<User>
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
            : base(options)
        {
        }

        public DbSet<Geofence> Geofences { get; set; } = default!;
        public DbSet<LocationPing> LocationHistories { get; set; } = default!;
        public DbSet<GeofenceEvent> GeofenceEvents { get; set; } = default!;

        protected override void OnModelCreating(ModelBuilder builder)
        {
            base.OnModelCreating(builder);

            // Geospatial Indexing for Geofences
            builder.Entity<Geofence>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.HasOne(e => e.Owner)
                      .WithMany()
                      .HasForeignKey(e => e.OwnerId);
            });

            // Geospatial Indexing for Locations
            builder.Entity<LocationPing>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.HasOne(e => e.User)
                      .WithMany()
                      .HasForeignKey(e => e.UserId);
            });

            // Geofence Events
            builder.Entity<GeofenceEvent>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.HasOne(e => e.User)
                      .WithMany()
                      .HasForeignKey(e => e.UserId);
                entity.HasOne(e => e.Geofence)
                      .WithMany()
                      .HasForeignKey(e => e.GeofenceId);
            });
        }
    }
}
