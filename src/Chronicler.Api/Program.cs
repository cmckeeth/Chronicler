using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Chronicler.Api.Data;
using Chronicler.Api.Models;
using QRCoder;
using Chronicler.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Serilog;
using Serilog.Events;

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .MinimumLevel.Override("Microsoft.AspNetCore", LogEventLevel.Warning)
    .MinimumLevel.Override("Microsoft.EntityFrameworkCore", LogEventLevel.Warning)
    .Enrich.FromLogContext()
    .WriteTo.Console(outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}")
    .WriteTo.File(
        path: "logs/chronicler-.log",
        rollingInterval: RollingInterval.Day,
        retainedFileCountLimit: 7,
        outputTemplate: "[{Timestamp:yyyy-MM-dd HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}")
    .CreateLogger();

var builder = WebApplication.CreateBuilder(args);
builder.Host.UseSerilog();

// ── Config ────────────────────────────────────────────────────────────────────

var jwtKey = builder.Configuration["Jwt:Key"]
    ?? Environment.GetEnvironmentVariable("JWT_KEY")
    ?? "dev-secret-change-in-production-min-32-chars!!";

var dbPath = Environment.GetEnvironmentVariable("CHRONICLER_DB_PATH")
    ?? builder.Configuration["DbPath"]
    ?? "chronicler.db";

// ── Services ──────────────────────────────────────────────────────────────────

builder.Services.AddDbContext<AppDbContext>(opt =>
    opt.UseSqlite($"Data Source={dbPath}"));

builder.Services.AddIdentity<AppUser, IdentityRole>(opt =>
{
    opt.Password.RequireDigit = false;
    opt.Password.RequireNonAlphanumeric = false;
    opt.Password.RequireUppercase = false;
    opt.Password.RequiredLength = 6;
})
.AddEntityFrameworkStores<AppDbContext>()
.AddDefaultTokenProviders();

builder.Services.AddAuthentication(opt =>
{
    opt.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    opt.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(opt =>
{
    opt.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
        ValidateIssuer = false,
        ValidateAudience = false
    };
});

builder.Services.AddAuthorization();
builder.Services.AddScoped<LibraryScanner>();
builder.Services.AddHostedService<LibraryScanService>();
builder.Services.AddCors(opt =>
    opt.AddDefaultPolicy(p => p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

// ── App ───────────────────────────────────────────────────────────────────────

var app = builder.Build();

// Auto-migrate and scan library on startup
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.MigrateAsync();
    // Enable WAL mode for better concurrent read performance
    await db.Database.ExecuteSqlRawAsync("PRAGMA journal_mode=WAL;");
    await db.Database.ExecuteSqlRawAsync("PRAGMA cache_size=-32000;"); // 32MB cache

    var scanner = scope.ServiceProvider.GetRequiredService<LibraryScanner>();
    var added = await scanner.ScanAsync();
    if (added > 0) app.Logger.LogInformation("Library scan: added {Count} books", added);
}

app.UseSerilogRequestLogging(opt =>
{
    opt.MessageTemplate = "{RequestMethod} {RequestPath} → {StatusCode} ({Elapsed:0}ms)";
});
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

// ── Health ────────────────────────────────────────────────────────────────────

app.MapGet("/api/health", () => Results.Ok(new { status = "healthy" }));

app.MapPost("/api/diag", (DiagMessage msg, ILogger<Program> logger) =>
{
    logger.LogInformation("[DIAG] {Message}", msg.Message);
    return Results.Ok();
});

app.MapGet("/api/logs", (IWebHostEnvironment env) =>
{
    var logsDir = Path.Combine(env.ContentRootPath, "logs");
    var today = DateTime.UtcNow.ToString("yyyyMMdd");
    var logFile = Path.Combine(logsDir, $"chronicler-{today}.log");
    if (!File.Exists(logFile)) return Results.NotFound(new { error = "No log file for today" });
    var content = File.ReadAllText(logFile);
    return Results.Content(content, "text/plain");
});

// ── Auth ──────────────────────────────────────────────────────────────────────

app.MapPost("/api/auth/register", async (
    RegisterRequest req,
    UserManager<AppUser> users) =>
{
    var user = new AppUser { UserName = req.Email, Email = req.Email };
    var result = await users.CreateAsync(user, req.Password);
    if (!result.Succeeded)
        return Results.BadRequest(result.Errors.Select(e => e.Description));

    return Results.Ok(new { token = CreateToken(user, jwtKey) });
});

app.MapPost("/api/auth/login", async (
    LoginRequest req,
    UserManager<AppUser> users,
    SignInManager<AppUser> signIn) =>
{
    var user = await users.FindByEmailAsync(req.Email);
    if (user is null) return Results.Unauthorized();

    var result = await signIn.CheckPasswordSignInAsync(user, req.Password, false);
    if (!result.Succeeded) return Results.Unauthorized();

    return Results.Ok(new { token = CreateToken(user, jwtKey) });
});

app.MapGet("/api/auth/me", (ClaimsPrincipal principal) =>
    Results.Ok(new { email = principal.FindFirstValue(ClaimTypes.Email) }));

// ── Books ─────────────────────────────────────────────────────────────────────

app.MapGet("/api/books", [Authorize] async (string? q, bool? root, ClaimsPrincipal principal, AppDbContext db) =>
{
    var userId = UserId(principal);
    var query = db.Books.AsQueryable();
    if (!string.IsNullOrWhiteSpace(q))
        query = query.Where(b =>
            b.Title.ToLower().Contains(q.ToLower()) ||
            b.Author.ToLower().Contains(q.ToLower()) ||
            (b.Narrator != null && b.Narrator.ToLower().Contains(q.ToLower())));

    // root=true → only top-level (standalone) books, i.e. not inside a collection.
    // Used by the library grid so collection books aren't shown twice.
    if (root == true) query = query.Where(b => b.CollectionId == null);

    var books = await query
        .OrderBy(b => b.Author).ThenBy(b => b.Title)
        .Select(b => new BookDto(
            b.Id, b.Title, b.Author, b.Narrator, b.DurationSeconds,
            b.CoverData != null, b.AddedAt,
            b.Chapters.Count(),
            b.Chapters.Count(c => c.Progresses.Any(p => p.UserId == userId && p.IsListened)),
            b.Year,
            db.UserBookFavorites.Any(f => f.UserId == userId && f.BookId == b.Id),
            b.CollectionId, b.Description, b.SortOrder))
        .ToListAsync();

    return Results.Ok(books);
});

// ── Collections ───────────────────────────────────────────────────────────────

app.MapGet("/api/collections", [Authorize] async (AppDbContext db) =>
{
    var cols = await db.Collections
        .OrderBy(c => c.Name)
        .Select(c => new CollectionDto(c.Id, c.Name, c.CoverData != null, c.Books.Count(), c.AddedAt))
        .ToListAsync();
    return Results.Ok(cols);
});

app.MapGet("/api/collections/{id:int}", [Authorize] async (int id, AppDbContext db) =>
{
    var c = await db.Collections.FindAsync(id);
    return c is null
        ? Results.NotFound()
        : Results.Ok(new CollectionDto(c.Id, c.Name, c.CoverData != null, await db.Books.CountAsync(b => b.CollectionId == id), c.AddedAt));
});

app.MapGet("/api/collections/{id:int}/books", [Authorize] async (int id, ClaimsPrincipal principal, AppDbContext db) =>
{
    var userId = UserId(principal);
    var books = await db.Books
        .Where(b => b.CollectionId == id)
        // Manually-ordered books first (by SortOrder), then the rest alphabetically.
        .OrderBy(b => b.SortOrder == null).ThenBy(b => b.SortOrder)
        .ThenBy(b => b.Author).ThenBy(b => b.Title)
        .Select(b => new BookDto(
            b.Id, b.Title, b.Author, b.Narrator, b.DurationSeconds,
            b.CoverData != null, b.AddedAt,
            b.Chapters.Count(),
            b.Chapters.Count(c => c.Progresses.Any(p => p.UserId == userId && p.IsListened)),
            b.Year,
            db.UserBookFavorites.Any(f => f.UserId == userId && f.BookId == b.Id),
            b.CollectionId, b.Description, b.SortOrder))
        .ToListAsync();
    return Results.Ok(books);
});

// Persist manual book order within a collection. Body = book ids in desired order.
// Backward compat: books omitted from the list keep their existing SortOrder.
app.MapPut("/api/collections/{id:int}/order", [Authorize] async (int id, int[] bookIds, AppDbContext db) =>
{
    var books = await db.Books.Where(b => b.CollectionId == id).ToListAsync();
    if (books.Count == 0) return Results.NotFound();
    var byId = books.ToDictionary(b => b.Id);
    for (var i = 0; i < bookIds.Length; i++)
        if (byId.TryGetValue(bookIds[i], out var b)) b.SortOrder = i;
    await db.SaveChangesAsync();
    return Results.NoContent();
});

// Collection cover: its own cover.* if present, else fall back to its first book's cover.
app.MapGet("/api/collections/{id:int}/cover", async (int id, HttpContext ctx, AppDbContext db) =>
{
    var col = await db.Collections.Where(c => c.Id == id)
        .Select(c => new { c.CoverData, c.CoverMimeType }).FirstOrDefaultAsync();
    byte[]? data = col?.CoverData;
    string? mime = col?.CoverMimeType;
    if (data is null || data.Length == 0)
    {
        var bk = await db.Books.Where(b => b.CollectionId == id && b.CoverData != null)
            .OrderBy(b => b.Title)
            .Select(b => new { b.CoverData, b.CoverMimeType }).FirstOrDefaultAsync();
        data = bk?.CoverData; mime = bk?.CoverMimeType;
    }
    if (data is null || data.Length == 0) return Results.NotFound();
    ctx.Response.Headers["Cache-Control"] = "public, max-age=86400";
    ctx.Response.Headers["ETag"] = $"\"col-{id}-{data.Length}\"";
    return Results.File(data, mime ?? "image/jpeg");
});

// Upload/replace a collection's cover. Mirrors the book cover upload: saves to the DB
// and also writes cover.<ext> into the collection's folder (so a rescan keeps it and
// every platform can read it). Reports disk-write failures instead of swallowing them.
app.MapPut("/api/collections/{id:int}/cover/upload", [Authorize] async (int id, HttpRequest request, AppDbContext db, LibraryScanner scanner) =>
{
    var col = await db.Collections.FindAsync(id);
    if (col is null) return Results.NotFound();
    if (!request.HasFormContentType) return Results.BadRequest("Expected multipart form");

    var form = await request.ReadFormAsync();
    var file = form.Files.FirstOrDefault();
    if (file is null || file.Length == 0) return Results.BadRequest("No file provided");

    using var ms = new MemoryStream();
    await file.CopyToAsync(ms);
    var bytes = ms.ToArray();
    var mime = file.ContentType.StartsWith("image/") ? file.ContentType : "image/jpeg";
    col.CoverData = bytes;
    col.CoverMimeType = mime;
    await db.SaveChangesAsync();

    string? coverPath = null;
    bool fileWritten = false;
    string? fileError = null;
    try
    {
        var dir = Path.Combine(scanner.LibraryRoot, col.FolderPath);
        if (!Directory.Exists(dir))
        {
            fileError = $"collection folder not found on disk: {dir}";
        }
        else
        {
            var ext = mime switch { "image/png" => ".png", "image/webp" => ".webp", "image/gif" => ".gif", _ => ".jpg" };
            foreach (var old in Directory.GetFiles(dir)
                .Where(f => Path.GetFileNameWithoutExtension(f).Equals("cover", StringComparison.OrdinalIgnoreCase)))
            {
                try { File.SetAttributes(old, FileAttributes.Normal); } catch { /* best effort */ }
                File.Delete(old);
            }
            coverPath = Path.Combine(dir, "cover" + ext);
            await using (var fs = new FileStream(coverPath, FileMode.Create, FileAccess.Write, FileShare.None))
                await fs.WriteAsync(bytes);
            fileWritten = true;
        }
    }
    catch (Exception ex)
    {
        fileError = ex.Message;
        app.Logger.LogError(ex, "Could not write cover file for collection {Id} at {Path}", id, coverPath);
    }

    if (!fileWritten)
        app.Logger.LogWarning("Cover for collection {Id} saved to DB but NOT written to disk: {Error}", id, fileError);

    return Results.Ok(new { hasCover = true, fileWritten, coverPath, fileError });
});

// Clear a collection's cover: wipe the DB cover AND delete cover.* in the collection
// folder (so the GET falls back to the first book's cover, and a fresh upload writes clean).
app.MapDelete("/api/collections/{id:int}/cover", [Authorize] async (int id, AppDbContext db, LibraryScanner scanner) =>
{
    var col = await db.Collections.FindAsync(id);
    if (col is null) return Results.NotFound();
    col.CoverData = null;
    col.CoverMimeType = null;
    await db.SaveChangesAsync();

    int deleted = 0; string? fileError = null;
    try
    {
        var dir = Path.Combine(scanner.LibraryRoot, col.FolderPath);
        if (Directory.Exists(dir))
            foreach (var f in Directory.GetFiles(dir)
                .Where(f => Path.GetFileNameWithoutExtension(f).Equals("cover", StringComparison.OrdinalIgnoreCase)))
            {
                try { File.SetAttributes(f, FileAttributes.Normal); } catch { }
                File.Delete(f); deleted++;
            }
    }
    catch (Exception ex) { fileError = ex.Message; app.Logger.LogError(ex, "Could not delete cover file(s) for collection {Id}", id); }

    return Results.Ok(new { cleared = true, filesDeleted = deleted, fileError });
});

app.MapGet("/api/books/{id:int}", [Authorize] async (int id, ClaimsPrincipal principal, AppDbContext db) =>
{
    var uid = UserId(principal);
    var b = await db.Books.FindAsync(id);
    if (b is null) return Results.NotFound();
    var isFav = await db.UserBookFavorites.FindAsync(uid, id) is not null;
    return Results.Ok(new BookDto(b.Id, b.Title, b.Author, b.Narrator, b.DurationSeconds,
        b.CoverData != null, b.AddedAt, 0, 0, b.Year, isFav, b.CollectionId, b.Description));
});

app.MapGet("/api/books/{id:int}/cover", async (int id, HttpContext ctx, AppDbContext db) =>
{
    // Select only the cover columns — don't load the whole book row
    var cover = await db.Books
        .Where(b => b.Id == id)
        .Select(b => new { b.CoverData, b.CoverMimeType })
        .FirstOrDefaultAsync();

    if (cover?.CoverData is null || cover.CoverData.Length == 0) return Results.NotFound();

    var mime = cover.CoverMimeType ?? "image/jpeg";
    ctx.Response.Headers["Cache-Control"] = "public, max-age=86400";
    ctx.Response.Headers["ETag"] = $"\"{id}-{cover.CoverData.Length}\"";
    return Results.File(cover.CoverData, mime);
});

app.MapGet("/api/books/{id:int}/audio", async (
    int id, HttpContext ctx, AppDbContext db, IWebHostEnvironment env, ILogger<Program> logger) =>
{
    var book = await db.Books.FindAsync(id);
    if (book is null) { logger.LogWarning("Audio: book {Id} not found", id); return Results.NotFound(); }

    var fullPath = Path.Combine(env.ContentRootPath, "Library", book.FilePath);
    logger.LogInformation("Audio: book {Id} → {Path} | exists={Exists} | Range={Range} | UA={UA}",
        id, fullPath, File.Exists(fullPath),
        ctx.Request.Headers["Range"].ToString(),
        ctx.Request.Headers["User-Agent"].ToString());

    if (!File.Exists(fullPath)) return Results.NotFound();

    var ext = Path.GetExtension(fullPath).ToLower();
    var mime = ext switch
    {
        ".mp3" => "audio/mpeg",
        ".m4b" or ".m4a" => "audio/mp4",
        ".ogg" => "audio/ogg",
        ".opus" => "audio/ogg; codecs=opus",
        ".flac" => "audio/flac",
        ".aac" => "audio/aac",
        ".wav" => "audio/wav",
        _ => "application/octet-stream"
    };

    return Results.File(fullPath, mime, enableRangeProcessing: true);
});

// ── Book metadata (reads/writes meta.json) ────────────────────────────────────

app.MapGet("/api/books/{id:int}/meta", [Authorize] async (int id, AppDbContext db, IWebHostEnvironment env) =>
{
    var book = await db.Books.FindAsync(id);
    if (book is null) return Results.NotFound();

    var audioDir = Path.GetDirectoryName(Path.Combine(env.ContentRootPath, "Library", book.FilePath));
    var metaPath = audioDir is not null ? Path.Combine(audioDir, "meta.json") : null;
    int? year = book.Year;

    if (metaPath is not null && File.Exists(metaPath))
    {
        try
        {
            var raw = await File.ReadAllTextAsync(metaPath);
            var meta = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(raw);
            if (meta.TryGetProperty("year", out var y) && y.ValueKind == System.Text.Json.JsonValueKind.Number)
                year = y.GetInt32();
        }
        catch { }
    }

    return Results.Ok(new { book.Id, book.Title, book.Author, book.Narrator, book.Description, Year = year });
});

app.MapPut("/api/books/{id:int}/meta", [Authorize] async (
    int id, BookMetaRequest req, AppDbContext db, IWebHostEnvironment env) =>
{
    var book = await db.Books.FindAsync(id);
    if (book is null) return Results.NotFound();

    if (req.Title is not null) book.Title = req.Title;
    if (req.Author is not null) book.Author = req.Author;
    book.Narrator = req.Narrator;
    book.Description = req.Description;
    if (req.Year.HasValue) book.Year = req.Year;

    await db.SaveChangesAsync();

    // Write meta.json next to the audio files
    var audioDir = Path.GetDirectoryName(Path.Combine(env.ContentRootPath, "Library", book.FilePath));
    if (audioDir is not null)
    {
        var meta = new
        {
            title = book.Title,
            author = book.Author,
            narrator = book.Narrator,
            year = req.Year,
            description = book.Description
        };
        var json = System.Text.Json.JsonSerializer.Serialize(meta,
            new System.Text.Json.JsonSerializerOptions { WriteIndented = true });
        await File.WriteAllTextAsync(Path.Combine(audioDir, "meta.json"), json);
    }

    return Results.Ok(new { book.Id, book.Title, book.Author, book.Narrator, book.Description, Year = req.Year });
});

// Clear the cover: wipe it from the DB AND delete cover.* on disk, so a fresh upload
// can write cleanly (and a rescan won't re-import the old file).
app.MapDelete("/api/books/{id:int}/cover", [Authorize] async (int id, AppDbContext db, LibraryScanner scanner) =>
{
    var book = await db.Books.FindAsync(id);
    if (book is null) return Results.NotFound();
    book.CoverData = null;
    book.CoverMimeType = null;
    await db.SaveChangesAsync();

    int deleted = 0; string? fileError = null;
    try
    {
        var dir = Path.GetDirectoryName(Path.Combine(scanner.LibraryRoot, book.FilePath));
        if (dir is not null && Directory.Exists(dir))
            foreach (var f in Directory.GetFiles(dir)
                .Where(f => Path.GetFileNameWithoutExtension(f).Equals("cover", StringComparison.OrdinalIgnoreCase)))
            {
                try { File.SetAttributes(f, FileAttributes.Normal); } catch { }
                File.Delete(f); deleted++;
            }
    }
    catch (Exception ex) { fileError = ex.Message; app.Logger.LogError(ex, "Could not delete cover file(s) for book {Id}", id); }

    return Results.Ok(new { cleared = true, filesDeleted = deleted, fileError });
});

app.MapPut("/api/books/{id:int}/cover/upload", [Authorize] async (int id, HttpRequest request, AppDbContext db, LibraryScanner scanner) =>
{
    var book = await db.Books.FindAsync(id);
    if (book is null) return Results.NotFound();
    if (!request.HasFormContentType) return Results.BadRequest("Expected multipart form");

    var form = await request.ReadFormAsync();
    var file = form.Files.FirstOrDefault();
    if (file is null || file.Length == 0) return Results.BadRequest("No file provided");

    using var ms = new MemoryStream();
    await file.CopyToAsync(ms);
    var bytes = ms.ToArray();
    var mime = file.ContentType.StartsWith("image/") ? file.ContentType : "image/jpeg";
    book.CoverData = bytes;
    book.CoverMimeType = mime;
    await db.SaveChangesAsync();

    // Persist the upload as cover.<ext> in the book's folder so the scanner (and every
    // platform that reads covers) keeps it — otherwise a rescan, which syncs covers from
    // disk, would clear a DB-only cover.
    string? coverPath = null;
    bool fileWritten = false;
    string? fileError = null;
    try
    {
        var bookDir = Path.GetDirectoryName(Path.Combine(scanner.LibraryRoot, book.FilePath));
        if (bookDir is null || !Directory.Exists(bookDir))
        {
            fileError = $"book folder not found on disk: {bookDir}";
        }
        else
        {
            var ext = mime switch { "image/png" => ".png", "image/webp" => ".webp", "image/gif" => ".gif", _ => ".jpg" };
            // Remove any existing cover.* first. Clear the read-only attribute so a delete
            // of a file written by another user/process can still succeed where permitted.
            foreach (var old in Directory.GetFiles(bookDir)
                .Where(f => Path.GetFileNameWithoutExtension(f).Equals("cover", StringComparison.OrdinalIgnoreCase)))
            {
                try { File.SetAttributes(old, FileAttributes.Normal); } catch { /* best effort */ }
                File.Delete(old);   // let a real failure surface (no longer swallowed)
            }
            coverPath = Path.Combine(bookDir, "cover" + ext);
            // FileMode.Create truncates/replaces; creating a fresh file avoids needing
            // write permission on a pre-existing file owned by someone else.
            await using (var fs = new FileStream(coverPath, FileMode.Create, FileAccess.Write, FileShare.None))
                await fs.WriteAsync(bytes);
            fileWritten = true;
        }
    }
    catch (Exception ex)
    {
        fileError = ex.Message;
        app.Logger.LogError(ex, "Could not write cover file for book {Id} at {Path}", id, coverPath);
    }

    if (!fileWritten)
        app.Logger.LogWarning("Cover for book {Id} saved to DB but NOT written to disk: {Error}", id, fileError);

    return Results.Ok(new { hasCover = true, fileWritten, coverPath, fileError });
});


// ── Chapters ──────────────────────────────────────────────────────────────────

app.MapGet("/api/books/{bookId:int}/chapters", [Authorize] async (int bookId, AppDbContext db) =>
{
    var chapters = await db.Chapters
        .Where(c => c.BookId == bookId)
        .OrderBy(c => c.TrackNumber)
        .Select(c => new { c.Id, c.BookId, c.Title, c.TrackNumber, c.FilePath })
        .ToListAsync();
    var dtos = chapters.Select(c =>
        new ChapterDto(c.Id, c.BookId, c.Title, c.TrackNumber, AudioMime(c.FilePath)));
    return Results.Ok(dtos);
});

app.MapGet("/api/chapters/{chapterId:int}/audio", async (
    int chapterId, HttpContext ctx, AppDbContext db, IWebHostEnvironment env, ILogger<Program> logger) =>
{
    var chapter = await db.Chapters.FindAsync(chapterId);
    if (chapter is null) { logger.LogWarning("Audio: chapter {Id} not found", chapterId); return Results.NotFound(); }

    var fullPath = Path.Combine(env.ContentRootPath, "Library", chapter.FilePath);
    logger.LogInformation("Audio: chapter {Id} → {Path} | exists={Exists} | Range={Range} | UA={UA}",
        chapterId, fullPath, File.Exists(fullPath),
        ctx.Request.Headers["Range"].ToString(),
        ctx.Request.Headers["User-Agent"].ToString());

    if (!File.Exists(fullPath)) return Results.NotFound();

    var ext = Path.GetExtension(fullPath).ToLower();
    var mime = ext switch
    {
        ".mp3" => "audio/mpeg",
        ".m4b" or ".m4a" => "audio/mp4",
        ".ogg" => "audio/ogg",
        ".opus" => "audio/ogg; codecs=opus",
        ".flac" => "audio/flac",
        ".aac" => "audio/aac",
        ".wav" => "audio/wav",
        _ => "application/octet-stream"
    };
    return Results.File(fullPath, mime, enableRangeProcessing: true);
});

app.MapGet("/api/chapters/{chapterId:int}/progress", [Authorize] async (int chapterId, ClaimsPrincipal principal, AppDbContext db) =>
{
    var uid = UserId(principal);
    var p = await db.ChapterProgresses
        .FirstOrDefaultAsync(p => p.UserId == uid && p.ChapterId == chapterId);
    return Results.Ok(new { positionSeconds = p?.PositionSeconds ?? 0, isListened = p?.IsListened ?? false });
});

app.MapPut("/api/chapters/{chapterId:int}/progress", [Authorize] async (
    int chapterId, ChapterProgressRequest req, ClaimsPrincipal principal, AppDbContext db) =>
{
    var uid = UserId(principal);
    var p = await db.ChapterProgresses
        .FirstOrDefaultAsync(cp => cp.UserId == uid && cp.ChapterId == chapterId);

    if (p is null)
    {
        p = new ChapterProgress { UserId = uid, ChapterId = chapterId };
        db.ChapterProgresses.Add(p);
    }

    p.PositionSeconds = req.PositionSeconds;
    p.UpdatedAt = DateTime.UtcNow;

    // Mark as listened if >= 95% complete (requires duration from client)
    if (req.DurationSeconds > 0 && req.PositionSeconds / req.DurationSeconds >= 0.95)
        p.IsListened = true;

    await db.SaveChangesAsync();
    return Results.Ok();
});

app.MapPost("/api/chapters/{chapterId:int}/reset", [Authorize] async (int chapterId, ClaimsPrincipal principal, AppDbContext db) =>
{
    var uid = UserId(principal);
    var p = await db.ChapterProgresses
        .FirstOrDefaultAsync(cp => cp.UserId == uid && cp.ChapterId == chapterId);
    if (p is not null)
    {
        p.IsListened = false;
        p.PositionSeconds = 0;
        await db.SaveChangesAsync();
    }
    return Results.Ok();
});

app.MapPost("/api/chapters/{chapterId:int}/complete", [Authorize] async (int chapterId, ClaimsPrincipal principal, AppDbContext db) =>
{
    var uid = UserId(principal);
    var chapter = await db.Chapters.FindAsync(chapterId);
    if (chapter is null) return Results.NotFound();

    var p = await db.ChapterProgresses
        .FirstOrDefaultAsync(cp => cp.UserId == uid && cp.ChapterId == chapterId);
    if (p is null)
    {
        p = new ChapterProgress { UserId = uid, ChapterId = chapterId };
        db.ChapterProgresses.Add(p);
    }
    p.IsListened = true;
    p.PositionSeconds = chapter.DurationSeconds;   // jump to the end so it reads as finished
    p.UpdatedAt = DateTime.UtcNow;
    await db.SaveChangesAsync();
    return Results.Ok();
});

app.MapPut("/api/chapters/{chapterId:int}", [Authorize] async (int chapterId, ChapterEditDto dto, AppDbContext db) =>
{
    var chapter = await db.Chapters.FindAsync(chapterId);
    if (chapter is null) return Results.NotFound();
    if (!string.IsNullOrWhiteSpace(dto.Title)) chapter.Title = dto.Title.Trim();
    if (dto.TrackNumber is int tn) chapter.TrackNumber = tn;
    await db.SaveChangesAsync();
    return Results.Ok();
});

app.MapPost("/api/books/{bookId:int}/reset", [Authorize] async (int bookId, ClaimsPrincipal principal, AppDbContext db) =>
{
    var uid = UserId(principal);
    var progresses = await db.ChapterProgresses
        .Where(p => p.UserId == uid && p.Chapter.BookId == bookId)
        .ToListAsync();
    foreach (var p in progresses) { p.IsListened = false; p.PositionSeconds = 0; }
    await db.SaveChangesAsync();
    return Results.Ok();
});

app.MapGet("/api/library/scan/preview", [Authorize] async (LibraryScanner scanner) =>
{
    var preview = await scanner.PreviewAsync();
    return Results.Ok(preview);
});

app.MapPost("/api/library/scan", [Authorize] async (LibraryScanner scanner) =>
{
    var added = await scanner.ScanAsync();
    return Results.Ok(new { added });
});


app.MapPut("/api/books/{id:int}", [Authorize] async (int id, BookUpdateRequest req, AppDbContext db) =>
{
    var book = await db.Books.FindAsync(id);
    if (book is null) return Results.NotFound();

    if (req.Title is not null) book.Title = req.Title;
    if (req.Author is not null) book.Author = req.Author;
    if (req.Narrator is not null) book.Narrator = req.Narrator;
    if (req.Description is not null) book.Description = req.Description;

    await db.SaveChangesAsync();
    return Results.Ok(book);
});

app.MapPost("/api/books/{id:int}/favorite", [Authorize] async (int id, ClaimsPrincipal principal, AppDbContext db) =>
{
    var uid = UserId(principal);
    var existing = await db.UserBookFavorites.FindAsync(uid, id);
    bool isFavorite;
    if (existing is not null)
    {
        db.UserBookFavorites.Remove(existing);
        isFavorite = false;
    }
    else
    {
        db.UserBookFavorites.Add(new Chronicler.Api.Models.UserBookFavorite { UserId = uid, BookId = id });
        isFavorite = true;
    }
    await db.SaveChangesAsync();
    return Results.Ok(new { isFavorite });
});

// ── Updates (mirrors CommandCenter pattern) ───────────────────────────────────

app.MapGet("/api/update/version", (IWebHostEnvironment env) =>
{
    var updatesDir = Path.Combine(env.ContentRootPath, "updates");
    var latest = GetLatestApk(updatesDir);
    return Results.Ok(new { version = latest is null ? "0.0.0" : GetVersionFromApkPath(latest) });
});

app.MapGet("/api/update/apk", (IWebHostEnvironment env) =>
{
    var updatesDir = Path.Combine(env.ContentRootPath, "updates");
    var path = GetLatestApk(updatesDir) ?? Path.Combine(updatesDir, "Chronicler.apk");
    if (!File.Exists(path)) return Results.NotFound(new { error = "No APK available" });
    return Results.File(path, "application/vnd.android.package-archive", Path.GetFileName(path));
});

app.MapGet("/api/update/apk/{fileName}", (string fileName, IWebHostEnvironment env) =>
{
    if (!fileName.EndsWith(".apk", StringComparison.OrdinalIgnoreCase))
        return Results.BadRequest(new { error = "Invalid file" });

    var path = Path.Combine(env.ContentRootPath, "updates", fileName);
    if (!File.Exists(path)) return Results.NotFound();
    return Results.File(path, "application/vnd.android.package-archive", fileName);
});

// ── Install page ──────────────────────────────────────────────────────────────

app.MapGet("/install", (HttpRequest req, IWebHostEnvironment env) =>
{
    var baseUrl = $"{req.Scheme}://{req.Host}";
    var apkUrl = $"{baseUrl}/api/update/apk";
    var updatesDir = Path.Combine(env.ContentRootPath, "updates");
    var latest = GetLatestApk(updatesDir);
    var version = latest is null ? null : GetVersionFromApkPath(latest);
    var hasApk = latest is not null && File.Exists(latest);

    // Generate QR code as SVG
    string qrSvg;
    using var qrGen = new QRCodeGenerator();
    var qrData = qrGen.CreateQrCode(apkUrl, QRCodeGenerator.ECCLevel.M);
    using var qrCode = new SvgQRCode(qrData);
    qrSvg = qrCode.GetGraphic(4, "#e8d5a8", "#160f07");

    var versionBadge = version is not null
        ? $"<span class=\"version\">v{version}</span>"
        : "<span class=\"version no-apk\">No APK built yet</span>";

    var downloadSection = hasApk
        ? $"""
          <a href="/api/update/apk" class="download-btn">⬇ Download APK</a>
          <p class="hint">Tap the button or scan the code on your Android device</p>
          """
        : """<p class="hint warn">Run <code>./deploy.sh</code> to build the first APK, then reload this page.</p>""";

    var html = $$"""
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8"/>
          <meta name="viewport" content="width=device-width, initial-scale=1"/>
          <title>Install Chronicler</title>
          <style>
            @import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@400;700&family=Lora:ital@0;1&display=swap');
            *{box-sizing:border-box;margin:0;padding:0}
            body{
              background:#0a0704;
              background-image:
                radial-gradient(ellipse at 20% 50%,rgba(100,60,10,.15) 0%,transparent 60%),
                radial-gradient(ellipse at 80% 20%,rgba(80,40,5,.12) 0%,transparent 50%);
              color:#e8d5a8;
              font-family:'Lora',Georgia,serif;
              min-height:100vh;
              display:flex;align-items:center;justify-content:center;
              padding:1.5rem;
            }
            .card{
              background:#160f07;
              border:1px solid #c8860a;
              border-radius:4px;
              padding:2.5rem 2rem;
              max-width:420px;
              width:100%;
              text-align:center;
              display:flex;flex-direction:column;gap:1.4rem;
              box-shadow:0 0 24px #c8860a50,0 20px 60px rgba(0,0,0,.7);
              position:relative;
            }
            .card::before{content:'✦';position:absolute;top:.6rem;left:.8rem;color:#7a5010;opacity:.6;font-size:1.1rem}
            .card::after{content:'✦';position:absolute;bottom:.6rem;right:.8rem;color:#7a5010;opacity:.6;font-size:1.1rem}
            h1{font-family:'Cinzel',serif;font-size:2rem;color:#e8a820;text-shadow:0 0 14px #c8860a60;letter-spacing:2px}
            .subtitle{color:#9a8060;font-style:italic;font-size:.875rem}
            .version{
              display:inline-block;background:#3d280f;border:1px solid #7a5010;
              border-radius:3px;padding:.2rem .7rem;
              font-family:'Cinzel',serif;font-size:.75rem;letter-spacing:1px;color:#c8860a;
            }
            .version.no-apk{color:#8b3510;border-color:#8b3510}
            .qr-frame{
              background:#0a0704;border:2px solid #7a5010;
              border-radius:4px;padding:.75rem;margin:0 auto;
              width:fit-content;
              box-shadow:inset 0 0 20px rgba(200,134,10,.08);
            }
            .qr-frame svg{display:block;width:200px;height:200px}
            .download-btn{
              display:inline-block;
              background:linear-gradient(135deg,#7a5010,#c8860a);
              color:#0a0704;padding:.75rem 2rem;border-radius:3px;
              font-family:'Cinzel',serif;font-size:.85rem;letter-spacing:1px;
              text-decoration:none;font-weight:700;
              border:1px solid #e8a820;
              box-shadow:0 0 12px #c8860a60;
              transition:all .15s;
            }
            .download-btn:hover{background:linear-gradient(135deg,#c8860a,#e8a820)}
            .hint{color:#9a8060;font-size:.8rem;font-style:italic}
            .hint.warn{color:#b5601a}
            .hint code{
              background:#1e1508;border:1px solid #3d280f;
              padding:.1rem .4rem;border-radius:3px;
              font-family:monospace;font-size:.8rem;color:#c8860a;
            }
            .ios-note{
              border-top:1px solid #3d280f;padding-top:1rem;
              font-size:.78rem;color:#9a8060;font-style:italic;line-height:1.6;
            }
            .url{
              font-family:monospace;font-size:.75rem;color:#7a5010;
              word-break:break-all;
            }
          </style>
        </head>
        <body>
          <div class="card">
            <div>
              <h1>Chronicler</h1>
              <p class="subtitle">Android Installation</p>
            </div>
            {{versionBadge}}
            <div class="qr-frame">{{qrSvg}}</div>
            {{downloadSection}}
            <p class="url">{{apkUrl}}</p>
            <p class="ios-note">
              <strong style="color:#c8860a;font-style:normal">iOS:</strong>
              Install via Xcode during development, or AltStore for sideloading.
              TestFlight requires an Apple Developer account.
            </p>
          </div>
        </body>
        </html>
        """;

    return Results.Content(html, "text/html");
});

// ── Helpers ───────────────────────────────────────────────────────────────────

// ── Helpers ──────────────────────────────────────────────────────────────────

app.Run();

static string UserId(ClaimsPrincipal p) =>
    p.FindFirstValue(ClaimTypes.NameIdentifier) ?? "default";

static string CreateToken(AppUser user, string key)
{
    var claims = new[]
    {
        new Claim(ClaimTypes.NameIdentifier, user.Id),
        new Claim(ClaimTypes.Email, user.Email ?? ""),
        new Claim(ClaimTypes.Name, user.UserName ?? "")
    };

    var creds = new SigningCredentials(
        new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)),
        SecurityAlgorithms.HmacSha256);

    var token = new JwtSecurityToken(
        claims: claims,
        expires: DateTime.UtcNow.AddDays(90),
        signingCredentials: creds);

    return new JwtSecurityTokenHandler().WriteToken(token);
}

static string? GetLatestApk(string dir)
{
    if (!Directory.Exists(dir)) return null;
    return Directory.GetFiles(dir, "Chronicler-v*.apk")
        .Select(p => new { Path = p, Ver = TryParseApkVersion(p) })
        .Where(x => x.Ver is not null)
        .OrderByDescending(x => x.Ver)
        .FirstOrDefault()?.Path;
}

static Version? TryParseApkVersion(string path)
{
    var name = Path.GetFileNameWithoutExtension(path).Replace("Chronicler-v", "");
    return Version.TryParse(name, out var v) ? v : null;
}

static string GetVersionFromApkPath(string path)
{
    var name = Path.GetFileNameWithoutExtension(path);
    var idx = name.IndexOf("-v", StringComparison.OrdinalIgnoreCase);
    return idx >= 0 ? name[(idx + 2)..] : "0.0.0";
}

// Audio MIME from file extension. Cast (Android CastPlayer) requires an explicit
// mimeType on the MediaItem or it crashes — so chapters expose theirs here.
static string AudioMime(string path) => Path.GetExtension(path).ToLower() switch
{
    ".mp3" => "audio/mpeg",
    ".m4b" or ".m4a" => "audio/mp4",
    ".ogg" => "audio/ogg",
    ".opus" => "audio/ogg; codecs=opus",
    ".flac" => "audio/flac",
    ".aac" => "audio/aac",
    ".wav" => "audio/wav",
    _ => "application/octet-stream"
};

// ── Request/Response types ────────────────────────────────────────────────────

record RegisterRequest(string Email, string Password);
record LoginRequest(string Email, string Password);
record BookUpdateRequest(string? Title, string? Author, string? Narrator, string? Description);
record DiagMessage(string Message);
record BookDto(int Id, string Title, string Author, string? Narrator, double DurationSeconds,
    bool HasCover, DateTime AddedAt, int ChapterCount = 0, int ListenedCount = 0, int? Year = null, bool IsFavorite = false,
    int? CollectionId = null, string? Description = null, int? SortOrder = null);
record CollectionDto(int Id, string Name, bool HasCover, int BookCount, DateTime AddedAt);
record ChapterDto(int Id, int BookId, string Title, int TrackNumber, string MimeType = "audio/mpeg");
record BookMetaRequest(string? Title, string? Author, string? Narrator, string? Description, int? Year);
record ChapterProgressRequest(double PositionSeconds, double DurationSeconds);
record ChapterEditDto(string? Title, int? TrackNumber);
