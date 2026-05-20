using Chronicler.Shared.Services;
using Microsoft.JSInterop;

namespace Chronicler.Web.Services;

public class LocalStorageTokenStorage(IJSRuntime js) : ITokenStorage
{
    private const string Key = "chronicler_token";

    public async Task<string?> GetAsync()
    {
        try { return await js.InvokeAsync<string?>("localStorage.getItem", Key); }
        catch { return null; }
    }

    public async Task SetAsync(string token)
    {
        try { await js.InvokeVoidAsync("localStorage.setItem", Key, token); }
        catch { }
    }

    public async Task ClearAsync()
    {
        try { await js.InvokeVoidAsync("localStorage.removeItem", Key); }
        catch { }
    }
}
