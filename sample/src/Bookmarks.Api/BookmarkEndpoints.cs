using Bookmarks.Application.Features.Bookmarks;
using Bookmarks.Contracts;

namespace Bookmarks.Api;

/// <summary>The bookmarks HTTP API.</summary>
internal static class BookmarkEndpoints
{
    public static IEndpointRouteBuilder MapBookmarks(this IEndpointRouteBuilder app)
    {
        RouteGroupBuilder bookmarks = app.MapGroup("/bookmarks").WithTags("Bookmarks");
        bookmarks.MapPost("/", CreateAsync).WithName("CreateBookmark");
        bookmarks.MapGet("/{id:guid}", GetAsync).WithName("GetBookmark");
        bookmarks.MapGet("/", ListAsync).WithName("ListBookmarks");
        return app;
    }

    private static async Task<IResult> CreateAsync(CreateBookmarkRequest request, BookmarkService service, CancellationToken cancellationToken)
    {
        AddBookmarkResult result;
        try
        {
            result = await service.AddAsync(request, cancellationToken);
        }
        catch (ArgumentException ex)
        {
            return TypedResults.Problem(ex.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return result.Bookmark is { } bookmark
            ? TypedResults.Created($"/bookmarks/{bookmark.Id}", bookmark)
            : TypedResults.Conflict();
    }

    private static async Task<IResult> GetAsync(Guid id, BookmarkService service, CancellationToken cancellationToken)
    {
        BookmarkResponse? bookmark = await service.GetAsync(id, cancellationToken);
        return bookmark is null ? TypedResults.NotFound() : TypedResults.Ok(bookmark);
    }

    private static async Task<IResult> ListAsync(BookmarkService service, CancellationToken cancellationToken) =>
        TypedResults.Ok(await service.ListAsync(cancellationToken));
}
