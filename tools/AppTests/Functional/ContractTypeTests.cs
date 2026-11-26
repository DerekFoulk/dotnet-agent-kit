using System.Reflection;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
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
            .Where(type => !Passes(type, described.ContractAssemblies))
            .Select(type => type.FullName ?? type.Name);

        others.Should().BeEmpty("an endpoint accepts and returns only Contracts types, never a domain entity (SEC-013)");
    }

    // .NET's own types carry no entity: plain values, collections of them, Problem Details and files. A type that can
    // carry anything, such as object or a JSON document, or any other framework or library type, isn't one.
    [Theory]
    [EachHost(typeof(object), false)]
    [EachHost(typeof(JsonElement), false)]
    [EachHost(typeof(JsonObject), false)]
    [EachHost(typeof(HttpContext), false)]
    [EachHost(typeof(string), true)]
    [EachHost(typeof(Guid), true)]
    [EachHost(typeof(List<>), true)]
    [EachHost(typeof(ProblemDetails), true)]
    public void OnlyPlainDotNetTypesPassBesideTheContracts(string host, Type type, bool passes)
    {
        ArgumentNullException.ThrowIfNull(type);

        Passes(type, AppHost.Named(host).ContractAssemblies).Should().Be(passes, $"{type.Name} is {(passes ? string.Empty : "not ")}a plain .NET type");
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

    private static bool Passes(Type type, IReadOnlyCollection<Assembly> contracts) =>
        contracts.Contains(type.Assembly) || IsDotNets(type);

    private static bool IsDotNets(Type type) =>
        type.Assembly.GetName().GetPublicKeyToken() is { Length: > 0 } token && s_microsoftKeys.Contains(Convert.ToHexStringLower(token));
}
