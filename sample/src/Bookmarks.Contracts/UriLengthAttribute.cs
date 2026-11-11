using System.ComponentModel.DataAnnotations;

namespace Bookmarks.Contracts;

/// <summary>
/// Limits a URI to a number of characters, the way [MaxLength] limits a string; [MaxLength] itself
/// throws on a <see cref="Uri"/>, which has no length or count (SEC-010). An absolute URI is measured in its escaped
/// absolute form (<see cref="Uri.AbsoluteUri"/>), the form the sample stores, which can be longer than what was
/// written. A missing or relative URI is valid here: [Required] says whether one is needed, and a relative one has no
/// stored form to measure (the sample's domain refuses it).
/// </summary>
[AttributeUsage(AttributeTargets.Property | AttributeTargets.Field | AttributeTargets.Parameter)]
public sealed class UriLengthAttribute(int maximumLength) : ValidationAttribute
{
    /// <summary>The most characters the URI may have.</summary>
    public int MaximumLength { get; } = maximumLength;

    public override bool IsValid(object? value) => value is not Uri { IsAbsoluteUri: true } uri || uri.AbsoluteUri.Length <= MaximumLength;

    public override string FormatErrorMessage(string name) =>
        $"The field {name} must be a URI of at most {MaximumLength} characters.";
}
