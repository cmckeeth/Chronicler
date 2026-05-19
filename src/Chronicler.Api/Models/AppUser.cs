using Microsoft.AspNetCore.Identity;

namespace Chronicler.Api.Models;

public class AppUser : IdentityUser
{
    public ICollection<UserProgress> Progresses { get; set; } = [];
    public ICollection<Bookmark> Bookmarks { get; set; } = [];
}
