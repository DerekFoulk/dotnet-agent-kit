using Microsoft.AspNetCore.Mvc.ApiExplorer;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace Kit.AppTests.Functional;

/// <summary>
/// An HTTP endpoint accepts and returns only Contracts types, never a domain entity (SEC-013, OWASP API3): every type
/// the host's endpoints take as a body or form, or answer with, is one of the host's <see cref="HostUnderTest.ContractAssemblies"/>
/// types or .NET's own, such as ProblemDetails, and so is each generic argument and array element. The types come from
/// ApiExplorer, which the built-in OpenAPI document is made from, so endpoints mapped anywhere, in Program.cs too, count.
/// </summary>
public sealed class ContractTypeTests
{
    // The public key tokens Microsoft signs .NET's assemblies with: the runtime's, ASP.NET Core's and Microsoft.Extensions'.
    private static readonly HashSet<string> s_microsoftKeys = ["7cec85d7bea7798e", "b03f5f7f11d50a3a", "cc7b13ffcd2ddd51", "adb9793829ddae60", "31bf3856ad364e35"];

    [Theory]
    [EachHost]
    public void TheEndpointsAcceptAndReturnOnlyContractsTypes(string host)
    {
        HostUnderTest described = AppHost.Named(host);
        Assert.SkipUnless(described.ServesHttpApi, AppHost.NoHttpApi);
        using IAppUnderTest app = described.Start(Environments.Development);
        IApiDescriptionGroupCollectionProvider? explorer = app.Services.GetService<IApiDescriptionGroupCollectionProvider>();
        explorer.Should().NotBeNull("the built-in OpenAPI document is made from ApiExplorer's descriptions");

        IEnumerable<string> others = explorer!.ApiDescriptionGroups.Items.SelectMany(group => group.Items)
            .SelectMany(TypesOf)
            .SelectMany(Unwrapped)
            .Distinct()
            .Where(type => !described.ContractAssemblies.Contains(type.Assembly) && !IsDotNets(type))
            .Select(type => type.FullName ?? type.Name);

        others.Should().BeEmpty("an endpoint accepts and returns only Contracts types, never a domain entity (SEC-013)");
    }

    private static IEnumerable<Type> TypesOf(ApiDescription endpoint) =>
        endpoint.ParameterDescriptions
            .Where(parameter => parameter.Source == BindingSource.Body || parameter.Source == BindingSource.Form || parameter.Source == BindingSource.FormFile)
            .Select(parameter => parameter.Type)
            .Concat(endpoint.SupportedResponseTypes.Select(response => response.Type))
            .OfType<Type>()
            .Where(type => type != typeof(void));

    // The type, and each type it's made of: an array's element, a generic type's definition and arguments.
    private static IEnumerable<Type> Unwrapped(Type type) =>
        type.IsArray ? Unwrapped(type.GetElementType()!)
        : type.IsConstructedGenericType ? type.GenericTypeArguments.SelectMany(Unwrapped).Prepend(type.GetGenericTypeDefinition())
        : [type];

    private static bool IsDotNets(Type type) =>
        type.Assembly.GetName().GetPublicKeyToken() is { Length: > 0 } token && s_microsoftKeys.Contains(Convert.ToHexStringLower(token));
}
