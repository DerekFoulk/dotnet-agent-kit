using System.Security.Cryptography;

namespace BrokenHash;

internal static class Code
{
    internal static byte[] Hash(byte[] data) => MD5.HashData(data);
}
