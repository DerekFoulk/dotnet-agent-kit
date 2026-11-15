using System.Xml;

namespace LegacyXmlReader;

// The legacy reader, with no safe default (SEC-014).
internal static class Code
{
    internal static XmlReader Create(Stream stream) => new XmlTextReader(stream);
}
