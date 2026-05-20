namespace Chronicler.Shared.Services;

public class AuthState
{
    private string? _token;
    private string? _email;

    public bool IsAuthenticated => _token is not null;
    public string? Token => _token;
    public string? Email => _email;

    public event Action? OnChange;

    public void SetToken(string? token, string? email = null)
    {
        _token = token;
        _email = email;
        OnChange?.Invoke();
    }

    public void Clear()
    {
        _token = null;
        _email = null;
        OnChange?.Invoke();
    }
}
