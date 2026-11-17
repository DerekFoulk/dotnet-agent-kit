#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Proves the repo's root build configuration is enforced, not just present.
# Each fixture project is copied with the root config files into an isolated, tagged git
# workspace, so the real files are tested and nothing builds inside the repo itself.

BeforeAll {
    # Every repo these tests make runs with the same git settings (TestGit.psm1).
    Import-Module (Join-Path $PSScriptRoot 'TestGit.psm1') -Force
    $savedGit = Set-TestGitEnvironment
}
AfterAll { Restore-TestGitEnvironment -Saved $savedGit }

BeforeDiscovery {
    # The fixtures that must fail the build, and the diagnostic each must fail with. The 'violations fail the build'
    # tests run them. GlobalConfig marks a rule that .globalconfig turns on, and the '.globalconfig' test checks that the
    # marked rules are exactly the ones it turns on.
    $violations = @(
        @{ Fixture = 'UsesVar'; Diagnostic = 'IDE0008'; Description = 'var, because code style is enforced on build' }
        @{ Fixture = 'VarForBuiltInType'; Diagnostic = 'IDE0008'; Description = 'var for a built-in type, even after a cast that names it (STY-002)' }
        # STY-007 (rules audit, owner 2026-11-12): Microsoft's C# coding conventions and identifier names pages, as gates.
        @{ Fixture = 'ParameterInPascalCase'; Diagnostic = 'IDE1006'; Description = 'a parameter in PascalCase, where the naming rules ask for camelCase (STY-007)' }
        @{ Fixture = 'InternalStaticReadonlyPrefixed'; Diagnostic = 'IDE1006'; Description = 'an internal static readonly field with the s_ prefix, where the naming rules ask for PascalCase (STY-007)' }
        @{ Fixture = 'PrivateStaticReadonlyUnprefixed'; Diagnostic = 'IDE1006'; Description = 'a private static readonly field without the s_ prefix (STY-007)' }
        @{ Fixture = 'UsingBlock'; Diagnostic = 'IDE0063'; Description = 'a using block where a simple using declaration does (STY-007)' }
        @{ Fixture = 'ArrayInitializer'; Diagnostic = 'IDE0300'; Description = 'an array creation where a collection expression does (STY-007)' }
        @{ Fixture = 'ExplicitNew'; Diagnostic = 'IDE0090'; Description = 'new with the type repeated where a target-typed new() does (STY-007)' }
        @{ Fixture = 'ConstructorOnlyAssigns'; Diagnostic = 'IDE0290'; Description = 'a constructor that only assigns its parameters, where a primary constructor does (STY-007)' }
        @{ Fixture = 'MixedOperators'; Diagnostic = 'IDE0048'; Description = 'operators of different precedence with no parentheses to show the order (STY-007)' }
        # STY-008 (rules audit, owner 2026-11-12): XML documentation comments on every publicly visible member.
        @{ Fixture = 'UndocumentedPublicMember'; Diagnostic = 'CS1591'; Description = 'a public member with no XML documentation comment (STY-008)' }
        # STY-009 (Framework Design Guidelines pass, owner 2026-11-13): the Design, Naming and Usage rules, CA1815 and
        # CA1819 check internal APIs too, so they reach an app whose types CA1515 made internal; and IDE0250.
        @{ Fixture = 'InternalVisibleField'; Diagnostic = 'CA1051'; Description = 'a visible instance field on an internal type, a Design rule (STY-009)' }
        @{ Fixture = 'InternalIncorrectSuffix'; Diagnostic = 'CA1711'; Description = 'an internal type named with the Impl suffix, a Naming rule (STY-009)' }
        @{ Fixture = 'InternalOperatorWithoutAlternate'; Diagnostic = 'CA2225'; Description = 'an operator on an internal type with no named alternative, a Usage rule (STY-009)' }
        @{ Fixture = 'InternalStructWithoutEquals'; Diagnostic = 'CA1815'; Description = 'an internal struct that doesn''t override Equals (STY-009)' }
        @{ Fixture = 'InternalArrayProperty'; Diagnostic = 'CA1819'; Description = 'an internal property that returns an array (STY-009)' }
        @{ Fixture = 'PrivateArgumentException'; Diagnostic = 'CA2208'; Description = 'a private member that names a parameter it doesn''t have, a Usage rule that checks every member by default (STY-009)' }
        @{ Fixture = 'PrivateCancellationTokenFirst'; Diagnostic = 'CA1068'; Description = 'a private method that takes its CancellationToken first, a Design rule that checks every member by default (STY-009)' }
        @{ Fixture = 'ReadonlyStructNotDeclared'; Diagnostic = 'IDE0250'; Description = 'a struct whose members are all read-only but isn''t declared readonly (STY-009)' }
        # DAT-010: a caller's value interpolated into a Raw method of EF Core is SQL injection (EF1002).
        @{ Fixture = 'RawSqlInterpolation'; Diagnostic = 'EF1002'; Description = 'a value interpolated into SqlQueryRaw or ExecuteSqlRaw (DAT-010)' }
        # SEC-014 (Secure Coding Guidelines pass): the security analyzers latest-all turns on, and the SYSLIB obsoletions, fail
        # the build. The first eleven pin rules that are on already; the last six are BannedSymbols entries for what they miss.
        @{ Fixture = 'BrokenHash'; Diagnostic = 'CA5351'; Description = 'MD5, a broken hash (SEC-014)' }
        @{ Fixture = 'WeakHash'; Diagnostic = 'CA5350'; Description = 'SHA-1, a weak hash (SEC-014)' }
        @{ Fixture = 'UnsafeCipherMode'; Diagnostic = 'CA5358'; Description = 'CFB, an unsafe cipher mode (SEC-014)' }
        @{ Fixture = 'HardcodedKey'; Diagnostic = 'CA5390'; Description = 'an encryption key written in the code (SEC-014)' }
        @{ Fixture = 'InsecureRandom'; Diagnostic = 'CA5394'; Description = 'Random for a value that should be unguessable (SEC-014)' }
        @{ Fixture = 'DeprecatedTls'; Diagnostic = 'CA5397'; Description = 'TLS 1.1 (SEC-014)' }
        @{ Fixture = 'DisabledCertificateCheck'; Diagnostic = 'CA5359'; Description = 'a certificate check that accepts everything (SEC-014)' }
        @{ Fixture = 'DsaFactory'; Diagnostic = 'CA5384'; Description = 'DSA through its factory, which CA5384 reports, so it needs no ban (SEC-014)' }
        @{ Fixture = 'BinaryFormatterUse'; Diagnostic = 'SYSLIB0011'; Description = 'BinaryFormatter (SEC-014)' }
        @{ Fixture = 'ObsoleteCryptoType'; Diagnostic = 'SYSLIB0021'; Description = 'an obsolete cryptography type, AesManaged (SEC-014)' }
        @{ Fixture = 'UnsafeDataSetRead'; Diagnostic = 'CA2351'; Description = 'DataSet.ReadXml on untrusted input (SEC-014)' }
        @{ Fixture = 'AesCreate'; Diagnostic = 'RS0030'; Description = 'Aes.Create, whose CBC needs an HMAC nothing checks for (SEC-014)' }
        @{ Fixture = 'CryptoConfigByName'; Diagnostic = 'RS0030'; Description = 'an algorithm picked by name at run time (SEC-014)' }
        @{ Fixture = 'XmlResolverUse'; Diagnostic = 'RS0030'; Description = 'XmlUrlResolver, which fetches what the input names (SEC-014)' }
        @{ Fixture = 'LegacyXmlReader'; Diagnostic = 'RS0030'; Description = 'the legacy XmlTextReader (SEC-014)' }
        @{ Fixture = 'AcceptAnyCertificate'; Diagnostic = 'RS0030'; Description = 'the accept-any-certificate validator (SEC-014)' }
        @{ Fixture = 'DtdParse'; Diagnostic = 'RS0030'; Description = 'DTD parsing in XmlReaderSettings (SEC-014)' }
        # The .NET best-practices and C# passes (owner, 2026-11-16): BannedSymbols.txt bans what no analyzer flags. One
        # fixture holds a family's banned calls, and each row names the symbol its RS0030 must be about.
        @{ Fixture = 'ClockRead'; Diagnostic = 'RS0030'; Symbol = 'DateTime.Now'; Description = 'DateTime.Now, where TimeProvider gives the time (ARC-008)' }
        @{ Fixture = 'ClockRead'; Diagnostic = 'RS0030'; Symbol = 'DateTime.UtcNow'; Description = 'DateTime.UtcNow (ARC-008)' }
        @{ Fixture = 'ClockRead'; Diagnostic = 'RS0030'; Symbol = 'DateTime.Today'; Description = 'DateTime.Today (ARC-008)' }
        @{ Fixture = 'ClockRead'; Diagnostic = 'RS0030'; Symbol = 'DateTimeOffset.Now'; Description = 'DateTimeOffset.Now (ARC-008)' }
        @{ Fixture = 'ClockRead'; Diagnostic = 'RS0030'; Symbol = 'DateTimeOffset.UtcNow'; Description = 'DateTimeOffset.UtcNow (ARC-008)' }
        @{ Fixture = 'ObsoleteTimeZone'; Diagnostic = 'CS0618'; Description = 'TimeZone, obsolete in favor of TimeZoneInfo, so it needs no ban (ARC-008)' }
        # GAP-039: a project marked pure (<PureAssembly>true</PureAssembly>) gets BannedSymbols.Pure.txt as well, so it
        # keeps every project's bans and adds randomness, file, network, environment and process access (ARC-008).
        @{ Fixture = 'PureRandomness'; Diagnostic = 'RS0030'; Symbol = 'Random'''; Description = 'Random, shared or seeded, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureRandomness'; Diagnostic = 'RS0030'; Symbol = 'RandomNumberGenerator'; Description = 'RandomNumberGenerator, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureRandomness'; Diagnostic = 'RS0030'; Symbol = 'Guid.NewGuid()'; Description = 'Guid.NewGuid, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureRandomness'; Diagnostic = 'RS0030'; Symbol = 'Guid.CreateVersion7()'; Description = 'Guid.CreateVersion7, which reads the clock and random bits, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureRandomness'; Diagnostic = 'RS0030'; Symbol = 'Guid.CreateVersion7(DateTimeOffset)'; Description = 'Guid.CreateVersion7 from a given time, whose other bits are random, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureRandomness'; Diagnostic = 'RS0030'; Symbol = 'DateTime.Now'; Description = 'DateTime.Now in an assembly marked pure, which keeps every project''s bans (ARC-008)' }
        @{ Fixture = 'PureFileAccess'; Diagnostic = 'RS0030'; Symbol = 'File'''; Description = 'File, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureFileAccess'; Diagnostic = 'RS0030'; Symbol = 'Directory'''; Description = 'Directory, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureFileAccess'; Diagnostic = 'RS0030'; Symbol = 'FileInfo'; Description = 'FileInfo, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureFileAccess'; Diagnostic = 'RS0030'; Symbol = 'DirectoryInfo'; Description = 'DirectoryInfo, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureFileAccess'; Diagnostic = 'RS0030'; Symbol = 'FileStream'; Description = 'FileStream, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureFileAccess'; Diagnostic = 'RS0030'; Symbol = 'StreamReader.StreamReader(string)'; Description = 'a StreamReader that opens a path, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureFileAccess'; Diagnostic = 'RS0030'; Symbol = 'StreamWriter.StreamWriter(string)'; Description = 'a StreamWriter that opens a path, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureFileAccess'; Diagnostic = 'RS0030'; Symbol = 'Path.GetTempFileName()'; Description = 'Path.GetTempFileName, which makes a file, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureFileAccess'; Diagnostic = 'RS0030'; Symbol = 'Path.GetFullPath(string)'; Description = 'Path.GetFullPath, which reads the current directory, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureFileAccess'; Diagnostic = 'RS0030'; Symbol = 'ZipFileExtensions'; Description = 'ZipArchive''s extensions that read and write files, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureFileAccess'; Diagnostic = 'RS0030'; Symbol = 'TarFile'; Description = 'TarFile, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureFileAccess'; Diagnostic = 'RS0030'; Symbol = 'FileSystemEnumerable'; Description = 'FileSystemEnumerable, which lists a folder, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureFileAccess'; Diagnostic = 'RS0030'; Symbol = 'AppContext.BaseDirectory'; Description = 'the app''s own folder, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureFileAccess'; Diagnostic = 'RS0030'; Symbol = 'Assembly.Location'; Description = 'an assembly''s path on disk, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureNetworkAccess'; Diagnostic = 'RS0030'; Symbol = 'HttpClient'''; Description = 'an HttpClient, even one passed in, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureNetworkAccess'; Diagnostic = 'RS0030'; Symbol = 'Socket'''; Description = 'Socket, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureNetworkAccess'; Diagnostic = 'RS0030'; Symbol = 'TcpClient'; Description = 'TcpClient, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureNetworkAccess'; Diagnostic = 'RS0030'; Symbol = 'Dns'''; Description = 'Dns, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureEnvironmentAccess'; Diagnostic = 'RS0030'; Symbol = 'Environment.GetEnvironmentVariable(string)'; Description = 'an environment variable, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureEnvironmentAccess'; Diagnostic = 'RS0030'; Symbol = 'Environment.CurrentDirectory'; Description = 'the current directory, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureEnvironmentAccess'; Diagnostic = 'RS0030'; Symbol = 'Environment.TickCount64'; Description = 'Environment.TickCount64, a clock, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureEnvironmentAccess'; Diagnostic = 'RS0030'; Symbol = 'Stopwatch'''; Description = 'Stopwatch, a clock, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureEnvironmentAccess'; Diagnostic = 'RS0030'; Symbol = 'Console'''; Description = 'the console, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureEnvironmentAccess'; Diagnostic = 'RS0030'; Symbol = 'Process'''; Description = 'another process, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureEnvironmentAccess'; Diagnostic = 'RS0030'; Symbol = 'AnonymousPipeServerStream'; Description = 'an anonymous pipe to another process, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureEnvironmentAccess'; Diagnostic = 'RS0030'; Symbol = 'TimeZoneInfo.Local'; Description = 'the machine''s time zone, where TimeProvider.LocalTimeZone does, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureEnvironmentAccess'; Diagnostic = 'RS0030'; Symbol = 'DateTime.ToLocalTime()'; Description = 'DateTime.ToLocalTime, which reads the machine''s time zone, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureEnvironmentAccess'; Diagnostic = 'RS0030'; Symbol = 'DateTime.ToUniversalTime()'; Description = 'DateTime.ToUniversalTime, which reads the machine''s time zone, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureEnvironmentAccess'; Diagnostic = 'RS0030'; Symbol = 'DateTimeOffset.ToLocalTime()'; Description = 'DateTimeOffset.ToLocalTime, which reads the machine''s time zone, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'PureEnvironmentAccess'; Diagnostic = 'RS0030'; Symbol = 'TimeZoneInfo.ConvertTimeToUtc(DateTime)'; Description = 'TimeZoneInfo.ConvertTimeToUtc with no zone, which reads the machine''s, in an assembly marked pure (ARC-008)' }
        @{ Fixture = 'HttpClientConstructed'; Diagnostic = 'RS0030'; Symbol = 'HttpClient.HttpClient('; Description = 'an HttpClient built by hand, not by IHttpClientFactory (OPS-003)' }
        @{ Fixture = 'BlockingWait'; Diagnostic = 'RS0030'; Symbol = 'Task.Wait('; Description = 'Task.Wait (STY-011)' }
        @{ Fixture = 'BlockingWait'; Diagnostic = 'RS0030'; Symbol = 'Task<TResult>.Result'; Description = 'Task<T>.Result (STY-011)' }
        @{ Fixture = 'BlockingWait'; Diagnostic = 'RS0030'; Symbol = 'Task.WaitAll('; Description = 'Task.WaitAll (STY-011)' }
        @{ Fixture = 'BlockingWait'; Diagnostic = 'RS0030'; Symbol = 'Task.WaitAny('; Description = 'Task.WaitAny (STY-011)' }
        @{ Fixture = 'BlockingWait'; Diagnostic = 'RS0030'; Symbol = 'Thread.Sleep('; Description = 'Thread.Sleep (STY-011)' }
        @{ Fixture = 'NonGenericCollection'; Diagnostic = 'RS0030'; Symbol = 'ArrayList'; Description = 'ArrayList (STY-009)' }
        @{ Fixture = 'NonGenericCollection'; Diagnostic = 'RS0030'; Symbol = 'Hashtable'; Description = 'Hashtable (STY-009)' }
        @{ Fixture = 'NonGenericCollection'; Diagnostic = 'RS0030'; Symbol = 'Queue'''; Description = 'the non-generic Queue (STY-009)' }
        @{ Fixture = 'NonGenericCollection'; Diagnostic = 'RS0030'; Symbol = 'Stack'''; Description = 'the non-generic Stack (STY-009)' }
        # STY-003 (.NET best-practices pass, owner 2026-11-16): one fixture per family of rules latest-all turns on, plus
        # CS4014, a compiler warning, so each is proved, not assumed. Two limits the fixtures found: CA1305 doesn't see an
        # interpolated or concatenated number, and CA1510 to CA1513 fire only on a check that passes no message of its own
        # (CA1511 only with an empty one); both stay code review's.
        @{ Fixture = 'StringCulture'; Diagnostic = 'CA1305'; Description = 'a number formatted in the current culture (STY-003)' }
        @{ Fixture = 'StringCulture'; Diagnostic = 'CA1307'; Description = 'a string call that doesn''t say its comparison (STY-003)' }
        @{ Fixture = 'StringCulture'; Diagnostic = 'CA1309'; Description = 'an invariant-culture comparison where ordinal is meant (STY-003)' }
        @{ Fixture = 'StringCulture'; Diagnostic = 'CA1310'; Description = 'a culture-sensitive comparison by default (STY-003)' }
        @{ Fixture = 'StringCulture'; Diagnostic = 'CA1311'; Description = 'a case change with no culture (STY-003)' }
        @{ Fixture = 'DisposePattern'; Diagnostic = 'CA2000'; Description = 'a disposable that''s never disposed (STY-003)' }
        @{ Fixture = 'DisposePattern'; Diagnostic = 'CA1063'; Description = 'a Dispose that doesn''t follow the dispose pattern (STY-003)' }
        @{ Fixture = 'DisposePattern'; Diagnostic = 'CA1816'; Description = 'a Dispose that doesn''t call GC.SuppressFinalize (STY-003)' }
        @{ Fixture = 'DisposePattern'; Diagnostic = 'CA1001'; Description = 'a type that owns a disposable field but isn''t disposable (STY-003)' }
        @{ Fixture = 'AsyncMisuse'; Diagnostic = 'CA2008'; Description = 'a continuation with no TaskScheduler (STY-003)' }
        @{ Fixture = 'AsyncMisuse'; Diagnostic = 'CA2016'; Description = 'a cancellation token not passed on (STY-003)' }
        @{ Fixture = 'AsyncMisuse'; Diagnostic = 'CA1849'; Description = 'a blocking call in an async method where an async one exists (STY-003)' }
        @{ Fixture = 'AsyncMisuse'; Diagnostic = 'CA2012'; Description = 'a ValueTask thrown away (STY-003)' }
        @{ Fixture = 'AsyncMisuse'; Diagnostic = 'CS4014'; Description = 'a task started and not awaited (STY-003)' }
        @{ Fixture = 'LoggingMisuse'; Diagnostic = 'CA1848'; Description = 'a logger extension method where a [LoggerMessage] method does (STY-003)' }
        @{ Fixture = 'LoggingMisuse'; Diagnostic = 'CA2254'; Description = 'a log template that varies between calls (STY-003)' }
        @{ Fixture = 'LoggingMisuse'; Diagnostic = 'CA1727'; Description = 'a log placeholder that isn''t PascalCase (STY-003)' }
        @{ Fixture = 'LoggingMisuse'; Diagnostic = 'CA1873'; Description = 'a log argument computed even when the level is off, a rule new in .NET 10 (STY-003)' }
        @{ Fixture = 'ThrowPattern'; Diagnostic = 'CA2200'; Description = 'a caught exception rethrown with throw e (STY-003)' }
        @{ Fixture = 'ThrowPattern'; Diagnostic = 'CA2201'; Description = 'a reserved, too general exception type (STY-003)' }
        @{ Fixture = 'ThrowPattern'; Diagnostic = 'CA1510'; Description = 'a hand-written null check where ThrowIfNull does (STY-003)' }
        @{ Fixture = 'ThrowPattern'; Diagnostic = 'CA1511'; Description = 'a hand-written empty check where ThrowIfNullOrEmpty does (STY-003)' }
        @{ Fixture = 'ThrowPattern'; Diagnostic = 'CA1512'; Description = 'a hand-written range check where ThrowIfNegative does (STY-003)' }
        @{ Fixture = 'ThrowPattern'; Diagnostic = 'CA1513'; Description = 'a hand-written disposed check where ObjectDisposedException.ThrowIf does (STY-003)' }
        @{ Fixture = 'RecordStructNotReadonly'; Diagnostic = 'IDE0250'; Description = 'a record struct whose members are all read-only but isn''t declared readonly (STY-009)' }
        @{ Fixture = 'InternalExceptionInLibrary'; Diagnostic = 'CA1064'; Description = 'an internal exception in a class library (STY-009)' }
        # The .NET best-practices and C# passes (owner, 2026-11-16): the modern APIs Microsoft's pages ask for, and async void,
        # which only the threading analyzers see (ADR-0076).
        @{ Fixture = 'RegexConstructed'; Diagnostic = 'SYSLIB1045'; Description = 'a regex built at run time, where [GeneratedRegex] does, a rule latest-all leaves at info (STY-003)'; GlobalConfig = $true }
        @{ Fixture = 'DllImportUsed'; Diagnostic = 'SYSLIB1054'; Description = 'a [DllImport], where [LibraryImport] does, a rule latest-all leaves at info (STY-003)'; GlobalConfig = $true }
        @{ Fixture = 'LockOnObject'; Diagnostic = 'IDE0330'; Description = 'a lock on an object, where System.Threading.Lock does (STY-007)' }
        @{ Fixture = 'AsyncVoid'; Diagnostic = 'VSTHRD100'; Description = 'an async void method (STY-011)' }
        @{ Fixture = 'AsyncVoid'; Diagnostic = 'VSTHRD101'; Description = 'an async lambda passed as a void delegate (STY-011)' }
        @{ Fixture = 'TaskInUsing'; Diagnostic = 'VSTHRD107'; Description = 'a using statement over a Task, which disposes the task instead of awaiting it (STY-011)' }
        @{ Fixture = 'TaskDropped'; Diagnostic = 'VSTHRD110'; Description = 'a Task dropped in a method that isn''t async, where CS4014 doesn''t look (STY-011)' }
        @{ Fixture = 'NullableViolation'; Diagnostic = 'CS8600'; Description = 'a null assigned to a non-nullable type' }
        @{ Fixture = 'CatchAll'; Diagnostic = 'CA1031'; Description = 'catching Exception, a rule only AnalysisLevel latest-all turns on' }
        @{ Fixture = 'MsBuildWarning'; Diagnostic = 'KIT0001'; Description = 'a warning from an MSBuild task, which TreatWarningsAsErrors alone misses' }
        @{ Fixture = 'AwaitInLibrary'; Diagnostic = 'CA2007'; Description = 'an await without ConfigureAwait in a class library' }
        @{ Fixture = 'TooComplex'; Diagnostic = 'CA1502'; Description = 'a method with a cyclomatic complexity of 16, over the limit of 15 (CRF-008)'; GlobalConfig = $true }
        @{ Fixture = 'TooCoupledMember'; Diagnostic = 'CA1506'; Description = 'a method coupled to 41 types, over the limit of 40 per member (CRF-008)'; GlobalConfig = $true }
        @{ Fixture = 'TooCoupledType'; Diagnostic = 'CA1506'; Description = 'a class coupled to 96 types, over the limit of 95 per type (CRF-008)'; GlobalConfig = $true }
        @{ Fixture = 'TooDeep'; Diagnostic = 'CA1501'; Description = 'a class 6 levels deep, over the limit of 5 (CRF-008)'; GlobalConfig = $true }
        @{ Fixture = 'Unmaintainable'; Diagnostic = 'CA1505'; Description = 'a method with a maintainability index of 7, under the limit of 10 (CRF-008)'; GlobalConfig = $true }
        @{ Fixture = 'LegacyDesign'; Diagnostic = 'CA1005'; Description = 'a type with three type parameters, a rule latest-all leaves off (STY-003)'; GlobalConfig = $true }
        @{ Fixture = 'LegacyDesign'; Diagnostic = 'CA1021'; Description = 'an out parameter outside the Try pattern, a rule latest-all leaves off (STY-003)'; GlobalConfig = $true }
        @{ Fixture = 'LegacyDesign'; Diagnostic = 'CA1045'; Description = 'a ref parameter, a rule latest-all leaves off (STY-003)'; GlobalConfig = $true }
        @{ Fixture = 'PlatformIntrinsics'; Diagnostic = 'CA1516'; Description = 'an x86-only intrinsic where a cross-platform one exists, a rule latest-all sets to none (STY-003)'; GlobalConfig = $true }
        @{ Fixture = 'NoComVisible'; Diagnostic = 'CA1017'; Description = 'an assembly that doesn''t say whether COM sees it, a rule latest-all leaves off (STY-003)'; GlobalConfig = $true }
        @{ Fixture = 'NoClsCompliant'; Diagnostic = 'CA1014'; Description = 'an assembly that doesn''t say whether it''s CLS-compliant, a rule latest-all leaves off (STY-003, ADR-0049)'; GlobalConfig = $true }
        @{ Fixture = 'PInvokeOutsideNativeMethods'; Diagnostic = 'CA1060'; Description = 'a P/Invoke outside a NativeMethods class, a rule latest-all leaves off (STY-003)'; GlobalConfig = $true }
        @{ Fixture = 'BadMetricsConfig'; Diagnostic = 'CA1509'; Description = 'a CodeMetricsConfig.txt entry the metric rules would ignore, so a typo can''t switch a limit off'; GlobalConfig = $true }
        @{ Fixture = 'NonPublicReflection'; Diagnostic = 'RS0030'; Description = 'reading a non-public member by reflection (CRF-010)' }
        @{ Fixture = 'UnsafeAccessorUse'; Diagnostic = 'RS0030'; Description = 'reaching a non-public member through UnsafeAccessor (CRF-010)' }
        @{ Fixture = 'PrivateAccessor'; Diagnostic = 'RS0030'; Description = 'getting a property''s private setter with GetSetMethod(true) (CRF-010)' }
        @{ Fixture = 'AccessorProperty'; Diagnostic = 'RS0030'; Description = 'getting a property''s private setter through its SetMethod property (CRF-010)' }
        @{ Fixture = 'ModuleTypes'; Diagnostic = 'RS0030'; Description = 'listing a module''s types, internal ones included (CRF-010)' }
        @{ Fixture = 'ByNameDelegate'; Diagnostic = 'RS0030'; Description = 'binding a delegate to a method by name, which finds private methods too (CRF-010)' }
        @{ Fixture = 'DeclaredMembersReflection'; Diagnostic = 'RS0030'; Description = 'listing non-public members through TypeInfo.DeclaredFields, with no BindingFlags (CRF-010)' }
        @{ Fixture = 'TypeInitializerUse'; Diagnostic = 'RS0030'; Description = 'reading a type''s static constructor, which is always private, through Type.TypeInitializer (CRF-010)' }
    )
}

Describe 'Repo build configuration' -Tag 'Build' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        $configFiles = 'global.json', 'Directory.Build.props', 'Directory.Packages.props', '.editorconfig', 'nuget.config', '.globalconfig', 'CodeMetricsConfig.txt', 'BannedSymbols.txt', 'BannedSymbols.Pure.txt'

        function New-FixtureWorkspace {
            param([Parameter(Mandatory)] [string] $Fixture)

            # A folder of its own under a random name, so a fixture can back several tests; the leaf keeps the
            # fixture's name.
            $workspace = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName()) $Fixture
            New-Item -ItemType Directory -Path $workspace | Out-Null
            foreach ($file in $configFiles) {
                $source = Join-Path $repoRoot $file
                if (Test-Path $source) {
                    Copy-Item -Path $source -Destination $workspace
                }
            }
            Copy-Item -Path (Join-Path $PSScriptRoot 'fixtures' $Fixture '*') -Destination $workspace -Recurse

            # Each git step must succeed, or the workspace has no commit or tag to version from; git's output goes into
            # the error, never into the path this returns (as New-TestGitRemote does, TestGit.psm1). The exit codes are
            # read here, so pwsh mustn't turn one into its own error first (as Test-RepoGitIgnore does).
            $PSNativeCommandUseErrorActionPreference = $false
            foreach ($step in @(
                    @('init', '--quiet', '--initial-branch', 'main'),
                    @('-c', 'core.autocrlf=false', 'add', '--all'),
                    @('commit', '--quiet', '--message', 'fixture'),
                    @('tag', 'v1.2.3'))) {
                $output = git -C $workspace @step 2>&1 | Out-String
                if ($LASTEXITCODE -ne 0) { throw "git $($step -join ' ') failed in ${workspace}: $($output.Trim())" }
            }
            $workspace
        }

        function Invoke-FixtureBuild {
            param([Parameter(Mandatory)] [string] $Workspace, [string] $Project = '')

            # A failed build is an answer the tests read, so its exit code mustn't become pwsh's error.
            $PSNativeCommandUseErrorActionPreference = $false
            $target = if ($Project) { Join-Path $Workspace $Project } else { $Workspace }
            $output = dotnet build $target --configuration Release --nologo 2>&1 | Out-String
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
        }
    }

    # SUP-012: nuget.config requires every package to carry a signature from a trusted signer, nuget.org's repository
    # signature. The clean fixture restores nuget.org's packages under that policy; this one restores an unsigned
    # package from a local folder, which the policy must refuse.
    Context 'package signatures' {
        BeforeAll {
            $workspace = New-FixtureWorkspace -Fixture 'UnsignedPackage'

            # A package with no signature: a .nupkg is a zip with a .nuspec and a file for the target framework.
            $local = Join-Path $workspace 'local-packages'
            New-Item -ItemType Directory -Path $local | Out-Null
            $staging = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
            New-Item -ItemType Directory -Path (Join-Path $staging 'lib' 'net10.0') | Out-Null
            Set-Content -Path (Join-Path $staging 'lib' 'net10.0' '_._') -Value ''
            Set-Content -Path (Join-Path $staging 'Kit.Unsigned.nuspec') -Value @'
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd">
  <metadata>
    <id>Kit.Unsigned</id>
    <version>1.0.0</version>
    <authors>kit-tests</authors>
    <description>An unsigned package for the signature policy test.</description>
  </metadata>
</package>
'@
            Compress-Archive -Path (Join-Path $staging '*') -DestinationPath (Join-Path $local 'kit.unsigned.1.0.0.zip')
            Rename-Item -Path (Join-Path $local 'kit.unsigned.1.0.0.zip') -NewName 'kit.unsigned.1.0.0.nupkg'

            # The kit's config, plus that folder as a source for this one package only.
            $config = Join-Path $workspace 'nuget.config'
            [xml] $xml = Get-Content -Raw -Path $config
            $source = $xml.CreateElement('add'); $source.SetAttribute('key', 'local'); $source.SetAttribute('value', 'local-packages')
            [void] $xml.configuration.packageSources.AppendChild($source)
            $mapping = $xml.CreateElement('packageSource'); $mapping.SetAttribute('key', 'local')
            $pattern = $xml.CreateElement('package'); $pattern.SetAttribute('pattern', 'Kit.Unsigned')
            [void] $mapping.AppendChild($pattern)
            [void] $xml.configuration.packageSourceMapping.AppendChild($mapping)
            $xml.Save($config)

            $props = Join-Path $workspace 'Directory.Packages.props'
            (Get-Content -Raw -Path $props) -replace '</Project>', "  <ItemGroup>`n    <PackageVersion Include=`"Kit.Unsigned`" Version=`"1.0.0`" />`n  </ItemGroup>`n</Project>" |
                Set-Content -Path $props -NoNewline

            # NuGet checks a signature when it extracts a package, so this build gets an empty global packages folder
            # of its own: a copy already extracted on the machine would skip the check, and this one stays out of it.
            $savedPackages = $env:NUGET_PACKAGES
            $env:NUGET_PACKAGES = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
            try { $build = Invoke-FixtureBuild -Workspace $workspace }
            finally { $env:NUGET_PACKAGES = $savedPackages }
        }

        # .NET doesn't verify signatures during a restore on macOS (SUP-012's exception), so there the unsigned package
        # restores and this would fail with the configuration right (Copilot's review of PR #69).
        It 'refuses a package that no trusted signer signed (NU3004)' -Skip:$IsMacOS {
            $build.ExitCode | Should -Not -Be 0 -Because 'the policy refuses unsigned packages'
            $build.Output | Should -Match 'NU3004' -Because $build.Output
        }

        # Copilot's review of PR #69: .NET doesn't verify signatures during a restore on macOS, and Microsoft advises
        # leaving it so (https://learn.microsoft.com/dotnet/core/tools/nuget-signed-package-verification). SUP-012 says
        # so plainly, and no workflow may turn verification off where it does run (Windows always, Linux by default).
        It 'SUP-012 states its macOS exception' {
            $text = Get-Content -Raw -Path (Join-Path $repoRoot 'docs' 'standards' 'supply-chain.md')
            $statement = [regex]::Match($text, '(?m)^  - id: SUP-012\r?\n    statement: "(?<s>[^"]+)"').Groups['s'].Value
            $statement | Should -Not -BeNullOrEmpty
            $statement | Should -Match 'macOS'
        }

        It 'no workflow turns NuGet signature verification off' {
            foreach ($workflow in Get-ChildItem -Path (Join-Path $repoRoot '.github' 'workflows') -Filter '*.yml') {
                Get-Content -Raw -Path $workflow.FullName | Should -Not -Match 'DOTNET_NUGET_SIGNATURE_VERIFICATION\s*:\s*["'']?false' -Because $workflow.Name
            }
        }

        # Copilot's review of PR #69: with every package already extracted on the machine, a wrong certificate list
        # passed every test. A cold cache extracts, and so checks, each of nuget.org's packages the fixture uses.
        It 'restores nuget.org''s packages under the policy with a cold cache' {
            $clean = New-FixtureWorkspace -Fixture 'Clean'
            $savedPackages = $env:NUGET_PACKAGES
            $env:NUGET_PACKAGES = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
            try { $cold = Invoke-FixtureBuild -Workspace $clean }
            finally { $env:NUGET_PACKAGES = $savedPackages }

            $cold.ExitCode | Should -Be 0 -Because $cold.Output
        }

        # Copilot's review of PR #69: NuGet merges trustedSigners from every config above the repo, the user's and the
        # machine's, so a signer trusted there would be trusted here too unless the repo's config clears them.
        It 'trusts only nuget.org''s repository, whatever a config above the repo adds' {
            $isolated = New-FixtureWorkspace -Fixture 'Clean'
            Set-Content -Path (Join-Path (Split-Path -Path $isolated -Parent) 'nuget.config') -Value @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <trustedSigners>
    <author name="kit-test-extra-signer">
      <certificate fingerprint="AA12DA22A49BCE7D5C1AE64CC1F3D892F150DA76140F210ABD2CBFFCA2C18A27" hashAlgorithm="SHA256" allowUntrustedRoot="false" />
    </author>
  </trustedSigners>
</configuration>
'@
            $PSNativeCommandUseErrorActionPreference = $false
            Push-Location $isolated
            try { $list = dotnet nuget trust list 2>&1 | Out-String }
            finally { Pop-Location }

            $list | Should -Match 'nuget\.org' -Because $list
            $list | Should -Not -Match 'kit-test-extra-signer' -Because $list
        }
    }

    # STY-002 (rules audit, owner 2026-11-12): var is allowed where the type is named on the right side (a new, a cast),
    # as in dotnet/runtime's .editorconfig; everywhere else the type is written (the UsesVar fixture).
    Context 'var where the type is named on the right' {
        It 'builds with no warnings or errors' {
            $workspace = New-FixtureWorkspace -Fixture 'VarWhenApparent'
            $build = Invoke-FixtureBuild -Workspace $workspace

            $build.ExitCode | Should -Be 0 -Because $build.Output
        }
    }

    Context 'clean code' {
        BeforeAll {
            $workspace = New-FixtureWorkspace -Fixture 'Clean'
            $build = Invoke-FixtureBuild -Workspace $workspace
        }

        It 'builds with no warnings or errors' {
            $build.ExitCode | Should -Be 0 -Because $build.Output
        }

        It 'takes its version from the v-prefixed git tag (MinVer)' {
            $assembly = Join-Path $workspace 'bin' 'Release' 'net10.0' 'Clean.dll'
            [System.Diagnostics.FileVersionInfo]::GetVersionInfo($assembly).ProductVersion | Should -Match '^1\.2\.3\+'
        }

        It 'writes a package lock file' {
            Join-Path $workspace 'packages.lock.json' | Should -Exist
        }
    }

    # Several rows build the same fixture (LegacyDesign covers three rules), so each build needs a workspace of its own,
    # or the next row finds the last one's folder and fails before it builds (CI on PR 36).
    Context 'fixture workspaces' {
        # GitHub Actions runs pwsh with $ErrorActionPreference = 'stop', so the test does too.
        It 'gives each build of the same fixture a workspace of its own' {
            $ErrorActionPreference = 'Stop'
            $first = New-FixtureWorkspace -Fixture 'Clean'

            { $script:second = New-FixtureWorkspace -Fixture 'Clean' } | Should -Not -Throw
            @($script:second) | Should -HaveCount 1 -Because 'the function returns only the workspace path'
            $script:second | Should -Not -Be $first -Because 'a reused folder would share one build between rows'
            $first | Should -Exist
        }

        # A workspace with no commit or no tag would still build, and only MinVer's version would show it. With
        # $PSNativeCommandUseErrorActionPreference on (a profile can turn it on), pwsh's own NativeCommandExitException
        # mustn't replace the error that names the git step (review 10 of PR 36).
        It 'stops when a git step fails, instead of returning an untagged workspace (native exit codes as errors: <NativeErrors>)' -ForEach @(
            @{ NativeErrors = $false }
            @{ NativeErrors = $true }
        ) {
            $ErrorActionPreference = 'Stop'
            $PSNativeCommandUseErrorActionPreference = $NativeErrors
            $savedDate = $env:GIT_COMMITTER_DATE
            try {
                $env:GIT_COMMITTER_DATE = 'not a date'

                { New-FixtureWorkspace -Fixture 'Clean' } | Should -Throw -ExpectedMessage '*git commit*'
            }
            finally {
                $env:GIT_COMMITTER_DATE = $savedDate
            }
        }

        # A build that fails is the answer the violation tests read, so it comes back as an exit code, not pwsh's error.
        It 'returns a failed build''s exit code and output, even where native exit codes are errors' {
            $ErrorActionPreference = 'Stop'
            $PSNativeCommandUseErrorActionPreference = $true
            $workspace = New-FixtureWorkspace -Fixture 'UsesVar'

            $build = try { Invoke-FixtureBuild -Workspace $workspace } catch { [pscustomobject]@{ ExitCode = 'threw'; Output = $_.Exception.Message } }

            $build.ExitCode | Should -BeOfType [int] -Because $build.Output
            $build.ExitCode | Should -Not -Be 0
            $build.Output | Should -Match 'error IDE0008'
        }
    }

    Context 'violations fail the build' {
        # A fixture that backs several rows (one per rule in its family) is built once, in a workspace of its own, and
        # each row reads that build.
        BeforeAll { $builds = @{} }

        It 'rejects <Description> (<Diagnostic>)' -ForEach $violations {
            if (-not $builds.ContainsKey($Fixture)) {
                $builds[$Fixture] = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture $Fixture)
            }
            $build = $builds[$Fixture]

            $build.ExitCode | Should -Not -Be 0 -Because $build.Output
            $build.Output | Should -Match "error $Diagnostic"
            if ($_['Symbol']) {
                $build.Output | Should -Match ([regex]::Escape("error ${Diagnostic}: The symbol '$($_['Symbol'])")) -Because "the ban on $($_['Symbol']) should fire"
            }
        }
    }

    # ARC-008, ADR-0078: the pure list bans what reaches outside the program and no more. Each row names a call in a Pure*
    # fixture that must build. RS0030 names a banned type alone ('Path'), not the member called on it, so each row checks
    # its type too, and a ban widened to a whole type (Path, Environment, StreamReader) shows here (review 2 of this PR).
    Context 'what an assembly marked pure keeps' {
        BeforeAll { $builds = @{} }

        It 'allows <Symbol>' -ForEach @(
            @{ Fixture = 'PureFileAccess'; Type = 'Path'; Symbol = 'Path.Combine' }
            @{ Fixture = 'PureFileAccess'; Type = 'StreamReader'; Symbol = 'StreamReader.StreamReader(Stream)' }
            @{ Fixture = 'PureFileAccess'; Type = 'StreamWriter'; Symbol = 'StreamWriter.StreamWriter(Stream)' }
            @{ Fixture = 'PureEnvironmentAccess'; Type = 'Environment'; Symbol = 'Environment.NewLine' }
            @{ Fixture = 'PureEnvironmentAccess'; Type = 'Environment'; Symbol = 'Environment.ProcessorCount' }
        ) {
            if (-not $builds.ContainsKey($Fixture)) {
                $builds[$Fixture] = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture $Fixture)
            }
            $build = $builds[$Fixture]

            $build.Output | Should -Match 'error RS0030' -Because 'the fixture''s banned calls show the pure list was applied'
            $build.Output | Should -Not -Match ([regex]::Escape("The symbol '$Symbol")) -Because "$Symbol only works in memory"
            $build.Output | Should -Not -Match ([regex]::Escape("The symbol '$Type'")) -Because "a ban on all of $Type would ban $Symbol too"
        }
    }

    # ARC-008, GAP-039: only a project that sets PureAssembly gets BannedSymbols.Pure.txt, so randomness, files, the
    # network, the environment and the console stay open everywhere else (the Pure* rows show they're shut in one that does).
    Context 'a project not marked pure' {
        It 'may use what an assembly marked pure may not' {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture 'UnmarkedProjectAccess')

            $build.Output | Should -Not -Match 'RS0030'
            $build.ExitCode | Should -Be 0 -Because $build.Output
        }
    }

    # STY-011: the C# async page lists GetAwaiter().GetResult() first among the ways to block where await can't reach,
    # because it keeps the original exception; the ban on Wait and Result leaves it open.
    Context 'blocking where await can''t reach' {
        It 'allows GetAwaiter().GetResult()' {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture 'BlockingEscape')

            $build.Output | Should -Not -Match 'RS0030'
            $build.ExitCode | Should -Be 0 -Because $build.Output
        }
    }

    # C# guidance pass (owner 2026-11-16): CA1064 asks for public exceptions, and CA1515 asks an Exe's types to be
    # internal. In an Exe, an internal exception builds: CA1064's page names no exception for an Exe, so this pins what the
    # analyzer does. In a class library, such as a module's Domain project, CA1064 fails an internal exception (the
    # InternalExceptionInLibrary row) and CA1515 doesn't apply, so a library's exception is public.
    Context 'an app''s own exception' {
        It 'builds as an internal type in an Exe project' {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture 'InternalCustomException')

            $build.Output | Should -Not -Match 'CA1064|CA1515|CA1032'
            $build.ExitCode | Should -Be 0 -Because $build.Output
        }

        It 'builds as a public type in a class library' {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture 'PublicExceptionInLibrary')

            $build.Output | Should -Not -Match 'CA1064|CA1515|CA1032'
            $build.ExitCode | Should -Be 0 -Because $build.Output
        }
    }

    # STY-007 and STY-009: CA1707, which checks internal APIs here, fails an underscore in a static readonly field, and
    # Microsoft's identifier names page gives a private or internal static field the s_ prefix. A static readonly field
    # that isn't private takes PascalCase, as a public one does in the Framework Design Guidelines; a private one keeps s_.
    Context 'a static readonly field''s name' {
        It 'is PascalCase wherever the field isn''t private' {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture 'VisibleStaticReadonly')

            $build.Output | Should -Not -Match 'IDE1006|CA1707'
            $build.ExitCode | Should -Be 0 -Because $build.Output
        }
    }

    # STY-011 (ADR-0076): of the threading analyzers, only VSTHRD100 and VSTHRD101 are on, so the names a framework fixes
    # or documents (an async Main, middleware's InvokeAsync and async Invoke, a Razor Pages OnGetAsync) and a test method named for its
    # behavior (TST-010) build, where VSTHRD200 would ask for or against an Async suffix.
    Context 'the threading analyzers'' other rules stay off' {
        It 'allows <Description>' -ForEach @(
            @{ Project = 'Console'; Description = 'an async Main' }
            @{ Project = 'Web'; Description = 'middleware''s InvokeAsync and async Invoke, and a Razor Pages handler''s OnGetAsync' }
            @{ Project = 'Widgets.Tests'; Description = 'a test method with no Async suffix' }
        ) {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture 'AsyncNamingAllowed') -Project $Project

            $build.Output | Should -Not -Match 'IDE1006|VSTHRD'
            $build.ExitCode | Should -Be 0 -Because $build.Output
        }
    }

    # ADR-0043: the metric limits sit exactly where the ADR puts them, not lower.
    Context 'code at the metric limits' {
        It 'builds <Description>' -ForEach @(
            @{ Fixture = 'AtComplexityLimit'; Description = 'a method with a cyclomatic complexity of 15' }
            @{ Fixture = 'AtMemberCouplingLimit'; Description = 'a method coupled to 40 types' }
            @{ Fixture = 'AtTypeCouplingLimit'; Description = 'a class coupled to 95 types' }
            @{ Fixture = 'AtInheritanceLimit'; Description = 'a class 5 levels deep' }
            @{ Fixture = 'AtMaintainabilityLimit'; Description = 'a method with a maintainability index of 10' }
        ) {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture $Fixture)

            $build.ExitCode | Should -Be 0 -Because $build.Output
        }
    }

    # STY-008, ADR-0069: a test project (a name ending in Tests) writes no documentation file, so its public classes need
    # no XML comments.
    Context 'XML documentation leaves out test projects' {
        It 'allows an undocumented public class in a test project' {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture 'UndocumentedTestProject') -Project 'Widgets.Tests'

            $build.Output | Should -Not -Match 'CS1591'
            $build.ExitCode | Should -Be 0 -Because $build.Output
        }

        # BenchmarkDotNet builds a project of its own for each run, which imports Directory.Build.props though it asks not
        # to (dotnet/BenchmarkDotNet#2722); its generated code has no comments.
        It 'allows undocumented public code in the project BenchmarkDotNet generates' {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture 'BenchmarkDotNetGenerated')

            $build.Output | Should -Not -Match 'CS1591'
            $build.ExitCode | Should -Be 0 -Because $build.Output
        }
    }

    # ADR-0029: CA2007 is for libraries; Microsoft advises suppressing it for application code.
    Context 'CA2007 applies to libraries only' {
        It 'allows an await without ConfigureAwait in <Description>' -ForEach @(
            @{ Fixture = 'AwaitInApp'; Project = ''; Description = 'an app' }
            @{ Fixture = 'AwaitInTests'; Project = 'Widgets.Tests'; Description = 'a test project (a library in a *Tests folder)' }
            @{ Fixture = 'AwaitInNestedTests'; Project = 'tests/Widgets.Tests'; Description = 'a test project nested under tests/' }
        ) {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture $Fixture) -Project $Project

            $build.Output | Should -Not -Match 'CA2007'
            $build.ExitCode | Should -Be 0 -Because $build.Output
        }
    }

    # ADR-0062: BenchmarkDotNet runs only public benchmark classes, so CA1515 (make an app's public types internal) is
    # off in a benchmarks project, whose name ends in .Benchmarks, and nowhere else.
    Context 'CA1515 is off in benchmarks projects only' {
        It 'allows a public class in a benchmarks project' {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture 'PublicTypeInBenchmarks') -Project 'tests/Widgets.Benchmarks'

            $build.Output | Should -Not -Match 'CA1515'
            $build.ExitCode | Should -Be 0 -Because $build.Output
        }

        It 'still rejects a public class in any other app' {
            $build = Invoke-FixtureBuild -Workspace (New-FixtureWorkspace -Fixture 'PublicTypeInApp') -Project 'src/Widgets.App'

            $build.Output | Should -Match 'CA1515'
            $build.ExitCode | Should -Not -Be 0
        }
    }
}

# The banned-API analyzer ignores an entry that names no symbol, so a typo in BannedSymbols.txt would lift a ban
# without a sound (review 1 of PR 36). Each documentation comment ID must resolve on the runtime these tests use.
Describe 'BannedSymbols.txt' {
    BeforeAll {
        $bannedPath = Join-Path $PSScriptRoot '..' '..' 'BannedSymbols.txt'

        function Find-KitType {
            param([Parameter(Mandatory)] [string] $FullName)

            # Load the assembly named by the namespace, or a prefix of it, so types outside CoreLib resolve too.
            $parts = $FullName.Split('.')
            for ($length = $parts.Count - 1; $length -ge 1; $length--) {
                try { [void][Reflection.Assembly]::Load(($parts[0..($length - 1)] -join '.')) } catch [IO.FileNotFoundException] { }
            }
            [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetType($FullName, $false) } | Where-Object { $_ } | Select-Object -First 1
        }

        function Test-DocumentationId {
            param([Parameter(Mandatory)] [string] $Id)

            if ($Id -notmatch '^(?<kind>[TFPM]):(?<name>[^(]+)(\((?<params>.*)\))?$') { return $false }
            if ($Matches['kind'] -in 'T', 'F', 'P' -and $Matches['params']) { return $false }
            $name = $Matches['name']
            if ($Matches['kind'] -eq 'T') { return $null -ne (Find-KitType $name) }

            # Roslyn finds only members declared on the named type, so an inherited member mustn't count, and it compares
            # with case. An instance constructor is #ctor (a static one is #cctor), a generic parameter type is its name
            # without the arity and its type arguments in braces (System.ReadOnlySpan{System.Threading.Tasks.Task}), and a
            # generic type's own parameter is `0, `1 and so on. A nested type in a parameter list is joined with . where
            # FullName has + (System.Environment.SpecialFolder). A generic method's parameters (``0), ref or out parameters
            # (@), multi-dimensional arrays ([0:,0:]) and a banned symbol that is or sits on a nested type aren't parsed;
            # such an entry fails here until this function learns them.
            $declared = [Reflection.BindingFlags]'Public, NonPublic, Static, Instance, DeclaredOnly'
            $owner = Find-KitType ($name.Substring(0, $name.LastIndexOf('.')))
            $member = $name.Substring($name.LastIndexOf('.') + 1)
            if ($null -eq $owner) { return $false }
            switch ($Matches['kind']) {
                'F' { return $null -ne $owner.GetField($member, $declared) }
                'P' { return $null -ne $owner.GetProperty($member, $declared) }
                'M' {
                    $wanted = [string] $Matches['params']
                    $candidates = if ($member -ceq '#ctor') { $owner.GetConstructors($declared) | Where-Object { -not $_.IsStatic } } else { $owner.GetMethods($declared) | Where-Object Name -CEQ $member }
                    return [bool]($candidates | Where-Object {
                        (@($_.GetParameters() | ForEach-Object { Get-DocumentationTypeName $_.ParameterType }) -join ',') -ceq $wanted
                    })
                }
            }
        }

        # A type as a documentation comment ID names it in a parameter list: generic types as Name{Argument,...}, and a
        # generic type's own parameter by its position. The forms it doesn't parse come back as text no ID contains, so an
        # entry with one never resolves.
        function Get-DocumentationTypeName {
            param([Parameter(Mandatory)] [Type] $Type)

            $unparsed = '<not parsed>'
            if ($Type.IsGenericParameter) { return $(if ($Type.DeclaringMethod) { $unparsed } else { '`' + $Type.GenericParameterPosition }) }
            if ($Type.IsArray) { return $(if ($Type.GetArrayRank() -gt 1) { $unparsed } else { (Get-DocumentationTypeName $Type.GetElementType()) + '[]' }) }
            if ($Type.IsByRef) { return $unparsed }
            if (-not $Type.IsGenericType) { return $Type.FullName.Replace('+', '.') }
            $arguments = @($Type.GenericTypeArguments | ForEach-Object { Get-DocumentationTypeName $_ }) -join ','
            ($Type.GetGenericTypeDefinition().FullName -replace '`\d+$', '') + "{$arguments}"
        }
    }

    # Review 4 of PR 36: documentation comment IDs are case-sensitive, so a mis-cased entry bans nothing.
    It 'rejects an ID that differs from the symbol only in case' {
        Test-DocumentationId -Id 'M:System.Reflection.Module.gettypes' | Should -BeFalse
        Test-DocumentationId -Id 'M:System.Reflection.Module.FindTypes(System.Reflection.typefilter,System.object)' | Should -BeFalse
    }

    # The .NET best-practices pass bans HttpClient's constructors and Task.WaitAll's overloads, so the IDs name a
    # constructor (#ctor) and generic parameter types ({...}), as documentation comment IDs do.
    It 'resolves <Id>' -ForEach @(
        @{ Id = 'M:System.Net.Http.HttpClient.#ctor' }
        @{ Id = 'M:System.Net.Http.HttpClient.#ctor(System.Net.Http.HttpMessageHandler,System.Boolean)' }
        @{ Id = 'M:System.Threading.Tasks.Task.WaitAll(System.ReadOnlySpan{System.Threading.Tasks.Task})' }
        @{ Id = 'M:System.Threading.Tasks.Task.WaitAll(System.Collections.Generic.IEnumerable{System.Threading.Tasks.Task},System.Threading.CancellationToken)' }
        @{ Id = 'P:System.Threading.Tasks.Task`1.Result' }
        @{ Id = 'M:System.Collections.Generic.List`1.Add(`0)' }
    ) {
        Test-DocumentationId -Id $Id | Should -BeTrue
    }

    It 'rejects <Id>, which names no symbol' -ForEach @(
        @{ Id = 'M:System.Net.Http.HttpClient.#ctor(System.String)' }
        @{ Id = 'M:System.Threading.Tasks.Task.WaitAll(System.ReadOnlySpan{System.String})' }
        @{ Id = 'M:System.Threading.Tasks.Task.WaitAll(System.ReadOnlySpan{System.Threading.Tasks.Task)' }
        # Review 1 of this PR: a static constructor is #cctor, so #ctor must name an instance constructor.
        @{ Id = 'M:System.Environment.#ctor' }
        @{ Id = 'M:System.AttributeUsageAttribute.#ctor' }
        # A generic type's own parameter is `0, and an ID that leaves it out names nothing.
        @{ Id = 'M:System.Collections.Generic.List`1.Add' }
    ) {
        Test-DocumentationId -Id $Id | Should -BeFalse
    }

    # Review 1 of PR 94: STY-011 and OPS-003 ban these in every overload, and the fixtures call one each, so a row that
    # goes missing, or an overload a later .NET adds, fails here instead of going unbanned.
    It 'bans every public overload of <Member>' -ForEach @(
        @{ Member = 'System.Threading.Tasks.Task.Wait' }
        @{ Member = 'System.Threading.Tasks.Task.WaitAll' }
        @{ Member = 'System.Threading.Tasks.Task.WaitAny' }
        @{ Member = 'System.Threading.Thread.Sleep' }
        @{ Member = 'System.Net.Http.HttpClient.#ctor' }
    ) {
        $ids = @(Get-Content -LiteralPath $bannedPath | Where-Object { $_ -and $_ -notmatch '^\s*//' } | ForEach-Object { $_.Split(';')[0].Trim() })
        $type = Find-KitType $Member.Substring(0, $Member.LastIndexOf('.'))
        $name = $Member.Substring($Member.LastIndexOf('.') + 1)
        $overloads = if ($name -ceq '#ctor') { $type.GetConstructors() } else { $type.GetMethods() | Where-Object { $_.Name -ceq $name -and $_.DeclaringType -eq $type } }

        @($overloads).Count | Should -BeGreaterThan 0
        foreach ($overload in $overloads) {
            $parameters = @($overload.GetParameters() | ForEach-Object { Get-DocumentationTypeName $_.ParameterType }) -join ','
            $id = "M:$Member" + $(if ($parameters) { "($parameters)" } else { '' })
            $ids | Should -Contain $id -Because "every overload of $Member is banned"
        }
    }

    It '<File> names only symbols that exist' -ForEach @(
        @{ File = 'BannedSymbols.txt' }
        @{ File = 'BannedSymbols.Pure.txt' }
    ) {
        $ids = @(Get-Content -LiteralPath (Join-Path $PSScriptRoot '..' '..' $File) | Where-Object { $_ -and $_ -notmatch '^\s*//' } | ForEach-Object { $_.Split(';')[0].Trim() })

        $ids.Count | Should -BeGreaterThan 0
        foreach ($id in $ids) {
            Test-DocumentationId -Id $id | Should -BeTrue -Because "'$id' should name a real symbol, or the ban does nothing"
        }
    }

    # GAP-039: the pure list bans types whose assembly isn't named after their namespace (Ping is in System.Net.Ping,
    # ZipFile in System.IO.Compression.ZipFile), and a method that takes a nested type (Environment.SpecialFolder).
    It 'resolves <Id>, whose type is in an assembly named otherwise or nested' -ForEach @(
        @{ Id = 'T:System.Net.NetworkInformation.Ping' }
        @{ Id = 'T:System.IO.Compression.ZipFile' }
        @{ Id = 'M:System.Environment.GetFolderPath(System.Environment.SpecialFolder)' }
    ) {
        Test-DocumentationId -Id $Id | Should -BeTrue
    }

    # A project marked pure gets both files, so an ID in both would be one ban stated twice (CRF-003).
    It 'BannedSymbols.Pure.txt repeats no ID of BannedSymbols.txt' {
        $read = { param($Name) @(Get-Content -LiteralPath (Join-Path $PSScriptRoot '..' '..' $Name) | Where-Object { $_ -and $_ -notmatch '^\s*//' } | ForEach-Object { $_.Split(';')[0].Trim() }) }
        $everywhere = & $read 'BannedSymbols.txt'
        $pure = & $read 'BannedSymbols.Pure.txt'

        $pure.Count | Should -BeGreaterThan 0
        @($pure | Where-Object { $_ -cin $everywhere }) | Should -BeNullOrEmpty
    }

    # ARC-008: a pure assembly may read a stream its caller passes in, so only the constructors that open a path are
    # banned; a row that goes missing, or a path overload a later .NET adds, fails here.
    It 'BannedSymbols.Pure.txt bans every public <Type> constructor that opens a path' -ForEach @(
        @{ Type = 'System.IO.StreamReader' }
        @{ Type = 'System.IO.StreamWriter' }
    ) {
        $ids = @(Get-Content -LiteralPath (Join-Path $PSScriptRoot '..' '..' 'BannedSymbols.Pure.txt') | Where-Object { $_ -and $_ -notmatch '^\s*//' } | ForEach-Object { $_.Split(';')[0].Trim() })
        $paths = @((Find-KitType $Type).GetConstructors() | Where-Object { $_.GetParameters()[0].ParameterType -eq [string] })

        $paths.Count | Should -BeGreaterThan 0
        foreach ($constructor in $paths) {
            $id = "M:$Type.#ctor(" + (@($constructor.GetParameters() | ForEach-Object { Get-DocumentationTypeName $_.ParameterType }) -join ',') + ')'
            $ids | Should -Contain $id -Because "every $Type constructor that opens a path is banned"
        }
    }
}

# ARC-008, GAP-039: the sample's domain is its core business logic, so it's marked pure; reading the evaluated items shows
# that Directory.Build.props, imported before the .csproj sets PureAssembly, still hands it BannedSymbols.Pure.txt.
Describe 'The sample''s pure assemblies' -Tag 'Build' {
    It '<Name> gets BannedSymbols.Pure.txt' -ForEach @(
        Get-ChildItem -Path (Join-Path $PSScriptRoot '..' '..' 'sample' 'src') -Filter '*.Domain.csproj' -Recurse |
            ForEach-Object { @{ Name = $_.BaseName; Project = $_.FullName } }
    ) {
        $PSNativeCommandUseErrorActionPreference = $false
        $items = dotnet msbuild $Project -getItem:AdditionalFiles 2>&1 | Out-String

        $LASTEXITCODE | Should -Be 0 -Because $items
        @(($items | ConvertFrom-Json).Items.AdditionalFiles.Identity | Split-Path -Leaf) | Should -Contain 'BannedSymbols.Pure.txt'
    }
}

# CodeMetricsConfig.txt is the one source of the metric limits; CRF-008 states them for readers, so the two must agree
# (CRF-003, review 1 of PR 36).
Describe 'CodeMetricsConfig.txt' {
    It 'sets exactly the limits CRF-008 states' {
        $root = Join-Path $PSScriptRoot '..' '..'
        $statement = (Select-String -LiteralPath (Join-Path $root 'docs' 'standards' 'craft.md') -Pattern '^\s*statement: "Stay within the metric limits:.*').Line
        $config = @{}
        foreach ($line in Get-Content -LiteralPath (Join-Path $root 'CodeMetricsConfig.txt')) {
            if ($line -match '^\s*(?<key>CA\d{4}(\(\w+\))?)\s*:\s*(?<limit>\d+)\s*$') { $config[$Matches['key']] = $Matches['limit'] }
        }
        $stated = [ordered]@{
            'CA1502'         = 'cyclomatic complexity (\d+) per method'
            'CA1506(Method)' = 'class coupling (\d+) types per member'
            'CA1506(Type)'   = 'and (\d+) per type'
            'CA1501'         = 'inheritance (\d+) levels deep'
            'CA1505'         = 'maintainability index of at least (\d+)'
        }

        $statement | Should -Not -BeNullOrEmpty
        @($config.Keys | Sort-Object) | Should -Be @($stated.Keys | Sort-Object) -Because 'every limit in the file is one CRF-008 states'
        foreach ($key in $stated.Keys) {
            $statement | Should -Match $stated[$key]
            [regex]::Match($statement, $stated[$key]).Groups[1].Value | Should -Be $config[$key] -Because "CRF-008 and CodeMetricsConfig.txt should agree on $key"
        }
    }
}

# STY-003: every rule .globalconfig turns on has a fixture that must fail with it, so a rule added there without one, or
# one that silently doesn't fire, can't slip in (review 4 of PR 36).
Describe '.globalconfig' {
    BeforeAll {
        # The IDs of the rules these lines turn on: any severity but none. It reads them as Roslyn's analyzer config
        # parser does, at dotnet/roslyn e141f0d31c796c99f5a7c31e54e0b597c03381be:
        #   https://github.com/dotnet/roslyn/blob/e141f0d31c796c99f5a7c31e54e0b597c03381be/src/Compilers/Core/Portable/CommandLine/AnalyzerConfig.cs
        #   https://github.com/dotnet/roslyn/blob/e141f0d31c796c99f5a7c31e54e0b597c03381be/src/Compilers/Core/Portable/CommandLine/AnalyzerConfigSet.cs
        # A key is [\w.-]+ ('_' is in \w), then '=' or ':', then the value; a comment starts at the first '#' or ';';
        # case doesn't matter, and the last value a key gets wins; the ID is everything between dotnet_diagnostic. and
        # .severity; and the severities are TryParseSeverity's. It stops at any other line but is_global and
        # global_level, so nothing in the file turns rules on unseen: a section, a bulk severity, an option, a typo.
        function Get-EnabledRule([string[]] $Line) {
            $severities = 'default', 'error', 'warning', 'suggestion', 'silent', 'refactoring', 'none'
            $severityOf = [Collections.Specialized.OrderedDictionary]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($text in $Line) {
                $setting = ($text -replace '[#;].*$', '').Trim()
                if (-not $setting) { continue }
                $unrecognised = "Get-EnabledRule doesn't recognise this .globalconfig line: '$text'"
                if ($setting -notmatch '^(?<key>[\w.-]+)\s*[=:]\s*(?<value>.*)$') { throw $unrecognised }
                $key, $value = $Matches['key'], $Matches['value']
                if ($key -in 'is_global', 'global_level') { continue }
                if ($key -notmatch '^dotnet_diagnostic\.(?<id>[\w.-]+)\.severity$' -or $value -notin $severities) { throw $unrecognised }
                $severityOf[$Matches['id']] = $value
            }
            $severityOf.Keys | Where-Object { $severityOf[$_] -ne 'none' }
        }
    }

    It 'reads <Line> as turning on <Expected>' -ForEach @(
        @{ Line = 'dotnet_diagnostic.CA1014.severity = warning'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = error'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = suggestion'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = silent'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = refactoring'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = default'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity: warning'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = warning # a trailing comment'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = warning ; a trailing comment'; Expected = 'CA1014' }
        @{ Line = '  dotnet_diagnostic.CA1014.severity = warning'; Expected = 'CA1014' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = none'; Expected = $null }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = None'; Expected = $null }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = none # off for now'; Expected = $null }
        @{ Line = '# dotnet_diagnostic.CA1014.severity = warning'; Expected = $null }
        # Roslyn's key takes '.' and '-' too, and everything between dotnet_diagnostic. and .severity is the ID.
        @{ Line = 'dotnet_diagnostic.My-Rule.v2.severity = warning'; Expected = 'My-Rule.v2' }
        @{ Line = 'is_global = true'; Expected = $null }
        @{ Line = 'global_level = 100'; Expected = $null }
    ) {
        { $script:enabled = Get-EnabledRule -Line $Line } | Should -Not -Throw
        $script:enabled | Should -Be $Expected
    }

    # Roslyn keeps the last value a key gets, and lowercases keys first, so a later line turns a rule back off.
    It 'lets the last line for a rule win: <Description>' -ForEach @(
        @{ Description = 'on, then off'; Lines = @('dotnet_diagnostic.CA1014.severity = warning', 'dotnet_diagnostic.CA1014.severity = none'); Expected = @() }
        @{ Description = 'on, then off in other case'; Lines = @('dotnet_diagnostic.CA1014.severity = warning', 'DOTNET_DIAGNOSTIC.ca1014.SEVERITY = none'); Expected = @() }
        @{ Description = 'off, then on'; Lines = @('dotnet_diagnostic.CA1014.severity = none', 'dotnet_diagnostic.CA1014.severity = error'); Expected = @('CA1014') }
        @{ Description = 'on twice'; Lines = @('dotnet_diagnostic.CA1014.severity = warning', 'dotnet_diagnostic.CA1014.severity = error'); Expected = @('CA1014') }
    ) {
        { $script:enabled = @(Get-EnabledRule -Line $Lines) } | Should -Not -Throw
        $script:enabled | Should -Be $Expected
    }

    # Review 10 of PR 36: a line the function can't read would turn nothing on in its eyes, so the real-file test
    # would pass while Roslyn read the line as something else (a bulk severity, say), or ignored a typo.
    It 'stops at <Line>, which it doesn''t recognise' -ForEach @(
        @{ Line = 'dotnet_diagnostic.CA1014.severity = warn' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = info' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity = warning error' }
        @{ Line = 'dotnet_diagnostic.CA1014.severity warning' }
        @{ Line = 'dotnet_diagnostic.CA1014 = warning' }
        @{ Line = 'dotnet_analyzer_diagnostic.severity = warning' }
        @{ Line = 'dotnet_analyzer_diagnostic.category-Design.severity = warning' }
        @{ Line = 'dotnet_code_quality.CA1501.api_surface = public' }
        @{ Line = '[*.cs]' }
    ) {
        { Get-EnabledRule -Line $Line } | Should -Throw -ExpectedMessage "*doesn't recognise*"
    }

    # Any severity but none counts as on, so suggestion, silent and default ask for a fixture too, erring toward one;
    # the table is the one the fixture builds run from, so a row that's commented out doesn't count. Both ways, so a
    # line the parser misread, or one taken out of .globalconfig, shows too (review 10 of PR 36).
    It 'turns on exactly the rules whose failing fixtures are marked GlobalConfig' -ForEach @(@{ Violations = $violations }) {
        $root = Join-Path $PSScriptRoot '..' '..'
        $turnedOn = @(Get-EnabledRule -Line (Get-Content -LiteralPath (Join-Path $root '.globalconfig')))
        $marked = @($Violations | Where-Object { $_['GlobalConfig'] } | ForEach-Object { $_.Diagnostic } | Sort-Object -Unique)

        $marked.Count | Should -BeGreaterThan 0
        @($turnedOn | Where-Object { $_ -notin $marked }) | Should -BeNullOrEmpty -Because 'each rule on in .globalconfig needs a failing fixture marked GlobalConfig, to prove it fires'
        @($marked | Where-Object { $_ -notin $turnedOn }) | Should -BeNullOrEmpty -Because 'each rule marked GlobalConfig should be on in .globalconfig'
    }
}