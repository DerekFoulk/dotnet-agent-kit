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
/// types or a plain .NET type, such as a Guid, a list or ProblemDetails, and so is each generic argument and array
/// element. The types come from ApiExplorer, which the built-in OpenAPI document is made from, so every endpoint the
/// document describes counts, wherever it's mapped, Program.cs too.
/// </summary>
public sealed class ContractTypeTests
{
    // .NET's own types that carry no entity, beside the primitives: plain values, collections (their definitions, whose
    // arguments are checked in turn), Problem Details, and files in and out.
    private static readonly HashSet<Type> s_plain =
    [
        typeof(string), typeof(decimal), typeof(DateTime), typeof(DateTimeOffset), typeof(DateOnly), typeof(TimeOnly),
        typeof(TimeSpan), typeof(Guid), typeof(Uri), typeof(Nullable<>),
        typeof(IEnumerable<>), typeof(IAsyncEnumerable<>), typeof(ICollection<>), typeof(IReadOnlyCollection<>), typeof(IList<>),
        typeof(IReadOnlyList<>), typeof(List<>), typeof(ISet<>), typeof(IReadOnlySet<>), typeof(HashSet<>),
        typeof(IDictionary<,>), typeof(IReadOnlyDictionary<,>), typeof(Dictionary<,>),
        typeof(ProblemDetails), typeof(HttpValidationProblemDetails), typeof(IFormFile), typeof(IFormFileCollection), typeof(Stream),
    ];

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

    // An endpoint that declares no success response, such as one returning an untyped IResult or object, would hide the
    // type it answers with from the check above, so every endpoint declares one (typed results, API-003); and an API
    // host describes at least one endpoint, or the check above would pass on nothing. An endpoint left out of the
    // document (ExcludeFromDescription) isn't described at all; code review checks those.
    [Theory]
    [EachHost]
    public void EveryEndpointDeclaresWhatItAnswersOnSuccess(string host)
    {
        HostUnderTest described = AppHost.Named(host);
        Assert.SkipUnless(described.ServesHttpApi, AppHost.NoHttpApi);
        using IAppUnderTest app = described.Start(Environments.Development);
        List<ApiDescription> endpoints = [.. app.Services.GetRequiredService<IApiDescriptionGroupCollectionProvider>()
            .ApiDescriptionGroups.Items.SelectMany(group => group.Items)];

        endpoints.Should().NotBeEmpty("a host that serves an HTTP API describes its endpoints");
        endpoints.Where(endpoint => !endpoint.SupportedResponseTypes.Any(response => response.StatusCode is >= 200 and < 300))
            .Select(endpoint => $"{endpoint.HttpMethod} {endpoint.RelativePath}")
            .Should().BeEmpty("each endpoint declares its success response with typed results (API-003), so its type is checked (SEC-013)");
    }

    // .NET's own types carry no entity: plain values, collections of them, Problem Details and files. A type that can
    // carry anything, such as object or a JSON document, or any other framework or library type (IdentityUser, say),
    // isn't one: a Contracts type wraps what the endpoint needs from it.
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

    private static bool IsDotNets(Type type) => type.IsPrimitive || s_plain.Contains(type);
}
