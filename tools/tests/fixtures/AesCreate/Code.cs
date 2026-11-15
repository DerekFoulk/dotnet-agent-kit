using System.Security.Cryptography;

namespace AesCreate;

// Aes.Create gives CBC with no integrity check, which CA5358 approves (SEC-014).
internal static class Code
{
    internal static Aes Create() => Aes.Create();
}
