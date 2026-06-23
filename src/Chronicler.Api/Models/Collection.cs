namespace Chronicler.Api.Models;

// A "collection" is a Library subfolder whose children are themselves audio folders
// (e.g. a series or boxed set). It groups Books and is browsable as its own page.
public class Collection
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
    public string FolderPath { get; set; } = "";   // relative to LibraryRoot (the collection folder)
    public byte[]? CoverData { get; set; }
    public string? CoverMimeType { get; set; }
    public DateTime AddedAt { get; set; } = DateTime.UtcNow;

    public ICollection<Book> Books { get; set; } = [];
}
