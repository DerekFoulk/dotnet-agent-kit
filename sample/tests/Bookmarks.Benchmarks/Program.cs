using BenchmarkDotNet.Running;

// Runs the benchmarks the command line picks: --filter '*' runs them all, and --exporters json writes the report
// tools/Test-BenchmarkBudget.ps1 checks against benchmark-budget.json (ADR-0062).
BenchmarkSwitcher.FromAssembly(typeof(Program).Assembly).Run(args);
