namespace InternalOperatorWithoutAlternate;

// FDG: an overloaded operator has a named alternative, such as Add for + (CA2225, a Usage rule), checked on internal
// types too (STY-009).
internal readonly record struct Money(decimal Amount)
{
    public static Money operator +(Money left, Money right) => new(left.Amount + right.Amount);
}
