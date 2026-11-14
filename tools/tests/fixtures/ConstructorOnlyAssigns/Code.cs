namespace ConstructorOnlyAssigns;

// STY-007: a primary constructor where a constructor only assigns its parameters (IDE0290).
public sealed class Greeting
{
    private readonly string _name;

    public Greeting(string name)
    {
        _name = name;
    }

    public string Greet(string greeting) => greeting + ", " + _name;
}
