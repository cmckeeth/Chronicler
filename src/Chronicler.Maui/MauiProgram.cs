using Chronicler.Shared.Services;
using Microsoft.Extensions.Logging;

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
        builder.Services.AddScoped<ApiClient>(_ =>
            new ApiClient(new HttpClient { BaseAddress = new Uri(ApiConfig.BaseUrl.TrimEnd('/') + "/") }));

#if DEBUG
        builder.Services.AddBlazorWebViewDeveloperTools();
        builder.Logging.AddDebug();
#endif

        return builder.Build();
    }
}
