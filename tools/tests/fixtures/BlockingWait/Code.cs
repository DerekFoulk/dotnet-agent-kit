namespace BlockingWait;

// Blocking on a task deadlocks under a synchronization context and ties up a thread; await it (STY-011).
internal static class Code
{
    internal static void Wait(Task task) => task.Wait();

    internal static int Result(Task<int> task) => task.Result;

    internal static void WaitAll(Task[] tasks) => Task.WaitAll(tasks);

    internal static int WaitAny(Task[] tasks) => Task.WaitAny(tasks);

    internal static void Sleep() => Thread.Sleep(1);
}
