namespace ObsoleteTimeZone;

// TimeZone is obsolete; Microsoft's date and time page says to use TimeZoneInfo (ARC-008).
internal static class Code
{
    internal static string Name() => TimeZone.CurrentTimeZone.StandardName;
}
