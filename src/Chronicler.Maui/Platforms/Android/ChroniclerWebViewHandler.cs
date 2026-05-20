using Android.Webkit;
using Microsoft.AspNetCore.Components.WebView.Maui;
using Microsoft.Maui.Handlers;

namespace Chronicler.Maui;

public class ChroniclerWebViewHandler : BlazorWebViewHandler
{
    protected override Android.Webkit.WebView CreatePlatformView()
    {
        var view = base.CreatePlatformView();
        view.Settings.MediaPlaybackRequiresUserGesture = false;
        view.Settings.AllowFileAccess = true;
        view.Settings.AllowContentAccess = true;
        view.Settings.MixedContentMode = MixedContentHandling.AlwaysAllow;
        view.SetWebViewClient(new ChroniclerWebViewClient());
        return view;
    }
}

/// <summary>
/// Intercepts requests to our API server (e.g. cover images) and proxies
/// them natively so the WebView's cross-origin restrictions don't block them.
/// </summary>
internal class ChroniclerWebViewClient : WebViewClient
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(10) };

    public override WebResourceResponse? ShouldInterceptRequest(
        Android.Webkit.WebView? view, IWebResourceRequest? request)
    {
        var url = request?.Url?.ToString();
        if (url is null) return base.ShouldInterceptRequest(view, request);

        // Intercept requests to our API server
        if (url.StartsWith(ApiConfig.BaseUrl, StringComparison.OrdinalIgnoreCase))
        {
            try
            {
                var bytes = Http.GetByteArrayAsync(url).GetAwaiter().GetResult();
                var mime = GuessMime(url);
                return new WebResourceResponse(mime, "utf-8", new MemoryStream(bytes));
            }
            catch
            {
                return base.ShouldInterceptRequest(view, request);
            }
        }

        return base.ShouldInterceptRequest(view, request);
    }

    private static string GuessMime(string url)
    {
        if (url.Contains("/cover")) return "image/jpeg";
        if (url.Contains(".png")) return "image/png";
        if (url.Contains(".jpg") || url.Contains(".jpeg")) return "image/jpeg";
        return "application/octet-stream";
    }
}
