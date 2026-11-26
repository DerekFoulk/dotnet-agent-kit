using System.Reflection;

namespace Kit.AppTests.Functional;

/// <summary>
/// The host checks run once for each host the app lists in its part of <see cref="AppHost"/>, such as an API and a web
/// UI beside it (GAP-037): each check is a theory whose rows come from EachHost, with the host's name first.
/// </summary>
public sealed class EachHostTests
{
    [Fact]
    public void EveryHostCheckRunsOnceForEachHost()
    {
        IEnumerable<string> checks = typeof(EachHostTests).Assembly.GetExportedTypes()
            .Where(type => type.Namespace == typeof(EachHostTests).Namespace && type != typeof(EachHostTests))
            .SelectMany(type => type.GetMethods())
            .Where(method => method.GetCustomAttribute<FactAttribute>() is not null)
            .Where(method => !method.GetCustomAttributes<EachHostAttribute>().Any()
                || method.GetParameters() is not [{ Name: "host", ParameterType: var type }, ..] || type != typeof(string))
            .Select(method => $"{method.DeclaringType!.Name}.{method.Name}");

        checks.Should().BeEmpty("every host check takes its host's name first, from EachHost");
    }

    // The sample has one host, so these show the rows for two, as an API with a web UI beside it gets.
    [Fact]
    public void EachHostGetsARowWithItsNameFirst()
    {
        IReadOnlyList<object?[]> rows = EachHostAttribute.Rows(["Shop.Api", "Shop.Web"], ["/health", true]);

        rows.Should().HaveCount(2);
        rows[0].Should().Equal("Shop.Api", "/health", true);
        rows[1].Should().Equal("Shop.Web", "/health", true);
    }

    // A host's name names its rows and its contract snapshot's folder, so it must be one of its own, and a folder's.
    [Theory]
    [InlineData("")]
    [InlineData("Shop.Api|Shop.Api")]
    [InlineData("Shop Api")]
    [InlineData("Shop/Api")]
    [InlineData("Shop.Api|Shop.Api.")]
    [InlineData("Shop.Api|")]
    public void HostsNeedNamesOfTheirOwnThatCanNameAFolder(string names)
    {
        string[] hosts = string.IsNullOrEmpty(names) ? [] : names.Split('|');

        Action rows = () => EachHostAttribute.Rows(hosts, []);

        rows.Should().Throw<InvalidOperationException>().WithMessage("*AppHost.Hosts*");
    }
}
