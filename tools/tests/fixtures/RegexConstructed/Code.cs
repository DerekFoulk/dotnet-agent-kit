using System.Text.RegularExpressions;

namespace RegexConstructed;

// Microsoft's regular expressions page: a source-generated regex ([GeneratedRegex]) over a constructed one (SYSLIB1045).
internal static class Code
{
    internal static bool Matches(string text) => Regex.IsMatch(text, "a+");
}
