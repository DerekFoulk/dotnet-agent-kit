using System.Xml;

namespace XmlResolverUse;

// A resolver that fetches the external references the input names (SEC-014).
internal static class Code
{
    internal static XmlResolver Create() => new XmlUrlResolver();
}
