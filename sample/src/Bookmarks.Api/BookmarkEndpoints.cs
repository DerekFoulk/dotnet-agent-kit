using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Bookmarks.Application.Features.Bookmarks;
using Bookmarks.Contracts;
using Microsoft.AspNetCore.Http.HttpResults;

namespace Bookmarks.Api;

/// <summary>The bookmarks HTTP API. Typed results describe each success in OpenAPI, and ProducesProblem each error body.</summary>
internal static class BookmarkEndpoints
{
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
        CreateBookmarkRequest request, ClaimsPrincipal user, BookmarkService service, CancellationToken cancellationToken)
    {
        AddBookmarkResult result;
        try
        {
            result = await service.AddAsync(user.UserId(), request, cancellationToken);
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
        Guid id, ClaimsPrincipal user, BookmarkService service, CancellationToken cancellationToken)
    {
        BookmarkResponse? bookmark = await service.GetAsync(user.UserId(), id, cancellationToken);
        return bookmark is null ? TypedResults.NotFound() : TypedResults.Ok(bookmark);
    }

    // Offset paging with a default page of 25 and at most 100 (API-004); AddValidation rejects anything else with a
    // validation problem before this runs (API-006).
    private static async Task<Ok<BookmarkPage>> ListAsync(
        ClaimsPrincipal user, BookmarkService service, CancellationToken cancellationToken,
        [Range(0, BookmarkService.MaxOffset)] int offset = 0, [Range(1, BookmarkService.MaxPageSize)] int limit = 25)
    {
        BookmarkListResult result = await service.ListAsync(user.UserId(), offset, limit, cancellationToken);
        Uri? next = result.HasMore ? new Uri($"/bookmarks?offset={offset + limit}&limit={limit}", UriKind.Relative) : null;
        return TypedResults.Ok(new BookmarkPage(result.Items, next));
    }
}
