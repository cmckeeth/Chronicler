using Android.Media;
using Chronicler.Shared.Services;

namespace Chronicler.Maui.Services;

public class NativeAudioPlayerService : IAudioPlayerService, IDisposable
{
    private MediaPlayer? _player;
    private System.Timers.Timer? _positionTimer;
    private string _currentUrl = "";

    public bool IsPlaying => _player?.IsPlaying ?? false;
    public double CurrentPosition => (_player?.CurrentPosition ?? 0) / 1000.0;
    public double Duration => (_player?.Duration ?? 0) / 1000.0;

    public event Action? StateChanged;
    public event Action<double>? PositionChanged;
    public event Action? Ended;

    public async Task PlayAsync(string url)
    {
        if (url != _currentUrl)
        {
            _player?.Stop();
            _player?.Release();
            _player = null;
            _currentUrl = url;
        }

        if (_player is null)
        {
            _player = new MediaPlayer();
            _player.SetAudioAttributes(new AudioAttributes.Builder()
                .SetUsage(AudioUsageKind.Media)!
                .SetContentType(AudioContentType.Music)!
                .Build()!);

            await _player.SetDataSourceAsync(Android.App.Application.Context, Android.Net.Uri.Parse(url)!);
            _player.Completion += (_, _) =>
            {
                StopTimer();
                StateChanged?.Invoke();
                Ended?.Invoke();
            };
            _player.Error += (_, _) =>
            {
                StateChanged?.Invoke();
            };

            _player.Prepare();
        }

        _player.Start();
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
        _player?.SeekTo((int)(position * 1000));
        return Task.CompletedTask;
    }

    public Task SetRateAsync(double rate)
    {
        if (_player is not null && OperatingSystem.IsAndroidVersionAtLeast(23))
        {
            var pp = new PlaybackParams();
            pp.SetSpeed((float)rate);
            _player.PlaybackParams = pp;
        }
        return Task.CompletedTask;
    }

    private void StartTimer()
    {
        StopTimer();
        _positionTimer = new System.Timers.Timer(250);
        _positionTimer.Elapsed += (_, _) => PositionChanged?.Invoke(CurrentPosition);
        _positionTimer.AutoReset = true;
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
        _player?.Release();
        _player?.Dispose();
        _player = null;
    }
}
