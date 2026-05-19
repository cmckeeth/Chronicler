using Chronicler.Shared.Services;
using Chronicler.Web.Components;

var builder = WebApplication.CreateBuilder(args);

var apiBase = builder.Configuration["ApiBaseUrl"]
    ?? Environment.GetEnvironmentVariable("CHRONICLER_API_URL")
    ?? "http://localhost:5160";

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

builder.Services.AddScoped<ApiClient>(_ =>
    new ApiClient(new HttpClient { BaseAddress = new Uri(apiBase.TrimEnd('/') + "/") }));

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseAntiforgery();
app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
