using System.Security.Cryptography;

namespace UnsafeCipherMode;

internal static class Code
{
    internal static void Use(Aes aes)
    {
        ArgumentNullException.ThrowIfNull(aes);
        aes.Mode = CipherMode.CFB;
    }
}
