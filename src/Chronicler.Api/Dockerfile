FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish src/Chronicler.Api/Chronicler.Api.csproj -c Release -o /app

FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app .
RUN mkdir -p Library updates
EXPOSE 5160
ENTRYPOINT ["dotnet", "Chronicler.Api.dll"]
