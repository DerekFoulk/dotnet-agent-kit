using System.Security.Cryptography;

namespace ObsoleteCryptoType;

internal static class Code
{
    internal static object Create() => new AesManaged();
}
