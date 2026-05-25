using Android.Media;
using Chronicler.Maui.Services;

namespace Chronicler.Maui.Platforms.Android;

public class StartupSoundService : IStartupSoundService
{
    public async Task PlayAsync()
    {
        try
        {
            using var stream = await FileSystem.OpenAppPackageFileAsync("startup.mp3");
            var player = new MediaPlayer();
            player.SetAudioAttributes(new AudioAttributes.Builder()
                .SetUsage(AudioUsageKind.Media)!
                .SetContentType(AudioContentType.Music)!
                .Build()!);
            player.SetDataSource(
                Android.App.Application.Context,
                Android.Net.Uri.Parse("file:///android_asset/startup.mp3")!);
            player.Prepare();
            player.Completion += (_, _) => { player.Release(); player.Dispose(); };
            player.Start();
        }
        catch { }
    }
}
