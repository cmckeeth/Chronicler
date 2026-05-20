namespace Chronicler.Shared.Services;

public interface IAudioPlayerService
{
    bool IsPlaying { get; }
    double CurrentPosition { get; }
    double Duration { get; }

    Task PlayAsync(string url);
    Task PauseAsync();
    Task SeekAsync(double position);
    Task SetRateAsync(double rate);

    event Action? StateChanged;
    event Action<double>? PositionChanged;
    event Action? Ended;
}
