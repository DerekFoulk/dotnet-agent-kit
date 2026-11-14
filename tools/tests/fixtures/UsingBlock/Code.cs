namespace UsingBlock;

// STY-007: a simple using declaration where a using block adds nothing (IDE0063).
public static class Reader
{
    public static int FirstByte(string path)
    {
        using (FileStream stream = File.OpenRead(path))
        {
            return stream.ReadByte();
        }
    }
}
