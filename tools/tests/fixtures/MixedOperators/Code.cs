namespace MixedOperators;

// STY-007: parentheses where operators of different precedence meet (IDE0048).
public static class Price
{
    public static int Total(int unitPrice, int count, int shipping) => unitPrice * count + shipping;
}
