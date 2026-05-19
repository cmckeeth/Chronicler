namespace Chronicler.Shared.Services;

public class AuthState
{
    private string? _token;

    public bool IsAuthenticated => _token is not null;
    public string? Token => _token;

    public event Action? OnChange;

    public void SetToken(string? token)
    {
        _token = token;
        OnChange?.Invoke();
    }
}
