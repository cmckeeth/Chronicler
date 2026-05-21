namespace Chronicler.Api.Services;

public class LibraryScanService(IServiceProvider services, ILogger<LibraryScanService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        // Wait a bit after startup before first background scan
        await Task.Delay(TimeSpan.FromMinutes(1), ct);

        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(20));
        while (!ct.IsCancellationRequested && await timer.WaitForNextTickAsync(ct))
        {
            try
            {
                using var scope = services.CreateScope();
                var scanner = scope.ServiceProvider.GetRequiredService<LibraryScanner>();
                var added = await scanner.ScanAsync(ct);
                if (added > 0)
                    logger.LogInformation("Background scan: added {Count} new book(s)", added);
            }
            catch (Exception ex)
            {
                logger.LogWarning("Background scan failed: {Error}", ex.Message);
            }
        }
    }
}
