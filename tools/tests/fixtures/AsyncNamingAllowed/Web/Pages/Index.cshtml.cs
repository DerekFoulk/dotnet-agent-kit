using System.Diagnostics.CodeAnalysis;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Web.Pages;

// A Razor Pages handler's documented async form is OnGetAsync.
[SuppressMessage("Performance", "CA1812:Avoid uninstantiated internal classes", Justification = "Razor Pages creates it; CA1812 can't see that.")]
internal sealed class IndexModel(TimeProvider clock) : PageModel
{
    internal DateTimeOffset Now { get; private set; }

    public async Task OnGetAsync()
    {
        await Task.Yield();
        Now = clock.GetUtcNow();
    }
}
