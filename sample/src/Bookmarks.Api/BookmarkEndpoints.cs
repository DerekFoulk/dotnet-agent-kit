using System.ComponentModel.DataAnnotations;
using Bookmarks.Application.Features.Bookmarks;
using Bookmarks.Contracts;
using Microsoft.AspNetCore.Http.HttpResults;

namespace Bookmarks.Api;

/// <summary>The bookmarks HTTP API. Typed results let OpenAPI describe every response.</summary>
internal static class BookmarkEndpoints
{
    private const int MaxLimit = 100;

    // Offset paging reads and skips every earlier row, so deep offsets are capped too (Azure's API implementation guide).
    private const int MaxOffset = 10_000;

    public static IEndpointRouteBuilder MapBookmarks(this IEndpointRouteBuilder app)
    {
        RouteGroupBuilder bookmarks = app.MapGroup("/bookmarks").WithTags("Bookmarks");
        bookmarks.MapPost("/", CreateAsync).WithName("CreateBookmark")
            .ProducesProblem(StatusCodes.Status400BadRequest).ProducesProblem(StatusCodes.Status409Conflict);
        bookmarks.MapGet("/{id:guid}", GetAsync).WithName("GetBookmark").ProducesProblem(StatusCodes.Status404NotFound);
        bookmarks.MapGet("/", ListAsync).WithName("ListBookmarks").ProducesValidationProblem();
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

    // Offset paging with a default page of 25 and at most 100 (API-004); AddValidation rejects anything else with a
    // validation problem before this runs (API-006).
    private static async Task<Ok<BookmarkPage>> ListAsync(
        BookmarkService service, CancellationToken cancellationToken,
        [Range(0, MaxOffset)] int offset = 0, [Range(1, MaxLimit)] int limit = 25)
    {
        BookmarkListResult result = await service.ListAsync(offset, limit, cancellationToken);
        Uri? next = result.HasMore ? new Uri($"/bookmarks?offset={offset + limit}&limit={limit}", UriKind.Relative) : null;
        return TypedResults.Ok(new BookmarkPage(result.Items, next));
    }
}
