namespace Chronicler.Api.Models;

public class ChapterProgress
{
    public int Id { get; set; }
    public string UserId { get; set; } = "default";
    public int ChapterId { get; set; }
    public double PositionSeconds { get; set; }
    public bool IsListened { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public Chapter Chapter { get; set; } = null!;
}
