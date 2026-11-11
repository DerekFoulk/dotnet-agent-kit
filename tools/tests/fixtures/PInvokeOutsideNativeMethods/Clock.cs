using System.Runtime.InteropServices;

namespace PInvokeOutsideNativeMethods;

// A P/Invoke declared outside a NativeMethods class: CA1060.
public static partial class Clock
{
    public static uint Ticks() => GetTickCount();

    [LibraryImport("kernel32.dll")]
    [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
    private static partial uint GetTickCount();
}
