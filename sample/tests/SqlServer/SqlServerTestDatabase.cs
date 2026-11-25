namespace Bookmarks.TestDatabase;

/// <summary>The SQL Server the sample's tests run against (DAT-005, ADR-0098).</summary>
internal static class SqlServerTestDatabase
{
    /// <summary>
    /// What a test does when Docker isn't running: on a developer's machine it's skipped, with the reason and what to
    /// do; in CI it fails, since a run that skipped every database test would prove nothing.
    /// </summary>
    /// <param name="reason">Testcontainers' own message.</param>
    /// <param name="inCi">Whether this is a CI run.</param>
    internal static void WithoutDocker(string reason, bool inCi)
    {
        if (inCi)
        {
            throw new InvalidOperationException($"This CI run has no Docker, so the database tests can't run on SQL Server: {reason}");
        }

        Assert.Skip($"These tests need SQL Server in Docker, and Docker isn't available: {reason} Start Docker Desktop and run them again; CI runs them on every pull request.");
    }
}
