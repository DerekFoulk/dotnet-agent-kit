using System.Runtime.InteropServices;

namespace DllImportUsed;

// Microsoft's native interoperability page: [LibraryImport] over [DllImport] on .NET 7 and later (SYSLIB1054).
internal static partial class NativeMethods
{
    [DllImport("user32.dll")]
    [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
    internal static extern int GetDoubleClickTime();
}
