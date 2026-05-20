namespace Chronicler.Shared.Services;

public interface ITokenStorage
{
    Task<string?> GetAsync();
    Task SetAsync(string token);
    Task ClearAsync();
}
