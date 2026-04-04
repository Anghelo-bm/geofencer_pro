using System.Text;
using GeofenceSystem.Application.Interfaces;
using GeofenceSystem.Domain.Entities;
using GeofenceSystem.Infrastructure.Data;
using GeofenceSystem.Infrastructure.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

// --- CORS Configuration ---
builder.Services.AddCors(options => {
    options.AddDefaultPolicy(policy => {
        policy.AllowAnyHeader()
              .AllowAnyMethod()
              .SetIsOriginAllowed((host) => true)
              .AllowCredentials();
    });
});

// --- Serilog Setup ---
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .WriteTo.File("logs/geofence-api-.log", rollingInterval: RollingInterval.Day)
    .CreateLogger();

builder.Host.UseSerilog();

// --- Database Configuration (PostGIS) ---
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection") 
    ?? "Host=localhost;Database=geofencing_db;Username=postgres;Password=postgres";

builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseNpgsql(connectionString, x => x.UseNetTopologySuite()));

// --- Identity Configuration ---
builder.Services.AddIdentity<User, IdentityRole>(options => {
    options.Password.RequireDigit = false;
    options.Password.RequiredLength = 6;
    options.Password.RequireNonAlphanumeric = false;
    options.Password.RequireUppercase = false;
})
.AddEntityFrameworkStores<ApplicationDbContext>()
.AddDefaultTokenProviders();

// --- JWT Authentication ---
var jwtKey = builder.Configuration["Jwt:Key"] ?? "SUPER_SECRET_KEY_FOR_JWT_GEOFENCING_SYSTEM";
var key = Encoding.UTF8.GetBytes(jwtKey);

builder.Services.AddAuthentication(options => {
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options => {
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = builder.Configuration["Jwt:Issuer"] ?? "GeofenceSystem",
        ValidAudience = builder.Configuration["Jwt:Audience"] ?? "GeofenceSystem",
        IssuerSigningKey = new SymmetricSecurityKey(key)
    };
});

// --- Dependency Injection ---
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IGeofenceService, GeofenceService>();

// --- SignalR for Real-time ---
builder.Services.AddSignalR();

builder.Services.AddControllers();

// --- Swagger Configuration ---
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "Geofencing Monitoring API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        In = ParameterLocation.Header,
        Description = "Please insert JWT with Bearer into field",
        Name = "Authorization",
        Type = SecuritySchemeType.ApiKey
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement {
       {
         new OpenApiSecurityScheme
         {
           Reference = new OpenApiReference
           {
             Type = ReferenceType.SecurityScheme,
             Id = "Bearer"
           }
          },
          new string[] { }
        }
    });
});

var app = builder.Build();

// --- Middleware Pipeline ---
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

using (var scope = app.Services.CreateScope())
{
    // var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    // context.Database.EnsureCreated(); // SUPABASE PGBOUNCER CRASHES HERE (Status 139). SCHEMA IS ALREADY CREATED.
    
    try {
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<User>>();
        if (await userManager.FindByIdAsync("admin") == null)
        {
            await userManager.CreateAsync(new User { Id = "admin", UserName = "admin", Email = "admin@example.com" });
        }
    } catch (Exception ex) {
        Console.WriteLine($"Auth Setup skipped: {ex.Message}");
    }
}

// app.UseHttpsRedirection(); // Removed for easy Docker internal connectivity

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// Hub definition would go here or separate file
// Hub definition
app.MapHub<GeofenceSystem.API.Hubs.MonitoringHub>("/monitoringHub");

app.Run();
