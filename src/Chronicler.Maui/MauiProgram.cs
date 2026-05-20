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
#if ANDROID
                handlers.AddHandler<Microsoft.AspNetCore.Components.WebView.Maui.BlazorWebView, ChroniclerWebViewHandler>();
#endif
            });

        builder.Services.AddMauiBlazorWebView();
        builder.Services.AddSingleton<IAudioPlayerService, NativeAudioPlayerService>();
        builder.Services.AddSingleton<ITokenStorage, SecureTokenStorage>();
        builder.Services.AddSingleton<AuthState>();
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
