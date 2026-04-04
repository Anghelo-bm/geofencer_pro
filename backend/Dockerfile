FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy solution and restore projects
COPY ["GeofenceSystem.sln", "./"]
COPY ["GeofenceSystem.API/GeofenceSystem.API.csproj", "GeofenceSystem.API/"]
COPY ["GeofenceSystem.Application/GeofenceSystem.Application.csproj", "GeofenceSystem.Application/"]
COPY ["GeofenceSystem.Domain/GeofenceSystem.Domain.csproj", "GeofenceSystem.Domain/"]
COPY ["GeofenceSystem.Infrastructure/GeofenceSystem.Infrastructure.csproj", "GeofenceSystem.Infrastructure/"]

RUN dotnet restore

# Copy everything and build
COPY . .
WORKDIR /src/GeofenceSystem.API
RUN dotnet publish -c Release -o /app/publish /p:UseAppHost=false

# Runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "GeofenceSystem.API.dll"]
