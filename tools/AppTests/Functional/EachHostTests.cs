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
            .Where(method => !method.GetCustomAttributes().Any(attribute => attribute.GetType().Name == "EachHostAttribute")
                || method.GetParameters() is not [{ Name: "host", ParameterType: var type }, ..] || type != typeof(string))
            .Select(method => $"{method.DeclaringType!.Name}.{method.Name}");

        checks.Should().BeEmpty("every host check takes its host's name first, from EachHost");
    }
}
