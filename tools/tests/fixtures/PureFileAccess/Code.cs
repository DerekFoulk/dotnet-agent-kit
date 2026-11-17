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

    internal static TextReader FromStream(Stream stream) => new StreamReader(stream);

    internal static TextWriter ToStream(Stream stream) => new StreamWriter(stream);

    internal static void Unzip(System.IO.Compression.ZipArchive zip, string folder) => System.IO.Compression.ZipFileExtensions.ExtractToDirectory(zip, folder);

    internal static void Untar(string archive, string folder) => System.Formats.Tar.TarFile.ExtractToDirectory(archive, folder, overwriteFiles: false);

    internal static IEnumerable<string> List(string folder) =>
        new System.IO.Enumeration.FileSystemEnumerable<string>(folder, (ref System.IO.Enumeration.FileSystemEntry entry) => entry.ToFullPath());

    internal static string Home() => AppContext.BaseDirectory;

    internal static string Location() => typeof(Code).Assembly.Location;
}
