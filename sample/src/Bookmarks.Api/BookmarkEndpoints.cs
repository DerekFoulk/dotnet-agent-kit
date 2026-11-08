using Bookmarks.Application.Features.Bookmarks;
using Bookmarks.Contracts;
using Microsoft.AspNetCore.Http.HttpResults;

namespace Bookmarks.Api;

/// <summary>The bookmarks HTTP API. Typed results let OpenAPI describe every response.</summary>
internal static class BookmarkEndpoints
{
    public static IEndpointRouteBuilder MapBookmarks(this IEndpointRouteBuilder app)
    {
        RouteGroupBuilder bookmarks = app.MapGroup("/bookmarks").WithTags("Bookmarks");
        bookmarks.MapPost("/", CreateAsync).WithName("CreateBookmark").ProducesProblem(StatusCodes.Status400BadRequest);
        bookmarks.MapGet("/{id:guid}", GetAsync).WithName("GetBookmark");
        bookmarks.MapGet("/", ListAsync).WithName("ListBookmarks");
        return app;
    }

    private static async Task<Results<Created<BookmarkResponse>, Conflict, ProblemHttpResult>> CreateAsync(
        CreateBookmarkRequest request, BookmarkService service, CancellationToken cancellationToken)
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

    private static async Task<Results<Ok<BookmarkResponse>, NotFound>> GetAsync(
        Guid id, BookmarkService service, CancellationToken cancellationToken)
    {
        BookmarkResponse? bookmark = await service.GetAsync(id, cancellationToken);
        return bookmark is null ? TypedResults.NotFound() : TypedResults.Ok(bookmark);
    }

    // Offset paging with a default page of 25 (API-004).
    private static async Task<Ok<BookmarkPage>> ListAsync(
        BookmarkService service, CancellationToken cancellationToken, int offset = 0, int limit = 25)
    {
        BookmarkListResult result = await service.ListAsync(offset, limit, cancellationToken);
        Uri? next = result.HasMore ? new Uri($"/bookmarks?offset={offset + limit}&limit={limit}", UriKind.Relative) : null;
        return TypedResults.Ok(new BookmarkPage(result.Items, next));
    }
}
