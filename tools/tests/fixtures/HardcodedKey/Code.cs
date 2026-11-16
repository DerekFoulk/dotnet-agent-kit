using System.Security.Cryptography;

namespace HardcodedKey;

internal static class Code
{
    internal static void Use(Aes aes)
    {
        ArgumentNullException.ThrowIfNull(aes);
        aes.Key = new byte[] { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
    }
}
