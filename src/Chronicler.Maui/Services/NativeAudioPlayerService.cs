using Android.Media;
using Android.Util;
using Chronicler.Shared.Services;

namespace Chronicler.Maui.Services;

public class NativeAudioPlayerService : IAudioPlayerService, IDisposable
{
    private const string TAG = "ChroniclerAudio";
    private MediaPlayer? _player;
    private System.Timers.Timer? _positionTimer;
    private string _currentUrl = "";

    private static void Dbg(string msg)
    {
        Log.Debug(TAG, msg);
        System.Diagnostics.Debug.WriteLine($"[ChroniclerAudio] {msg}");
    }

    public bool IsPlaying => _player?.IsPlaying ?? false;
    public double CurrentPosition => (_player?.CurrentPosition ?? 0) / 1000.0;
    public double Duration => (_player?.Duration ?? 0) / 1000.0;

    public event Action? StateChanged;
    public event Action<double>? PositionChanged;
    public event Action? Ended;

    public async Task PlayAsync(string url)
    {
        Dbg($"PlayAsync: url={url} currentUrl={_currentUrl}");

        if (url != _currentUrl)
        {
            Dbg("New URL — resetting player");
            _player?.Stop();
            _player?.Release();
            _player = null;
            _currentUrl = url;
        }

        if (_player is null)
        {
            Dbg("Creating MediaPlayer");
            _player = new MediaPlayer();
            _player.SetAudioAttributes(new AudioAttributes.Builder()
                .SetUsage(AudioUsageKind.Media)!
                .SetContentType(AudioContentType.Music)!
                .Build()!);

            Dbg($"SetDataSource: {url}");
            await _player.SetDataSourceAsync(Android.App.Application.Context, Android.Net.Uri.Parse(url)!);

            _player.Completion += (_, _) => { Dbg("Completion"); StopTimer(); StateChanged?.Invoke(); Ended?.Invoke(); };
            _player.Error += (_, e) => { Dbg($"Error: what={e.What} extra={e.Extra}"); StateChanged?.Invoke(); };

            Dbg("Prepare()");
            _player.Prepare();
            Dbg($"Prepared — duration={_player.Duration}ms");
        }

        Dbg("Start()");
        _player.Start();
        StartTimer();
        StateChanged?.Invoke();
        Dbg($"Playing — isPlaying={_player.IsPlaying}");
    }

    public Task PauseAsync()
    {
        Dbg("PauseAsync");
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
