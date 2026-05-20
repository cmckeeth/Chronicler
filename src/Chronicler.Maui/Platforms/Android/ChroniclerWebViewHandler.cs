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
        return view;
    }
}
