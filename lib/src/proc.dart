import 'dart:io';

abstract class Proc {
  Future<ProcessResult> run(String exe, List<String> args);
  ProcessResult runSync(String exe, List<String> args);
  Future<Process> start(String exe, List<String> args);
}

class SystemProc implements Proc {
  const SystemProc();

  @override
  Future<ProcessResult> run(String exe, List<String> args) =>
      Process.run(exe, args);

  @override
  ProcessResult runSync(String exe, List<String> args) =>
      Process.runSync(exe, args);

  @override
  Future<Process> start(String exe, List<String> args) =>
      Process.start(exe, args);
}
