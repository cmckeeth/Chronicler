#if ANDROID
using Android.Media;
using Android.Util;
using Chronicler.Shared.Services;
using Microsoft.Extensions.DependencyInjection;

namespace Chronicler.Maui.Services;

public class NativeAudioPlayerService(IServiceProvider services) : IAudioPlayerService, IDisposable
{
    private const string TAG = "ChroniclerAudio";
    private IDownloadService? Downloads => services.GetService<IDownloadService>();
    private MediaPlayer? _player;
    private System.Timers.Timer? _positionTimer;
    private string _currentUrl = "";
    private bool _intendedPlaying;
    private float _playbackSpeed = 1.0f;

    private static void Dbg(string msg)
    {
        Log.Debug(TAG, msg);
        System.Diagnostics.Debug.WriteLine($"[ChroniclerAudio] {msg}");
    }

    public bool IsPlaying => _intendedPlaying;
    public bool IsPlayingLocally => !string.IsNullOrEmpty(_currentUrl) &&
        !_currentUrl.StartsWith("http", StringComparison.OrdinalIgnoreCase);
    public double CurrentPosition => (_player?.CurrentPosition ?? 0) / 1000.0;
    public double Duration => (_player?.Duration ?? 0) / 1000.0;

    public event Action? StateChanged;
    public event Action<double>? PositionChanged;
    public event Action? Ended;

    public async Task PlayAsync(string url)
    {
        // Check for local downloaded file first
        if (Downloads is not null)
        {
            if (Uri.TryCreate(url, UriKind.Absolute, out var uri) &&
                uri.Segments.Length >= 2 &&
                int.TryParse(uri.Segments.FirstOrDefault(s => int.TryParse(s.TrimEnd('/'), out _))?.TrimEnd('/'), out var chapterId))
            {
                var localPath = await Downloads.GetLocalPathAsync(chapterId);
                if (localPath is not null) { url = localPath; Dbg($"Using local file: {url}"); }
            }
        }

        Dbg($"PlayAsync: url={url} currentUrl={_currentUrl}");

        if (url != _currentUrl)
        {
            Dbg("New URL — resetting player");
            _player?.Stop();
            _player?.Release();
            _player = null;
            _currentUrl = url;
            _intendedPlaying = false;
        }

        if (_player is null)
        {
            Dbg("Creating MediaPlayer");
            _player = new MediaPlayer();
            _player.SetAudioAttributes(new AudioAttributes.Builder()
                .SetUsage(AudioUsageKind.Media)!
                .SetContentType(AudioContentType.Music)!
                .Build()!);

            var isLocal = !url.StartsWith("http", StringComparison.OrdinalIgnoreCase);
            Dbg($"SetDataSource: {url} (local={isLocal})");
            if (isLocal)
                _player.SetDataSource(url);
            else
                await _player.SetDataSourceAsync(Android.App.Application.Context, Android.Net.Uri.Parse(url)!);

            _player.Completion += (_, _) =>
            {
                Dbg("Completion");
                _intendedPlaying = false;
                StopTimer();
                StateChanged?.Invoke();
                Ended?.Invoke();
            };
            _player.Error += (_, e) =>
            {
                Dbg($"Error: what={e.What} extra={e.Extra}");
                _intendedPlaying = false;
                StateChanged?.Invoke();
            };

            Dbg("Prepare()");
            _player.Prepare();
            Dbg($"Prepared — duration={_player.Duration}ms");
        }

        Dbg("Start()");
        _player.Start();
        // Restore speed (also resumes from speed=0 pause)
        if (OperatingSystem.IsAndroidVersionAtLeast(23))
        {
            var pp = new PlaybackParams();
            pp.SetSpeed(_playbackSpeed);
            try { _player.PlaybackParams = pp; } catch { }
        }
        _intendedPlaying = true;
        StartTimer();
        StateChanged?.Invoke();
        Dbg($"Playing — isPlaying={_player.IsPlaying}");
    }

    public Task PauseAsync()
    {
        Dbg($"PauseAsync — intendedPlaying={_intendedPlaying}");
        if (_player is not null && OperatingSystem.IsAndroidVersionAtLeast(23))
        {
            // Use speed=0 instead of Pause() — more reliable for streaming on Android
            var pp = new PlaybackParams();
            pp.SetSpeed(0.0f);
            _player.PlaybackParams = pp;
        }
        else
        {
            _player?.Pause();
        }
        _intendedPlaying = false;
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
        _playbackSpeed = (float)rate;
        if (_player is not null && _intendedPlaying && OperatingSystem.IsAndroidVersionAtLeast(23))
        {
            var pp = new PlaybackParams();
            pp.SetSpeed(_playbackSpeed);
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
#endif
