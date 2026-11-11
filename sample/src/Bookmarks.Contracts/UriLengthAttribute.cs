using System.ComponentModel.DataAnnotations;

namespace Bookmarks.Contracts;

/// <summary>
/// Limits a URI to a number of characters, the way [MaxLength] limits a string; [MaxLength] itself
/// throws on a <see cref="Uri"/>, which has no length or count (SEC-010). An absolute URI is measured in its escaped
/// absolute form (<see cref="Uri.AbsoluteUri"/>), the form the sample stores, which can be longer than what was
/// written; a relative one as written. A missing URI is valid here: [Required] says whether one is needed.
/// </summary>
[AttributeUsage(AttributeTargets.Property | AttributeTargets.Field | AttributeTargets.Parameter)]
public sealed class UriLengthAttribute(int maximumLength) : ValidationAttribute
{
    /// <summary>The most characters the URI may have.</summary>
    public int MaximumLength { get; } = maximumLength;

    public override bool IsValid(object? value) => value is not Uri uri || (uri.IsAbsoluteUri ? uri.AbsoluteUri : uri.OriginalString).Length <= MaximumLength;

    public override string FormatErrorMessage(string name) =>
        $"The field {name} must be a URI of at most {MaximumLength} characters.";
}
