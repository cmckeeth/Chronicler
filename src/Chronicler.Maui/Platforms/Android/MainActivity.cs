using Android.App;
using Android.Content.PM;
using Android.OS;
using Android.Webkit;

namespace Chronicler.Maui;

[Activity(Theme = "@style/Maui.SplashTheme", MainLauncher = true, ConfigurationChanges = ConfigChanges.ScreenSize | ConfigChanges.Orientation | ConfigChanges.UiMode | ConfigChanges.ScreenLayout | ConfigChanges.SmallestScreenSize | ConfigChanges.Density)]
public class MainActivity : MauiAppCompatActivity
{
    protected override void OnCreate(Bundle? savedInstanceState)
    {
        base.OnCreate(savedInstanceState);
        // Enable media playback in WebView without requiring user gesture
        Android.Webkit.WebView.SetWebContentsDebuggingEnabled(true);
    }
}
