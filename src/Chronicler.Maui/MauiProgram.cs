using Chronicler.Maui.Services;
using Chronicler.Shared.Services;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;

namespace Chronicler.Maui;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .ConfigureFonts(fonts =>
            {
                fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
            })
            .ConfigureMauiHandlers(handlers =>
            {
#if ANDROID || IOS
                handlers.AddHandler<Microsoft.AspNetCore.Components.WebView.Maui.BlazorWebView, ChroniclerWebViewHandler>();
#endif
            });

        // Load stored token before first render so AuthState is correct immediately
        var tokenStorage = new SecureTokenStorage();
        var authState = new AuthState();
        try
        {
            var token = SecureStorage.Default.GetAsync("chronicler_token").GetAwaiter().GetResult();
            if (token is not null)
                authState.SetToken(token);
        }
        catch { /* SecureStorage unavailable — start unauthenticated */ }

        builder.Services.AddMauiBlazorWebView();
#if ANDROID
        builder.Services.AddSingleton<IAudioPlayerService, NativeAudioPlayerService>();
#elif IOS
        builder.Services.AddSingleton<IAudioPlayerService, iOSAudioPlayerService>();
#endif
        builder.Services.AddSingleton<IDownloadService, MauiDownloadService>();
        builder.Services.AddSingleton<ITokenStorage>(tokenStorage);
        builder.Services.AddSingleton(authState);
        builder.Services.AddScoped<ApiClient>(sp =>
        {
            var auth = sp.GetRequiredService<AuthState>();
            var http = new HttpClient { BaseAddress = new Uri(ApiConfig.BaseUrl.TrimEnd('/') + "/") };
            return new ApiClient(http, auth);
        });

#if DEBUG
        builder.Services.AddBlazorWebViewDeveloperTools();
        builder.Logging.AddDebug();
#endif

        return builder.Build();
    }
}
