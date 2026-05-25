using AVFoundation;
using Chronicler.Maui.Services;
using Foundation;

namespace Chronicler.Maui.Platforms.iOS;

public class StartupSoundService : IStartupSoundService
{
    public Task PlayAsync()
    {
        try
        {
            var session = AVAudioSession.SharedInstance();
            session.SetCategory(AVAudioSessionCategory.Playback, AVAudioSessionCategoryOptions.DefaultToSpeaker, out _);
            session.SetActive(true, out _);

            var path = NSBundle.MainBundle.PathForResource("startup", "mp3");
            if (path is null) return Task.CompletedTask;
            var player = AVAudioPlayer.FromUrl(NSUrl.FromFilename(path), out _);
            player?.Play();
        }
        catch { }
        return Task.CompletedTask;
    }
}
