---
topic: csharp
rules:
  - id: CS-001
    statement: "Don't use _ = Task.Run(...) or _ = SomeAsyncMethod() to discard a task in application code; await the task."
    why: "A discard assignment doesn't observe the task's exception or make it a supported fire-and-forget operation, so a failure goes unseen."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/fundamentals/patterns/discards, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/patterns/discards"
        retrieved: "2026-11-17"
        text: "Don't use _ = Task.Run(...) or _ = SomeAsyncMethod() to discard a task in application code."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/patterns/discards"
        retrieved: "2026-11-17"
        text: "Await the task so its completion and exceptions remain in the calling flow."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks that no task is discarded with _ ="
    paths: ["**/*.cs"]
  - id: CS-002
    statement: "Prefer the shorter _ discard pattern for a switch catch-all, and avoid declaring your own variables, constants or types named _."
    why: "A variable or type named _ can change how a discard is read."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/fundamentals/patterns/discards, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/patterns/discards"
        retrieved: "2026-11-17"
        text: "Prefer the shorter _ discard pattern for a switch catch-all."
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/patterns/discards"
        retrieved: "2026-11-17"
        text: "Avoid declaring your own variables, constants, or types named _; use _ to communicate discard intent."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks switch catch-alls and any identifier named _"
    paths: ["**/*.cs"]
  - id: CS-003
    statement: "Prefer raw string literals over verbatim (@) strings in new code."
    why: "Raw string literals are easier to read and write."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/fundamentals/types/built-in-types, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/types/built-in-types"
        retrieved: "2026-11-17"
        text: "Raw string literals are easier to read and write, so prefer them for new code."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks new multi-line or escaped strings"
    paths: ["**/*.cs"]
  - id: CS-004
    statement: "Avoid dynamic in most application code."
    why: "Errors the compiler normally catches become run-time exceptions."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/fundamentals/types/built-in-types, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/fundamentals/types/built-in-types"
        retrieved: "2026-11-17"
        text: "Avoid dynamic in most application code because you lose compile-time safety."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every use of dynamic"
    paths: ["**/*.cs"]
  - id: CS-005
    statement: "Including an explanation of what to use instead in an Obsolete attribute is recommended."
    why: "The message is shown as part of the warning or error."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/language-reference/attributes/general, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/language-reference/attributes/general"
        retrieved: "2026-11-17"
        text: "The Obsolete attribute can be used without arguments, but including an explanation what to use instead is recommended."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every Obsolete attribute"
    paths: ["**/*.cs"]
  - id: CS-006
    statement: "Outside the initialization code source generators need, in most cases you should write a static constructor instead of a module initializer; and library authors should use OverloadResolutionPriority as a last resort when adding a new and better method overload."
    why: "Module initializers give source generators a standard place for their initialization code; overload priority needs a deep understanding of overload resolution, or unexpected errors result."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/language-reference/attributes/general, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/language-reference/attributes/general"
        retrieved: "2026-11-17"
        text: "Source code generators sometimes need to generate initialization code. Module initializers provide a standard place for that code. In most other cases, you should write a static constructor instead of a module initializer."
      - source: "https://learn.microsoft.com/dotnet/csharp/language-reference/attributes/general"
        retrieved: "2026-11-17"
        text: "Library authors should use this attribute as a last resort when adding a new and better method overload."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every ModuleInitializer and OverloadResolutionPriority attribute"
    paths: ["**/*.cs"]
  - id: CS-007
    statement: "Almost always define a member with value 0 in an enum."
    why: "The default value of an enum is 0."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/enum, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/enum"
        retrieved: "2026-11-17"
        text: "Almost always define a member with value 0 in your enums."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks new enums; CA1008 checks the same for the Framework Design Guidelines (STY-009)"
    paths: ["**/*.cs"]
  - id: CS-008
    statement: "Computed properties in record types should be computed on access, not initialized when the instance is created."
    why: "A with expression copies the instance, so a value computed at creation would describe the original, not the copy."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/record, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/record"
        retrieved: "2026-11-17"
        text: "Computed properties in record types should be computed on access, not initialized when the instance is created."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks computed properties on records"
    paths: ["**/*.cs"]
  - id: CS-009
    statement: "Defining immutable structure types is recommended, and if you're focused on the behavior of a type, consider defining a class."
    why: "Structure types have value semantics."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/struct, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/struct"
        retrieved: "2026-11-17"
        text: "Because structure types have value semantics, we recommend you define immutable structure types."
      - source: "https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/struct"
        retrieved: "2026-11-17"
        text: "If you're focused on the behavior of a type, consider defining a class."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks new structs; CA1815 and CA1819 check related Framework Design Guidelines (STY-009)"
    paths: ["**/*.cs"]
  - id: CS-010
    statement: "For a by-reference struct parameter, prefer ref readonly over in when the method captures the parameter or returns it by readonly reference."
    why: "Passing a large struct by reference avoids copying it."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/advanced-topics/performance/, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/advanced-topics/performance/"
        retrieved: "2026-11-17"
        text: "Prefer ref readonly when the method captures the parameter or returns it by readonly reference."
      - source: "https://learn.microsoft.com/dotnet/csharp/advanced-topics/performance/"
        retrieved: "2026-11-17"
        text: "The method might capture the parameter, or it might return the parameter by readonly reference. In those cases, you should use the ref readonly modifier. Otherwise, the in modifier offers more flexibility."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks by-reference parameters on large structs"
    paths: ["**/*.cs"]
  - id: CS-011
    statement: "Avoid using stackalloc inside loops, and never give it a negative length: where the length comes from user input, forbid negative values and cap the maximum."
    why: "Repeated stack allocation can overflow the stack."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/language-reference/operators/stackalloc, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/language-reference/operators/stackalloc"
        retrieved: "2026-11-17"
        text: "Avoid using stackalloc inside loops. Allocate the memory block outside a loop and reuse it inside the loop."
      - source: "https://learn.microsoft.com/dotnet/csharp/language-reference/operators/stackalloc"
        retrieved: "2026-11-17"
        text: "Do not provide negative lengths to the stackalloc operator. If the length is derived from user input, ensure that the call site both forbids negative values and caps the maximum allowed value, as shown in the above examples."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every stackalloc"
    paths: ["**/*.cs"]
  - id: CS-012
    statement: "Starting with .NET 9 and C# 13, lock a dedicated System.Threading.Lock instance for best performance (on an older .NET and C#, a dedicated object instance that isn't used for another purpose); avoid using the same lock object instance for different shared resources; and avoid this, Type instances and string instances (including string literals) as lock objects."
    why: "A shared or publicly reachable lock object can cause deadlock or lock contention."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/language-reference/statements/lock, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/language-reference/statements/lock"
        retrieved: "2026-11-17"
        text: "Starting with .NET 9 and C# 13, lock a dedicated object instance of the System.Threading.Lock type for best performance."
      - source: "https://learn.microsoft.com/dotnet/csharp/language-reference/statements/lock"
        retrieved: "2026-11-17"
        text: "If you're using an older version of .NET and C#, lock on a dedicated object instance that isn't used for another purpose."
      - source: "https://learn.microsoft.com/dotnet/csharp/language-reference/statements/lock"
        retrieved: "2026-11-17"
        text: "Avoid using the same lock object instance for different shared resources, as it might result in deadlock or lock contention. In particular, avoid using the following instances as lock objects:"
      - source: "https://learn.microsoft.com/dotnet/csharp/language-reference/statements/lock"
        retrieved: "2026-11-17"
        text: "this, as callers might also lock this."
      - source: "https://learn.microsoft.com/dotnet/csharp/language-reference/statements/lock"
        retrieved: "2026-11-17"
        text: "Type instances, as they might be obtained by the typeof operator or reflection."
      - source: "https://learn.microsoft.com/dotnet/csharp/language-reference/statements/lock"
        retrieved: "2026-11-17"
        text: "string instances, including string literals, as they might be interned."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every lock statement"
    paths: ["**/*.cs"]
  - id: CS-013
    statement: "Don't block the current thread in static constructors and initializers: don't wait on tasks, threads, wait handles or events, don't acquire locks, and don't run blocking parallel operations there."
    why: "Blocking there risks deadlock."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/static-constructors, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/static-constructors"
        retrieved: "2026-11-17"
        text: "To avoid the risk of deadlocks, don't block the current thread in static constructors and initializers. For example, don't wait on tasks, threads, wait handles or events, don't acquire locks, and don't execute blocking parallel operations such as parallel loops, Parallel.Invoke and Parallel LINQ queries."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks static constructors and static field initializers"
    paths: ["**/*.cs"]
  - id: CS-014
    statement: "Subscribing to an event with an anonymous function is not recommended if you have to unsubscribe from it later, and you should unsubscribe from events before you dispose of a subscriber object."
    why: "Until you unsubscribe, the publisher holds a reference to the subscriber's handler, so the subscriber can't be collected."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/programming-guide/events/how-to-subscribe-to-and-unsubscribe-from-events, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/programming-guide/events/how-to-subscribe-to-and-unsubscribe-from-events"
        retrieved: "2026-11-17"
        text: "We recommend that you don't use anonymous functions to subscribe to events if you have to unsubscribe from the event at some later point in your code."
      - source: "https://learn.microsoft.com/dotnet/csharp/programming-guide/events/how-to-subscribe-to-and-unsubscribe-from-events"
        retrieved: "2026-11-17"
        text: "In order to prevent resource leaks, you should unsubscribe from events before you dispose of a subscriber object."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks event subscriptions against the subscriber's lifetime"
    paths: ["**/*.cs"]
  - id: CS-015
    statement: "Don't call a method in a LINQ query expression that can create a side effect, such as modifying the data source or throwing an exception; and don't mix declarative and imperative code when you query and modify a LINQ to XML tree."
    why: "A query runs when it is enumerated, so side effects happen at a time and number of times the code doesn't show."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/linq/get-started/write-linq-queries, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/linq/mixed-declarative-imperative-code-bugs, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/linq/get-started/write-linq-queries"
        retrieved: "2026-11-17"
        text: "Don't call any method in a query expression that can create a side effect such as modifying the contents of the data source or throwing an exception."
      - source: "https://learn.microsoft.com/dotnet/standard/linq/mixed-declarative-imperative-code-bugs"
        retrieved: "2026-11-17"
        text: "To avoid such problems, don't mix declarative and imperative code, even if you know exactly the semantics of your collections and the semantics of the methods that modify the XML tree."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the methods a query expression calls"
    paths: ["**/*.cs"]
  - id: CS-016
    statement: "For a class library you implemented, you should not use extension methods to avoid incrementing the assembly's version number; to add significant functionality to a library whose source code you own, follow the .NET guidelines for assembly versioning."
    why: "Functionality added through extension methods leaves the assembly's version unchanged, which hides the change from the library's versioning."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/extension-methods, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/extension-methods"
        retrieved: "2026-11-17"
        text: "For a class library that you implemented, you shouldn't use extension methods to avoid incrementing the version number of an assembly. If you want to add significant functionality to a library for which you own the source code, follow the .NET guidelines for assembly versioning."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks new extension methods on types the repo owns"
    paths: ["**/*.cs"]
  - id: CS-017
    statement: "Avoid declaring a new method with the same name as a virtual method of a base class."
    why: "Overload resolution can pick the derived method when the caller meant the base method, or the reverse."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/versioning-with-the-override-and-new-keywords, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/versioning-with-the-override-and-new-keywords"
        retrieved: "2026-11-17"
        text: "First, avoid declaring new methods with the same name as virtual methods."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks new members that share a name with a base type's virtual member"
    paths: ["**/*.cs"]
  - id: CS-018
    statement: "Avoid overriding the same method in multiple derived interfaces."
    why: "Two overrides of a default interface method make a call ambiguous for a class that implements both interfaces."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/advanced-topics/interface-implementation/mixins-with-default-interface-methods, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/advanced-topics/interface-implementation/mixins-with-default-interface-methods"
        retrieved: "2026-11-17"
        text: "Avoid overriding the same method in multiple derived interfaces."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks default interface methods"
    paths: ["**/*.cs"]
  - id: CS-019
    statement: "You should annotate a method whose arguments could be null, and are known to be not null when the method returns true, the way the page annotates its TryGetMessage example: with NotNullWhen."
    why: "The attributes state a null contract the type alone can't express."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/csharp/language-reference/attributes/nullable-analysis, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/csharp/language-reference/attributes/nullable-analysis"
        retrieved: "2026-11-17"
        text: "In a nullable enabled context, you can communicate that idiom using the NotNullWhen attribute."
      - source: "https://learn.microsoft.com/dotnet/csharp/language-reference/attributes/nullable-analysis"
        retrieved: "2026-11-17"
        text: "In the preceding example, the value of message is known to be not null when TryGetMessage returns true. You should annotate similar methods in your codebase in the same way: the arguments could be null, and are known to be not null when the method returns true."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks Try-style methods and other null contracts the nullable type can't express (STY-005 covers the nullable switch itself)"
    paths: ["**/*.cs"]
  - id: CS-020
    statement: "The recommended way to deal with the platform compatibility analyzer's diagnostics is to make sure you only call platform-specific APIs when running on an appropriate platform; suppressing the warning should be a last resort."
    why: "A call on the wrong platform throws at run time; the analyzer's diagnostics point out where."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/analyzers/platform-compat-analyzer, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/analyzers/platform-compat-analyzer"
        retrieved: "2026-11-17"
        text: "The recommended way to deal with these diagnostics is to make sure you only call platform-specific APIs when running on an appropriate platform."
      - source: "https://learn.microsoft.com/dotnet/standard/analyzers/platform-compat-analyzer"
        retrieved: "2026-11-17"
        text: "However, this option should be a last resort when using platform-specific APIs."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks how each platform-compat diagnostic is dealt with, and that a suppression is a last resort"
    paths: ["**/*.cs"]
  - id: CS-021
    statement: "In a library, don't expose asynchronous methods purely for offloading, and don't expose a synchronous method that wraps an asynchronous implementation: leave the choice to offload, and the decision whether to block, to the consumer."
    why: "The consumer knows its threading environment and can make an informed choice."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/async-wrappers-for-synchronous-methods, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/synchronous-wrappers-for-asynchronous-methods, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/async-wrappers-for-synchronous-methods"
        retrieved: "2026-11-17"
        text: "Don't expose asynchronous methods purely for offloading. Leave that choice to the consumer."
      - source: "https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/synchronous-wrappers-for-asynchronous-methods"
        retrieved: "2026-11-17"
        text: "Don't expose a synchronous method that wraps an asynchronous implementation. Instead, leave the decision of whether to block to the consumer."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the public API of a library for async-over-sync and sync-over-async wrappers; STY-011 covers blocking on a task"
    paths: ["**/*.cs"]
  - id: CS-022
    statement: "When you complete a task by hand (a TaskCompletionSource), always complete it in success and failure paths; and when work must continue after the caller returns, transfer ownership of it explicitly."
    why: "A task that is never completed makes callers wait forever, and an unobserved background operation fails silently."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/complete-your-tasks, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/keep-async-methods-alive, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/complete-your-tasks"
        retrieved: "2026-11-17"
        text: "When you expose a task from TaskCompletionSource<TResult>, you own the task's lifetime."
      - source: "https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/complete-your-tasks"
        retrieved: "2026-11-17"
        text: "Always complete the task in success and failure paths."
      - source: "https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/keep-async-methods-alive"
        retrieved: "2026-11-17"
        text: "If work must continue after the caller returns, transfer ownership explicitly."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every TaskCompletionSource and every task that outlives its caller"
    paths: ["**/*.cs"]
  - id: CS-023
    statement: "Use the regular expression source generator if you can (the page's general guidance), and prefer it when you use Regex in C# with arguments known at compile time."
    why: "A source-generated regex is built at compile time instead of at run time."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/base-types/regular-expression-source-generators, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/base-types/regular-expression-source-generators"
        retrieved: "2026-11-17"
        text: "The general guidance is if you can use the source generator, use it."
      - source: "https://learn.microsoft.com/dotnet/standard/base-types/regular-expression-source-generators"
        retrieved: "2026-11-17"
        text: "If you're using Regex today in C# with arguments known at compile time, and especially if you're already using RegexOptions.Compiled (because the regex has been identified as a hot spot that would benefit from faster throughput), you should prefer to use the source generator."
    scope: core
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "build: SYSLIB1045 ([GeneratedRegex]) is on in the root .globalconfig (STY-003)"
    paths: ["**/*.cs"]
  - id: CS-024
    statement: "Validate an email address with a small regular expression that checks its structure, never with a regular expression alone, and send a test email to the address a user gives."
    why: "Only a test email shows the address exists."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/base-types/how-to-verify-that-strings-are-in-valid-email-format, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/base-types/how-to-verify-that-strings-are-in-valid-email-format"
        retrieved: "2026-11-17"
        text: "DO use a small regular expression to check for the valid structure of an email."
      - source: "https://learn.microsoft.com/dotnet/standard/base-types/how-to-verify-that-strings-are-in-valid-email-format"
        retrieved: "2026-11-17"
        text: "DO send a test email to the address provided by a user of your app."
      - source: "https://learn.microsoft.com/dotnet/standard/base-types/how-to-verify-that-strings-are-in-valid-email-format"
        retrieved: "2026-11-17"
        text: "DON'T use a regular expression as the only way you validate an email."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks how an app validates an email address"
    paths: ["**/*.cs"]
  - id: CS-025
    statement: "If you can choose the encoding, you should use a Unicode encoding, preferably UTF8Encoding or UnicodeEncoding, and you should use UTF-8 instead of UTF-7 if possible; most new applications should avoid best-fit behavior; whenever possible, you should specify an encoding object's fallback strategy when you instantiate it; and the encoding classes should not be used to store binary data in string form: to convert binary data to a string form, use Convert.ToBase64String."
    why: "Best-fit mapping has security risks, and a text encoding can corrupt binary data."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/base-types/character-encoding, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/base-types/character-encoding"
        retrieved: "2026-11-17"
        text: "If you have the opportunity to choose the encoding to be used by your application, you should use a Unicode encoding, preferably either UTF8Encoding or UnicodeEncoding."
      - source: "https://learn.microsoft.com/dotnet/standard/base-types/character-encoding"
        retrieved: "2026-11-17"
        text: "Consequently, you should use UTF-8 instead of UTF-7 if possible."
      - source: "https://learn.microsoft.com/dotnet/standard/base-types/character-encoding"
        retrieved: "2026-11-17"
        text: "However, most new applications should avoid best-fit behavior for security reasons."
      - source: "https://learn.microsoft.com/dotnet/standard/base-types/character-encoding"
        retrieved: "2026-11-17"
        text: "Whenever possible, you should specify the fallback strategy used by an encoding object when you instantiate the object."
      - source: "https://learn.microsoft.com/dotnet/standard/base-types/character-encoding"
        retrieved: "2026-11-17"
        text: "They should not be used to store binary data in string form. Depending on the encoding used, converting binary data to string format with the encoding classes can introduce unexpected behavior and produce inaccurate or corrupted data."
      - source: "https://learn.microsoft.com/dotnet/standard/base-types/character-encoding"
        retrieved: "2026-11-17"
        text: "To convert binary data to a string form, use the Convert.ToBase64String method."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every Encoding that isn't UTF-8 and any binary data held in a string"
    paths: ["**/*.cs"]
  - id: CS-026
    statement: "When you implement the observer pattern, don't write observers that depend on being notified before or after another observer, don't throw exceptions from OnNext or OnError, and the recommended pattern is to attach an observer to only one provider."
    why: "The provider is free to choose the notification order, and an exception from an observer goes unhandled."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/events/observer-design-pattern-best-practices, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/events/observer-design-pattern-best-practices"
        retrieved: "2026-11-17"
        text: "The provider is free to use any method to determine the order, so don't write observers that depend on being notified before or after another observer."
      - source: "https://learn.microsoft.com/dotnet/standard/events/observer-design-pattern-best-practices"
        retrieved: "2026-11-17"
        text: "Don't throw exceptions from interface implementations such as OnNext or OnError."
      - source: "https://learn.microsoft.com/dotnet/standard/events/observer-design-pattern-best-practices"
        retrieved: "2026-11-17"
        text: "Although you can attach an observer to multiple providers, the recommended pattern is to attach an IObserver<T> instance to only one IObservable<T> instance."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks IObservable<T> and IObserver<T> implementations"
    paths: ["**/*.cs"]
  - id: CS-027
    statement: "Using the cooperative cancellation model for all new library and application code is recommended; you should call CancellationTokenSource.Dispose when you have finished using the cancellation token source; and library code that provides cancelable operations should also provide public methods that accept an external cancellation token."
    why: "An undisposed source holds unmanaged resources, and a caller can only cancel an operation that takes its token."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/threading/cancellation-in-managed-threads, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/threading/cancellation-in-managed-threads"
        retrieved: "2026-11-17"
        text: "We recommend that you use this cooperative cancellation model for all new library and application code."
      - source: "https://learn.microsoft.com/dotnet/standard/threading/cancellation-in-managed-threads"
        retrieved: "2026-11-17"
        text: "You should be sure to call the CancellationTokenSource.Dispose method when you have finished using the cancellation token source to free any unmanaged resources it holds."
      - source: "https://learn.microsoft.com/dotnet/standard/threading/cancellation-in-managed-threads"
        retrieved: "2026-11-17"
        text: "If library code provides cancelable operations, it should also provide public methods that accept an external cancellation token so that user code can request cancellation."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every CancellationTokenSource's disposal and a library's cancelable public methods"
    paths: ["**/*.cs"]
  - id: CS-028
    statement: "Don't assume that parallel is always faster: always measuring actual results is recommended; avoiding, or at least limiting, access to shared state in a parallel loop is recommended; one iteration of a parallel loop should never wait on another iteration of the loop to make progress; catching an AggregateException without observing any of its inner exceptions is not recommended; and source.AsParallel().Where().ForAll(...) should be strongly preferred to Parallel.ForEach(source.AsParallel().Where(), ...)."
    why: "Parallelism sometimes runs slower, and shared state, waiting iterations and a blocked UI thread cause races and deadlocks."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/parallel-programming/potential-pitfalls-in-data-and-task-parallelism, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/parallel-programming/potential-pitfalls-with-plinq, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/parallel-programming/exception-handling-task-parallel-library, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/parallel-programming/potential-pitfalls-in-data-and-task-parallelism"
        retrieved: "2026-11-17"
        text: "Do Not Assume That Parallel Is Always Faster"
      - source: "https://learn.microsoft.com/dotnet/standard/parallel-programming/potential-pitfalls-in-data-and-task-parallelism"
        retrieved: "2026-11-17"
        text: "However, because many factors are involved in performance, we recommend that you always measure actual results."
      - source: "https://learn.microsoft.com/dotnet/standard/parallel-programming/potential-pitfalls-in-data-and-task-parallelism"
        retrieved: "2026-11-17"
        text: "Therefore, we recommend that you avoid, or at least limit, access to shared state in a parallel loop as much as possible."
      - source: "https://learn.microsoft.com/dotnet/standard/parallel-programming/potential-pitfalls-in-data-and-task-parallelism"
        retrieved: "2026-11-17"
        text: "In particular, one iteration of a parallel loop should never wait on another iteration of the loop to make progress."
      - source: "https://learn.microsoft.com/dotnet/standard/parallel-programming/potential-pitfalls-with-plinq"
        retrieved: "2026-11-17"
        text: "In other words, source.AsParallel().Where().ForAll(...) should be strongly preferred to Parallel.ForEach(source.AsParallel().Where(), ...)."
      - source: "https://learn.microsoft.com/dotnet/standard/parallel-programming/exception-handling-task-parallel-library"
        retrieved: "2026-11-17"
        text: "You could avoid an unhandled exception by just catching the AggregateException and not observing any of the inner exceptions. However, we recommend that you do not do this because it is analogous to catching the base Exception type in non-parallel scenarios."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every Parallel call and PLINQ query"
    paths: ["**/*.cs"]
  - id: CS-029
    statement: "Avoid using weak references as an automatic solution to memory management problems (develop an effective caching policy instead) and avoid weak references to small objects; allocating a pool of large objects that you reuse instead of allocating temporary ones is recommended; and an app should never make assumptions about or depend on a particular garbage collector segment size."
    why: "Large temporary objects fragment the large object heap, and segment sizes are implementation-specific and can change at any time."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/garbage-collection/weak-references, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/garbage-collection/large-object-heap, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/standard/garbage-collection/fundamentals, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/garbage-collection/weak-references"
        retrieved: "2026-11-17"
        text: "Avoid using weak references as an automatic solution to memory management problems. Instead, develop an effective caching policy for handling your application's objects."
      - source: "https://learn.microsoft.com/dotnet/standard/garbage-collection/weak-references"
        retrieved: "2026-11-17"
        text: "Avoid using weak references to small objects because the pointer itself may be as large or larger."
      - source: "https://learn.microsoft.com/dotnet/standard/garbage-collection/large-object-heap"
        retrieved: "2026-11-17"
        text: "Because of this, we recommend that you allocate a pool of large objects that you reuse instead of allocating temporary ones."
      - source: "https://learn.microsoft.com/dotnet/standard/garbage-collection/fundamentals"
        retrieved: "2026-11-17"
        text: "Your app should never make assumptions about or depend on a particular segment size, nor should it attempt to configure the amount of memory available for segment allocations."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every WeakReference and any large temporary allocation on a hot path"
    paths: ["**/*.cs"]
  - id: CS-030
    statement: "When extracting an untrusted ZIP or TAR archive, always enforce limits on decompressed size and entry count, applications should check that extracted entry names conform to an acceptable pattern, and don't use ExtractToDirectory (iterate the entries manually); when creating encrypted ZIP entries, always prefer Aes256."
    why: "Extraction helpers don't enforce size or entry limits and don't guarantee containment on disk, so path traversal and decompression bombs are the caller's to stop; ZipCrypto has known weaknesses."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/io/zip-tar-best-practices, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/io/zip-tar-best-practices"
        retrieved: "2026-11-17"
        text: "Always enforce limits on decompressed size and entry count when extracting untrusted archives."
      - source: "https://learn.microsoft.com/dotnet/standard/io/zip-tar-best-practices"
        retrieved: "2026-11-17"
        text: "Applications should check that the extracted entry names conform to an acceptable pattern."
      - source: "https://learn.microsoft.com/dotnet/standard/io/zip-tar-best-practices"
        retrieved: "2026-11-17"
        text: "Manual iteration: Don't use ExtractToDirectory for untrusted input—iterate entries manually to enforce all limits."
      - source: "https://learn.microsoft.com/dotnet/standard/io/zip-tar-best-practices"
        retrieved: "2026-11-17"
        text: "When creating encrypted entries, always prefer Aes256."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every ZIP or TAR extraction of data the app doesn't produce"
    paths: ["**/*.cs"]
  - id: CS-031
    statement: "If you must process untrusted XML from unknown sources, using an XmlReader configured to filter out known XML denial-of-service attacks is recommended; you should not accept DTDs or XSD schemas from untrusted sources; and error messages should not be exposed to callers that aren't trusted: you should catch all errors and report them with your own custom error messages."
    why: "DTDs and schemas are inherently vulnerable to denial-of-service attacks, and an error description can reveal data, file names or implementation details."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/linq/linq-xml-security, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/linq/linq-xml-security"
        retrieved: "2026-11-17"
        text: "If you must process untrusted data from unknown sources, Microsoft recommends that you use an instance of the XmlReader class that has been configured to filter out known XML denial of service (DoS) attacks."
      - source: "https://learn.microsoft.com/dotnet/standard/linq/linq-xml-security"
        retrieved: "2026-11-17"
        text: "You shouldn't accept DTDs from untrusted sources."
      - source: "https://learn.microsoft.com/dotnet/standard/linq/linq-xml-security"
        retrieved: "2026-11-17"
        text: "XSD schemas (including inline schemas) are inherently vulnerable to denial of service attacks; you shouldn't accept schemas from untrusted sources."
      - source: "https://learn.microsoft.com/dotnet/standard/linq/linq-xml-security"
        retrieved: "2026-11-17"
        text: "Error messages shouldn't be exposed to callers that aren't trusted. You should catch all errors and report errors with your own custom error messages."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every XML parse of data the app doesn't produce"
    paths: ["**/*.cs"]
  - id: CS-032
    statement: "Prefer RSA over DSA, and prefer SHA-2 (SHA256, SHA384, SHA512) over MD5 and SHA-1."
    why: "DSA is not as secure as RSA, and MD5 and SHA-1 have been found to be insecure."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/security/cryptographic-services, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/security/cryptographic-services"
        retrieved: "2026-11-17"
        text: "DSA is not as secure as RSA, and we recommend RSA."
      - source: "https://learn.microsoft.com/dotnet/standard/security/cryptographic-services"
        retrieved: "2026-11-17"
        text: "But the MD5 and SHA-1 algorithms have been found to be insecure, and SHA-2 is now recommended instead. SHA-2 includes SHA256, SHA384, and SHA512."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks cryptography against this rule and SEC-014; SEC-014's analyzers gate what a tool can see"
    paths: ["**/*.cs"]
  - id: CS-033
    statement: "Use System.Text.Json source generation in Native AOT apps."
    why: "Certain reflection APIs can't be used in Native AOT applications."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/serialization/system-text-json/reflection-vs-source-generation, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/serialization/system-text-json/reflection-vs-source-generation"
        retrieved: "2026-11-17"
        text: "In addition, certain reflection APIs can't be used in Native AOT applications, so you must use source generation for those apps."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the JSON serializer setup of an app that publishes Native AOT"
    paths: ["**/*.cs"]
  - id: CS-034
    statement: "A library's author chooses a dependency policy deliberately, removes out-of-support target frameworks from the package, doesn't reference a package when the framework provides the API, and avoids using branching to drop support for in-support frameworks."
    why: "A dependency policy affects framework libraries even when the library doesn't reference them directly, and branching removes the feature and support choice for users."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/library-guidance/dependencies-net, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/library-guidance/dependencies-net"
        retrieved: "2026-11-17"
        text: "DO be deliberate in choosing a dependency policy for your library."
      - source: "https://learn.microsoft.com/dotnet/standard/library-guidance/dependencies-net"
        retrieved: "2026-11-17"
        text: "DO remove out of support target frameworks from your package."
      - source: "https://learn.microsoft.com/dotnet/standard/library-guidance/dependencies-net"
        retrieved: "2026-11-17"
        text: "Don't reference packages when the framework provides the API."
      - source: "https://learn.microsoft.com/dotnet/standard/library-guidance/dependencies-net"
        retrieved: "2026-11-17"
        text: "AVOID using branching as a way to remove support for in-support frameworks as this approach removes the feature/support choice for users."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks a packable library's target frameworks and package references"
    paths: ["**/*.csproj", "**/Directory.Build.props"]
  - id: CS-035
    statement: "A package's assemblies for compatible frameworks must expose the same (or a superset of) API surface; never decrease the assembly version across releases, and change it with each release, unless the package overlaps with a .NET shared framework; avoid binary breaking changes to the public API and avoid removing package dependencies between compatible versions; and consider enabling Package Validation with a baseline version."
    why: "Consumers must be able to update packages and use them across frameworks and versions reliably."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/library-guidance/nuget-package-compatibility-rules, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/library-guidance/nuget-package-compatibility-rules"
        retrieved: "2026-11-17"
        text: "DO ensure that assemblies for compatible frameworks within the same package expose the same (or a superset of) API surface."
      - source: "https://learn.microsoft.com/dotnet/standard/library-guidance/nuget-package-compatibility-rules"
        retrieved: "2026-11-17"
        text: "DO NOT decrease the assembly version of a package across releases."
      - source: "https://learn.microsoft.com/dotnet/standard/library-guidance/nuget-package-compatibility-rules"
        retrieved: "2026-11-17"
        text: "DO change the assembly version with each release, unless the package overlaps with a .NET shared framework."
      - source: "https://learn.microsoft.com/dotnet/standard/library-guidance/nuget-package-compatibility-rules"
        retrieved: "2026-11-17"
        text: "AVOID binary breaking changes to your package's public API."
      - source: "https://learn.microsoft.com/dotnet/standard/library-guidance/nuget-package-compatibility-rules"
        retrieved: "2026-11-17"
        text: "AVOID removing package dependencies between compatible versions of the package or between compatible target frameworks within the same package."
      - source: "https://learn.microsoft.com/dotnet/standard/library-guidance/nuget-package-compatibility-rules"
        retrieved: "2026-11-17"
        text: "CONSIDER enabling Package Validation with a baseline version to automatically detect breaking changes."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks a packable library's release against these compatibility rules"
    paths: ["**/*.csproj", "**/*.cs"]
  - id: CS-036
    statement: "A library that targets .NET Standard should target .NET Standard 2.0 unless it needs to support an earlier version, shouldn't target .NET Standard 1.x, and, if it doesn't need to support .NET Framework, should skip .NET Standard 2.1 and go straight to the current .NET (the page names .NET 11)."
    why: "The page's reach-against-features trade-off: .NET Standard 2.0 is supported by all modern platforms, and 1.x limits features for little extra reach."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/net-standard, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/net-standard"
        retrieved: "2026-11-17"
        text: "If you're targeting .NET Standard, we recommend you target .NET Standard 2.0, unless you need to support an earlier version."
      - source: "https://learn.microsoft.com/dotnet/standard/net-standard"
        retrieved: "2026-11-17"
        text: "We don't recommend targeting .NET Standard 1.x, as you'd limit the available feature set for a minimal increase in reach."
      - source: "https://learn.microsoft.com/dotnet/standard/net-standard"
        retrieved: "2026-11-17"
        text: "If you don't need to support .NET Framework, you could target .NET Standard 2.1 or .NET 11. We recommend you skip .NET Standard 2.1 and go straight to .NET 11."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the target frameworks of a library meant for NuGet"
    paths: ["**/*.csproj", "**/Directory.Build.props"]
  - id: CS-038
    statement: "When you use System.IO.Pipelines, always complete the PipeReader and PipeWriter (including an exception where applicable), and always call AdvanceTo after ReadAsync."
    why: "An uncompleted reader or writer leaves its counterpart waiting."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/io/pipelines, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/io/pipelines"
        retrieved: "2026-11-17"
        text: "Always complete the PipeReader and PipeWriter, including an exception where applicable."
      - source: "https://learn.microsoft.com/dotnet/standard/io/pipelines"
        retrieved: "2026-11-17"
        text: "Always call PipeReader.AdvanceTo after calling PipeReader.ReadAsync."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every PipeReader and PipeWriter loop"
    paths: ["**/*.cs"]
  - id: CS-039
    statement: "When you marshal native structures, avoid using classes to express complex native types through inheritance, and use InlineArray to define fixed-size buffers in modern .NET (C# 12 and later)."
    why: "The page lists these among the guidance that helps avoid common marshalling issues."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/standard/native-interop/customize-struct-marshalling, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/standard/native-interop/customize-struct-marshalling"
        retrieved: "2026-11-17"
        text: "AVOID using classes to express complex native types through inheritance."
      - source: "https://learn.microsoft.com/dotnet/standard/native-interop/customize-struct-marshalling"
        retrieved: "2026-11-17"
        text: "DO use System.Runtime.CompilerServices.InlineArrayAttribute to define fixed-size buffers in modern .NET (C# 12 and later)."
    scope: core
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks every struct passed to native code"
    paths: ["**/*.cs"]
---

# C# and .NET library guidance

This file records recommendations from Microsoft Learn's C# guide (its fundamentals, language reference, programming
guide, LINQ and asynchronous pages) and its .NET library pages (`docs/standard`) that no other standards file holds.
The coding conventions, identifier names, async scenarios and exception pages are STY-007 and STY-012; the Framework
Design Guidelines are STY-009 and STY-010; secure coding, cryptography and serialization are SEC-014. Each rule states
only what its cited page says, at the page's strength, and quotes the sentence.

Every rule here is **proposed**: none is in force until the owner accepts it. Language-reference pages count only for
their explicit recommendations, not the feature description.
