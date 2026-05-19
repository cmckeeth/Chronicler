namespace Chronicler.Maui;

public static class ApiConfig
{
#if DEBUG
    public const string BaseUrl = "http://localhost:5160";
#else
    // Change this to your server's IP/hostname before deploying
    public const string BaseUrl = "http://192.168.1.100:5160";
#endif

    public const string HealthUrl = BaseUrl + "/api/health";
    public const string UpdateVersionUrl = BaseUrl + "/api/update/version";
    public const string UpdateApkUrl = BaseUrl + "/api/update/apk";
}
