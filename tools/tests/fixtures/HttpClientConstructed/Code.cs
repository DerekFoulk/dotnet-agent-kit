namespace HttpClientConstructed;

// A client built by hand skips IHttpClientFactory's pooled handlers and the standard resilience handler (OPS-003).
internal static class Code
{
    internal static HttpClient Create() => new();
}
