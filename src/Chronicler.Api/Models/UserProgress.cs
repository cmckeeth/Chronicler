namespace Chronicler.Api.Models;

public class UserProgress
{
    public int Id { get; set; }
    public string UserId { get; set; } = "";
    public int BookId { get; set; }
    public double PositionSeconds { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public AppUser User { get; set; } = null!;
    public Book Book { get; set; } = null!;
}
