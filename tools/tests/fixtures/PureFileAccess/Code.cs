namespace PureFileAccess;

// A pure assembly reads and writes files only through an injected abstraction, so its tests need no disk (ARC-008).
internal static class Code
{
    internal static string Read(string path) => File.ReadAllText(path);

    internal static bool Exists(string path) => Directory.Exists(path);

    internal static long Length(string path) => new FileInfo(path).Length;

    internal static string Name(string path) => new DirectoryInfo(path).Name;

    internal static Stream Open(string path) => new FileStream(path, FileMode.Open);

    internal static TextReader Reader(string path) => new StreamReader(path);

    internal static TextWriter Writer(string path) => new StreamWriter(path);

    internal static string Temporary() => Path.GetTempFileName();

    internal static string Full(string path) => Path.GetFullPath(path);

    internal static string Combined(string folder, string file) => Path.Combine(folder, file);
}
