using System.Globalization;

namespace CatchAll;

public static class Parser
{
    public static int ParseOrZero(string text)
    {
        try
        {
            return int.Parse(text, CultureInfo.InvariantCulture);
        }
        catch (Exception)
        {
            return 0;
        }
    }
}
