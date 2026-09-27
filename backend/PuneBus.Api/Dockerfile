# ---- Build Stage ----
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY ["PuneBus.Api.csproj", "./"]
RUN dotnet restore

COPY . .
RUN dotnet publish -c Release -o /app/publish

# ---- Runtime Stage ----
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app

COPY --from=build /app/publish .
# Copy the SQLite database into the image
COPY ["punebus.db", "/app/punebus.db"]

EXPOSE 8080 10000 5178

ENTRYPOINT ["dotnet", "PuneBus.Api.dll"]
