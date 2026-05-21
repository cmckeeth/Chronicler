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

        // Intercept cover image requests from the WebView
        var existing = view.GetWebViewClient();
        view.SetWebViewClient(new ProxyWebViewClient(existing));

        return view;
    }
}

/// <summary>
/// Wraps MAUI's internal WebViewClient to intercept cover image requests,
/// fetching them natively to bypass cross-origin restrictions.
/// All other requests go through the original client unchanged.
/// </summary>
internal class ProxyWebViewClient(WebViewClient? inner) : WebViewClient
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(10) };

    public override WebResourceResponse? ShouldInterceptRequest(
        Android.Webkit.WebView? view, IWebResourceRequest? request)
    {
        var url = request?.Url?.ToString();

        if (url is not null &&
            url.StartsWith(ApiConfig.BaseUrl, StringComparison.OrdinalIgnoreCase) &&
            url.Contains("/cover", StringComparison.OrdinalIgnoreCase))
        {
            try
            {
                var bytes = Http.GetByteArrayAsync(url).GetAwaiter().GetResult();
                var mime = url.EndsWith(".png", StringComparison.OrdinalIgnoreCase) ? "image/png" : "image/jpeg";
                return new WebResourceResponse(mime, "utf-8", new MemoryStream(bytes));
            }
            catch
            {
                // Fall through to default handling
            }
        }

        return inner?.ShouldInterceptRequest(view, request)
               ?? base.ShouldInterceptRequest(view, request);
    }

    public override void OnPageStarted(Android.Webkit.WebView? view, string? url, Android.Graphics.Bitmap? favicon)
        => inner?.OnPageStarted(view, url, favicon) ?? base.OnPageStarted(view, url, favicon);

    public override void OnPageFinished(Android.Webkit.WebView? view, string? url)
        => inner?.OnPageFinished(view, url) ?? base.OnPageFinished(view, url);

    public override bool ShouldOverrideUrlLoading(Android.Webkit.WebView? view, IWebResourceRequest? request)
        => inner?.ShouldOverrideUrlLoading(view, request) ?? base.ShouldOverrideUrlLoading(view, request);
}
