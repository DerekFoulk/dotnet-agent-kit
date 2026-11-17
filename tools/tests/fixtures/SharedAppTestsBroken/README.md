# Broken layers

Copied over `SharedAppTests` by `Export-KitApp.Tests.ps1`, it breaks the kit's shared architecture tests four ways:

- the domain uses its infrastructure (`LayerTests`);
- the domain uses ADO.NET (`SharedLibraryTests`);
- the tests reference an application project that `AppLayers` doesn't declare (`DeclarationTests`);
- the API has no endpoint type for `EndpointTests` to check.
