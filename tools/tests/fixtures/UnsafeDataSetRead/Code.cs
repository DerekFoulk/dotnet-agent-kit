using System.Data;

namespace UnsafeDataSetRead;

internal static class Code
{
    internal static DataSet Read(Stream stream)
    {
        DataSet set = new();
        set.ReadXml(stream);
        return set;
    }
}
