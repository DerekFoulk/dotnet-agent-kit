using System.Security.Cryptography;

namespace CryptoConfigByName;

// An algorithm named at run time, which CA5350 and CA5351 can't check (SEC-014).
internal static class Code
{
    internal static object? Create(string name) => CryptoConfig.CreateFromName(name);
}
