using AVFoundation;
using Chronicler.Shared.Services;
using Foundation;
using Microsoft.Extensions.DependencyInjection;

namespace Chronicler.Maui.Services;

public class iOSAudioPlayerService(IServiceProvider services) : IAudioPlayerService, IDisposable
{
    private IDownloadService? Downloads => services.GetService<IDownloadService>();
    private AVPlayer? _player;
    private NSObject? _endObserver;
    private System.Timers.Timer? _positionTimer;
    private string _currentUrl = "";

    public bool IsPlaying => _player?.Rate > 0;
    public bool IsPlayingLocally => !string.IsNullOrEmpty(_currentUrl) &&
        !_currentUrl.StartsWith("http", StringComparison.OrdinalIgnoreCase);
    public double CurrentPosition => _player?.CurrentTime.Seconds ?? 0;
    public double Duration => _player?.CurrentItem?.Duration.Seconds ?? 0;

    public event Action? StateChanged;
    public event Action<double>? PositionChanged;
    public event Action? Ended;

    public async Task PlayAsync(string url)
    {
        // Check for local downloaded file first
        if (Downloads is not null &&
            Uri.TryCreate(url, UriKind.Absolute, out var uri) &&
            int.TryParse(uri.Segments.Last(), out var chapterId))
        {
            var localPath = await Downloads.GetLocalPathAsync(chapterId);
            if (localPath is not null) { url = localPath; }
        }

        if (url != _currentUrl)
        {
            _player?.Pause();
            _endObserver?.Dispose();
            _endObserver = null;
            _player?.Dispose();
            _player = null;
            _currentUrl = url;

            var nsUrl = url.StartsWith("http", StringComparison.OrdinalIgnoreCase)
                ? NSUrl.FromString(url)!
                : NSUrl.FromFilename(url);

            _player = new AVPlayer(nsUrl);

            _endObserver = NSNotificationCenter.DefaultCenter.AddObserver(
                AVPlayerItem.DidPlayToEndTimeNotification,
                _ => { StopTimer(); StateChanged?.Invoke(); Ended?.Invoke(); },
                _player.CurrentItem);
        }

        _player?.Play();
        StartTimer();
        StateChanged?.Invoke();
    }

    public Task PauseAsync()
    {
        _player?.Pause();
        StopTimer();
        StateChanged?.Invoke();
        return Task.CompletedTask;
    }

    public Task SeekAsync(double position)
    {
        _player?.Seek(CoreMedia.CMTime.FromSeconds(position, 1));
        return Task.CompletedTask;
    }

    public Task SetRateAsync(double rate)
    {
        if (_player is not null)
            _player.Rate = (float)rate;
        return Task.CompletedTask;
    }

    private void StartTimer()
    {
        StopTimer();
        _positionTimer = new System.Timers.Timer(250) { AutoReset = true };
        _positionTimer.Elapsed += (_, _) => PositionChanged?.Invoke(CurrentPosition);
        _positionTimer.Start();
    }

    private void StopTimer()
    {
        _positionTimer?.Stop();
        _positionTimer?.Dispose();
        _positionTimer = null;
    }

    public void Dispose()
    {
        StopTimer();
        _endObserver?.Dispose();
        _player?.Pause();
        _player?.Dispose();
        _player = null;
    }
}
