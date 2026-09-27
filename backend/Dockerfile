# Build stage
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY ["PuneBus.Api/PuneBus.Api.csproj", "PuneBus.Api/"]
RUN dotnet restore "PuneBus.Api/PuneBus.Api.csproj"

COPY . .
WORKDIR "/src/PuneBus.Api"
RUN dotnet publish "PuneBus.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
# Include seeded database if present
COPY PuneBus.Api/punebus.db* /app/

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENV ConnectionStrings__DefaultConnection="Data Source=punebus.db"

ENTRYPOINT ["dotnet", "PuneBus.Api.dll"]
