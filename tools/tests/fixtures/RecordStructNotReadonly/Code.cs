namespace RecordStructNotReadonly;

// C#'s records page: a record struct's members are read-write unless it's declared readonly (IDE0250, STY-009).
internal record struct Size
{
    internal int Width { get; init; }
}
