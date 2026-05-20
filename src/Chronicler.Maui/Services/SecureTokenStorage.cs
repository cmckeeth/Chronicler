using Chronicler.Shared.Services;

namespace Chronicler.Maui.Services;

public class SecureTokenStorage : ITokenStorage
{
    private const string Key = "chronicler_token";

    public async Task<string?> GetAsync()
    {
        try { return await SecureStorage.Default.GetAsync(Key); }
        catch { return null; }
    }

    public async Task SetAsync(string token)
    {
        try { await SecureStorage.Default.SetAsync(Key, token); }
        catch { }
    }

    public Task ClearAsync()
    {
        try { SecureStorage.Default.Remove(Key); }
        catch { }
        return Task.CompletedTask;
    }
}
