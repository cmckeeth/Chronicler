using Microsoft.AspNetCore.Components.WebView.Maui;
using Microsoft.Maui.Handlers;
using WebKit;

namespace Chronicler.Maui;

public class ChroniclerWebViewHandler : BlazorWebViewHandler
{
    protected override WKWebView CreatePlatformView()
    {
        var view = base.CreatePlatformView();
        // Allow inline media playback without requiring user gesture
        view.Configuration.AllowsInlineMediaPlayback = true;
        view.Configuration.MediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypes.None;
        return view;
    }
}
