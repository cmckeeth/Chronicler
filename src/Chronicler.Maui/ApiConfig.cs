namespace Chronicler.Maui;

public static class ApiConfig
{
    public const string BaseUrl = "http://192.168.1.71:5160";

    public const string HealthUrl = BaseUrl + "/api/health";
    public const string UpdateVersionUrl = BaseUrl + "/api/update/version";
    public const string UpdateApkUrl = BaseUrl + "/api/update/apk";
}
