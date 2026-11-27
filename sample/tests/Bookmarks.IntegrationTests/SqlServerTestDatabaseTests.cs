using Bookmarks.TestDatabase;

namespace Bookmarks.IntegrationTests;

/// <summary>
/// What the database tests do without Docker (ADR-0098): a developer's run skips them and says why, and a CI run fails,
/// so a missing Docker never turns into a pass.
/// </summary>
public sealed class SqlServerTestDatabaseTests
{
    private const string Reason = "Docker is either not running or misconfigured.";

    [Fact]
    public void WithoutDockerACiRunFails()
    {
        Action act = () => SqlServerTestDatabase.WithoutDocker(Reason, inCi: true);

        act.Should().Throw<InvalidOperationException>().WithMessage($"*CI*{Reason}*");
    }

    [Fact]
    public void WithoutDockerALocalRunSkipsAndSaysToStartDocker()
    {
        Action act = () => SqlServerTestDatabase.WithoutDocker(Reason, inCi: false);

        act.Should().Throw<Xunit.Sdk.SkipException>().WithMessage($"*{Reason}*Start Docker*");
    }
}
