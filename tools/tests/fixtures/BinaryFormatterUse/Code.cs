using System.Runtime.Serialization.Formatters.Binary;

namespace BinaryFormatterUse;

internal static class Code
{
    internal static object Create() => new BinaryFormatter();
}
