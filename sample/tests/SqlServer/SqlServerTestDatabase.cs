using System.Diagnostics.CodeAnalysis;
using System.Reflection;
using System.Security.Cryptography;
using Bookmarks.Infrastructure;
using DotNet.Testcontainers.Builders;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Testcontainers.MsSql;

namespace Bookmarks.TestDatabase;

/// <summary>
/// The SQL Server the sample's tests run against (DAT-005, ADR-0098): one container for the test process, started the
/// first time a test asks for a database, and a new database for each test or host, so tests never see each other's
/// rows. Testcontainers' resource reaper removes the container when the process ends.
/// </summary>
internal static class SqlServerTestDatabase
{
    private const string PinKey = "SqlServerImagePin";

    // Started once and shared. A failed start, such as no Docker, is kept too, so every test after the first fails or
    // skips at once instead of waiting for Docker again.
    private static readonly Lazy<Task<MsSqlContainer>> s_server = new(() => Task.Run(StartServerAsync));

    /// <summary>
    /// A connection string to a new database on the shared server, with the app's migrations applied, as a deployment
    /// applies them (DAT-002, DAT-005). Without Docker, the calling test is skipped on a developer's machine and fails in
    /// CI (<see cref="WithoutDocker"/>).
    /// </summary>
    public static string Create()
    {
        string connectionString = NewDatabase();
        DbContextOptions<BookmarksDbContext> options = new DbContextOptionsBuilder<BookmarksDbContext>().UseSqlServer(connectionString).Options;
        using BookmarksDbContext db = new(options);
        db.Database.Migrate();
        return connectionString;
    }

    /// <summary>
    /// What a test does when Docker isn't running: on a developer's machine it's skipped, with the reason and what to
    /// do; in CI it fails, since a run that skipped every database test would prove nothing.
    /// </summary>
    /// <param name="reason">Testcontainers' own message.</param>
    /// <param name="inCi">Whether this is a CI run.</param>
    [DoesNotReturn]
    internal static void WithoutDocker(string reason, bool inCi)
    {
        if (inCi)
        {
            throw new InvalidOperationException($"This CI run has no Docker, so the database tests can't run on SQL Server: {reason}");
        }

        Assert.Skip($"These tests need SQL Server in Docker, and Docker isn't available: {reason} Start Docker Desktop and run them again; CI runs them on every pull request.");
    }

    private static string NewDatabase()
    {
        MsSqlContainer server;
        try
        {
            // A test's constructor can't await, and the kit's AppHost.Start is synchronous, so this waits here. The
            // start runs on the thread pool (Task.Run above), so no test's synchronization context is captured.
            server = s_server.Value.GetAwaiter().GetResult();
        }
        catch (DockerUnavailableException exception)
        {
            WithoutDocker(exception.Message, InCi());
            throw; // Not reached: WithoutDocker skips or fails the test, but definite assignment can't see that.
        }

        return new SqlConnectionStringBuilder(server.GetConnectionString()) { InitialCatalog = $"bookmarks-{Guid.NewGuid():N}" }.ConnectionString;
    }

    private static async Task<MsSqlContainer> StartServerAsync()
    {
        MsSqlContainer server = new MsSqlBuilder(Image()).WithPassword(NewPassword()).Build();
        await server.StartAsync().ConfigureAwait(false);
        return server;
    }

    // Testcontainers' default sa password is published in its source, and Docker publishes the server's port on every
    // interface, so each run makes its own: random hex, plus the lower-case letter and symbol SQL Server's password policy
    // asks for beside the digits and upper-case letters hex holds.
    private static string NewPassword() => Convert.ToHexString(RandomNumberGenerator.GetBytes(16)) + "a!";

    // GitHub Actions sets CI=true, and the shared CI passes it into the Playwright container the tests run in.
    private static bool InCi() => string.Equals(Environment.GetEnvironmentVariable("CI"), "true", StringComparison.OrdinalIgnoreCase);

    // The image the pin's FROM line names, by tag and digest.
    private static string Image()
    {
        string pin = typeof(SqlServerTestDatabase).Assembly.GetCustomAttributes<AssemblyMetadataAttribute>()
            .Single(attribute => attribute.Key == PinKey).Value
            ?? throw new InvalidOperationException($"The test project names no {PinKey}; it imports SqlServerTests.props.");
        const string From = "FROM ";
        return File.ReadLines(pin).Single(line => line.StartsWith(From, StringComparison.Ordinal))[From.Length..].Trim();
    }
}
