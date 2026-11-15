using System.Xml;

namespace DtdParse;

// DTD parsing, which lets input pull in files and URLs; CA3075 to CA3077 stayed silent on it (SEC-014).
internal static class Code
{
    internal static XmlReaderSettings Settings() => new() { DtdProcessing = DtdProcessing.Parse };
}
