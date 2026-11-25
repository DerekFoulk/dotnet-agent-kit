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

    /// <summary>One row for each host, its name first.</summary>
    public static IReadOnlyList<object?[]> Rows(IReadOnlyCollection<string> hosts, IReadOnlyList<object?> values)
    {
        ArgumentNullException.ThrowIfNull(hosts);
        ArgumentNullException.ThrowIfNull(values);
        return [.. hosts.Select(host => (object?[])[host, .. values])];
    }

    public override ValueTask<IReadOnlyCollection<ITheoryDataRow>> GetData(MethodInfo testMethod, DisposalTracker disposalTracker) =>
        new([.. Rows([.. AppHost.Hosts.Select(host => host.Name)], Values).Select(row => ConvertDataRow(row))]);

    public override bool SupportsDiscoveryEnumeration() => true;
}
