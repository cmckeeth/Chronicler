using System.Text.Json;

namespace Chronicler.Maui;

public static class ApiConfig
{
    private static string? _baseUrl;

    public static string BaseUrl => _baseUrl ??= LoadBaseUrl();

    public static string HealthUrl => BaseUrl + "/api/health";
    public static string UpdateVersionUrl => BaseUrl + "/api/update/version";
    public static string UpdateApkUrl => BaseUrl + "/api/update/apk";

    private static string LoadBaseUrl()
    {
        try
        {
            using var stream = FileSystem.OpenAppPackageFileAsync("appsettings.json").GetAwaiter().GetResult();
            using var reader = new StreamReader(stream);
            var json = reader.ReadToEnd();
            var doc = JsonDocument.Parse(json);
            if (doc.RootElement.TryGetProperty("ApiBaseUrl", out var val))
                return val.GetString()!.TrimEnd('/');
        }
        catch { }
        return "https://chronicler.mckeeth.app"; // fallback
    }
}
