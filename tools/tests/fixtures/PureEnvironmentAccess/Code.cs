using System.Diagnostics;

namespace PureEnvironmentAccess;

// A pure assembly reads its settings, the console and other processes only through injected abstractions, so its
// tests don't depend on the machine they run on (ARC-008).
internal static class Code
{
    internal static string? Setting(string name) => Environment.GetEnvironmentVariable(name);

    internal static string Folder() => Environment.CurrentDirectory;

    internal static long Ticks() => Environment.TickCount64;

    internal static string? Line() => Console.ReadLine();

    internal static Process Run(string file) => Process.Start(file);

    internal static long Elapsed() => Stopwatch.GetTimestamp();

    internal static string NewLine() => Environment.NewLine;

    internal static int Processors() => Environment.ProcessorCount;

    internal static Stream Pipe() => new System.IO.Pipes.AnonymousPipeServerStream();

    internal static TimeZoneInfo Zone() => TimeZoneInfo.Local;

    internal static DateTime Local(DateTime utc) => utc.ToLocalTime();

    internal static DateTime Universal(DateTime local) => local.ToUniversalTime();

    internal static DateTimeOffset LocalOffset(DateTimeOffset at) => at.ToLocalTime();

    internal static DateTime ToUtc(DateTime local) => TimeZoneInfo.ConvertTimeToUtc(local);
}
