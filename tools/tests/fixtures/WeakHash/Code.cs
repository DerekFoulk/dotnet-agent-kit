using System.Security.Cryptography;

namespace WeakHash;

internal static class Code
{
    internal static byte[] Hash(byte[] data) => SHA1.HashData(data);
}
