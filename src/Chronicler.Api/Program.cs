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

app.MapGet("/api/books", [Authorize] async (string? q, ClaimsPrincipal principal, AppDbContext db) =>
{
    var userId = (principal.FindFirstValue(ClaimTypes.NameIdentifier) ?? "default");
    var query = db.Books.AsQueryable();
    if (!string.IsNullOrWhiteSpace(q))
        query = query.Where(b =>
            b.Title.ToLower().Contains(q.ToLower()) ||
            b.Author.ToLower().Contains(q.ToLower()) ||
            (b.Narrator != null && b.Narrator.ToLower().Contains(q.ToLower())));

    var books = await query
        .OrderBy(b => b.Author).ThenBy(b => b.Title)
        .Select(b => new BookDto(
            b.Id, b.Title, b.Author, b.Narrator, b.DurationSeconds,
            b.CoverData != null, b.AddedAt,
            b.Chapters.Count(),
            b.Chapters.Count(c => c.Progresses.Any(p => p.UserId == userId && p.IsListened)),
            b.Year))
        .ToListAsync();

    return Results.Ok(books);
});

app.MapGet("/api/books/{id:int}", [Authorize] async (int id, AppDbContext db) =>
{
    var b = await db.Books.FindAsync(id);
    return b is null ? Results.NotFound() : Results.Ok(b);
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

// Clear wrong cover so it can be re-fetched
app.MapDelete("/api/books/{id:int}/cover", [Authorize] async (int id, AppDbContext db) =>
{
    var book = await db.Books.FindAsync(id);
    if (book is null) return Results.NotFound();

    book.CoverData = null;
    book.CoverMimeType = null;
    await db.SaveChangesAsync();
    return Results.Ok();
});


// ── Chapters ──────────────────────────────────────────────────────────────────

app.MapGet("/api/books/{bookId:int}/chapters", [Authorize] async (int bookId, AppDbContext db) =>
{
    var chapters = await db.Chapters
        .Where(c => c.BookId == bookId)
        .OrderBy(c => c.TrackNumber)
        .Select(c => new ChapterDto(c.Id, c.BookId, c.Title, c.TrackNumber))
        .ToListAsync();
    return Results.Ok(chapters);
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
    var p = await db.ChapterProgresses
        .FirstOrDefaultAsync(p => p.UserId == (principal.FindFirstValue(ClaimTypes.NameIdentifier) ?? "default") && p.ChapterId == chapterId);
    return Results.Ok(new { positionSeconds = p?.PositionSeconds ?? 0, isListened = p?.IsListened ?? false });
});

app.MapPut("/api/chapters/{chapterId:int}/progress", [Authorize] async (
    int chapterId, ChapterProgressRequest req, ClaimsPrincipal principal, AppDbContext db) =>
{
    var p = await db.ChapterProgresses
        .FirstOrDefaultAsync(cp => cp.UserId == (principal.FindFirstValue(ClaimTypes.NameIdentifier) ?? "default") && cp.ChapterId == chapterId);

    if (p is null)
    {
        p = new ChapterProgress { UserId = (principal.FindFirstValue(ClaimTypes.NameIdentifier) ?? "default"), ChapterId = chapterId };
        db.ChapterProgresses.Add(p);
    }

    p.PositionSeconds = req.PositionSeconds;
    p.UpdatedAt = DateTime.UtcNow;

    // Mark as listened if > 90% complete (requires duration from client)
    if (req.DurationSeconds > 0 && req.PositionSeconds / req.DurationSeconds >= 0.9)
        p.IsListened = true;

    await db.SaveChangesAsync();
    return Results.Ok();
});

app.MapPost("/api/chapters/{chapterId:int}/reset", [Authorize] async (int chapterId, ClaimsPrincipal principal, AppDbContext db) =>
{
    var p = await db.ChapterProgresses
        .FirstOrDefaultAsync(cp => cp.UserId == (principal.FindFirstValue(ClaimTypes.NameIdentifier) ?? "default") && cp.ChapterId == chapterId);
    if (p is not null)
    {
        p.IsListened = false;
        p.PositionSeconds = 0;
        await db.SaveChangesAsync();
    }
    return Results.Ok();
});

app.MapPost("/api/books/{bookId:int}/reset", [Authorize] async (int bookId, ClaimsPrincipal principal, AppDbContext db) =>
{
    var progresses = await db.ChapterProgresses
        .Where(p => p.UserId == (principal.FindFirstValue(ClaimTypes.NameIdentifier) ?? "default") && p.Chapter.BookId == bookId)
        .ToListAsync();
    foreach (var p in progresses) { p.IsListened = false; p.PositionSeconds = 0; }
    await db.SaveChangesAsync();
    return Results.Ok();
});

app.MapPost("/api/library/scan", async (LibraryScanner scanner) =>
{
    var added = await scanner.ScanAsync();
    return Results.Ok(new { added });
});


app.MapPut("/api/books/{id:int}", async (int id, BookUpdateRequest req, AppDbContext db) =>
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

// ── Progress ──────────────────────────────────────────────────────────────────

app.MapGet("/api/progress/{bookId:int}", [Authorize] async (int bookId, ClaimsPrincipal principal, AppDbContext db) =>
{
    var progress = await db.Progresses
        .FirstOrDefaultAsync(p => p.UserId == (principal.FindFirstValue(ClaimTypes.NameIdentifier) ?? "default") && p.BookId == bookId);
    return Results.Ok(new { positionSeconds = progress?.PositionSeconds ?? 0 });
});

app.MapPut("/api/progress/{bookId:int}", [Authorize] async (int bookId, ProgressRequest req, ClaimsPrincipal principal, AppDbContext db) =>
{
    var progress = await db.Progresses
        .FirstOrDefaultAsync(p => p.UserId == (principal.FindFirstValue(ClaimTypes.NameIdentifier) ?? "default") && p.BookId == bookId);

    if (progress is null)
    {
        progress = new UserProgress { UserId = (principal.FindFirstValue(ClaimTypes.NameIdentifier) ?? "default"), BookId = bookId };
        db.Progresses.Add(progress);
    }

    progress.PositionSeconds = req.PositionSeconds;
    progress.UpdatedAt = DateTime.UtcNow;
    await db.SaveChangesAsync();
    return Results.Ok();
});

// ── Bookmarks ─────────────────────────────────────────────────────────────────

app.MapGet("/api/bookmarks/{bookId:int}", [Authorize] async (int bookId, ClaimsPrincipal principal, AppDbContext db) =>
{
    var bookmarks = await db.Bookmarks
        .Where(b => b.UserId == (principal.FindFirstValue(ClaimTypes.NameIdentifier) ?? "default") && b.BookId == bookId)
        .OrderBy(b => b.PositionSeconds)
        .Select(b => new BookmarkDto(b.Id, b.BookId, b.PositionSeconds, b.Label, b.CreatedAt))
        .ToListAsync();
    return Results.Ok(bookmarks);
});

app.MapPost("/api/bookmarks/{bookId:int}", [Authorize] async (int bookId, BookmarkRequest req, ClaimsPrincipal principal, AppDbContext db) =>
{
    var bookmark = new Bookmark
    {
        UserId = (principal.FindFirstValue(ClaimTypes.NameIdentifier) ?? "default"),
        BookId = bookId,
        PositionSeconds = req.PositionSeconds,
        Label = req.Label
    };
    db.Bookmarks.Add(bookmark);
    await db.SaveChangesAsync();
    return Results.Ok(new BookmarkDto(bookmark.Id, bookmark.BookId,
        bookmark.PositionSeconds, bookmark.Label, bookmark.CreatedAt));
});

app.MapDelete("/api/bookmarks/{id:int}", [Authorize] async (int id, ClaimsPrincipal principal, AppDbContext db) =>
{
    var bookmark = await db.Bookmarks.FindAsync(id);
    if (bookmark is null) return Results.NotFound();

    db.Bookmarks.Remove(bookmark);
    await db.SaveChangesAsync();
    return Results.Ok();
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

app.Run();

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

// ── Request/Response types ────────────────────────────────────────────────────

record RegisterRequest(string Email, string Password);
record LoginRequest(string Email, string Password);
record ProgressRequest(double PositionSeconds);
record BookmarkRequest(double PositionSeconds, string? Label);
record BookmarkDto(int Id, int BookId, double PositionSeconds, string? Label, DateTime CreatedAt);
record BookUpdateRequest(string? Title, string? Author, string? Narrator, string? Description);
record DiagMessage(string Message);
record BookDto(int Id, string Title, string Author, string? Narrator, double DurationSeconds,
    bool HasCover, DateTime AddedAt, int ChapterCount = 0, int ListenedCount = 0, int? Year = null);
record ChapterDto(int Id, int BookId, string Title, int TrackNumber);
record BookMetaRequest(string? Title, string? Author, string? Narrator, string? Description, int? Year);
record ChapterProgressRequest(double PositionSeconds, double DurationSeconds);
