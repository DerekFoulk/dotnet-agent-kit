using System.Security.Cryptography;

namespace DsaCreate;

// DSA, a weak signature algorithm CA5384 doesn't see through its factory (SEC-014).
internal static class Code
{
    internal static DSA Create() => DSA.Create();
}
