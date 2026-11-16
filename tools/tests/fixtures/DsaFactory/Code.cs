using System.Security.Cryptography;

namespace DsaFactory;

// DSA, a weak signature algorithm, through its factory: CA5384 reports it, so BannedSymbols.txt needn't (SEC-014).
internal static class Code
{
    internal static DSA Create() => DSA.Create();
}
