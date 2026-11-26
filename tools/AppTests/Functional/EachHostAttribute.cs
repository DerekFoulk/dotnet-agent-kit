using System.Reflection;
using Xunit.Sdk;
using Xunit.v3;

namespace Kit.AppTests.Functional;

/// <summary>
/// A theory's rows, one for each host in <see cref="AppHost.Hosts"/>: the host's name, then this attribute's own
/// values. Put one on a theory for each row its other values make, as with InlineData. The rows are listed before the
/// run (discovery enumeration), so each host's row shows by name in the test list.
/// </summary>
[AttributeUsage(AttributeTargets.Method, AllowMultiple = true)]
internal sealed class EachHostAttribute(params object?[] values) : DataAttribute
{
    /// <summary>Gets the values that follow the host's name in each row.</summary>
    public IReadOnlyList<object?> Values { get; } = values;

    /// <summary>
    /// One row for each host, its name first. There must be a host, and each name must be its own and able to name a
    /// folder (letters, digits, '.', '-' and '_'), since it names the host's contract snapshot folder too.
    /// </summary>
    public static IReadOnlyList<object?[]> Rows(IReadOnlyCollection<string> hosts, IReadOnlyList<object?> values)
    {
        ArgumentNullException.ThrowIfNull(hosts);
        ArgumentNullException.ThrowIfNull(values);
        if (hosts.Count == 0)
        {
            throw new InvalidOperationException("AppHost.Hosts lists no host: the app's part of AppHost lists each host the checks start.");
        }

        if (hosts.FirstOrDefault(name => !CanNameAFolder(name)) is { } bad)
        {
            throw new InvalidOperationException($"AppHost.Hosts names a host '{bad}': a name is letters, digits, '.', '-' and '_', since it names a folder.");
        }

        if (hosts.GroupBy(name => name, StringComparer.OrdinalIgnoreCase).FirstOrDefault(group => group.Count() > 1) is { } repeated)
        {
            throw new InvalidOperationException($"AppHost.Hosts names two hosts '{repeated.Key}': each needs a name of its own.");
        }

        return [.. hosts.Select(host => (object?[])[host, .. values])];
    }

    public override ValueTask<IReadOnlyCollection<ITheoryDataRow>> GetData(MethodInfo testMethod, DisposalTracker disposalTracker) =>
        new([.. Rows([.. AppHost.Hosts.Select(host => host.Name)], Values).Select(row => ConvertDataRow(row))]);

    public override bool SupportsDiscoveryEnumeration() => true;

    private static bool CanNameAFolder(string name) =>
        name.Trim('.').Length > 0 && !name.EndsWith('.') && name.All(character => char.IsAsciiLetterOrDigit(character) || character is '.' or '-' or '_');
}
