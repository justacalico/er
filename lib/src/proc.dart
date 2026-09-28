import 'dart:io';

abstract class Proc {
  Future<ProcessResult> run(String exe, List<String> args);
  ProcessResult runSync(String exe, List<String> args);
  Future<Process> start(String exe, List<String> args, {String? pgidFile});

  // True when spawned processes live outside this process's pid namespace
  // (flatpak-spawn --host), so the session pgid can only be read back
  // through pgidFile.
  bool get needsPgidFile;
}

class SystemProc implements Proc {
  const SystemProc();

  @override
  bool get needsPgidFile => false;

  @override
  Future<ProcessResult> run(String exe, List<String> args) =>
      Process.run(exe, args);

  @override
  ProcessResult runSync(String exe, List<String> args) =>
      Process.runSync(exe, args);

  @override
  Future<Process> start(String exe, List<String> args, {String? pgidFile}) =>
      Process.start(exe, args);
}

// Runs every command on the host via flatpak-spawn, for when er itself is
// installed as a flatpak. Instance sessions get their pgid written to
// pgidFile because a host pid is meaningless inside the sandbox.
class FlatpakSpawnProc implements Proc {
  const FlatpakSpawnProc(
      [this.spawnPrefix = const ['flatpak-spawn', '--host']]);

  final List<String> spawnPrefix;

  @override
  bool get needsPgidFile => true;

  List<String> _argv(String exe, List<String> args) =>
      [...spawnPrefix, exe, ...args];

  @override
  Future<ProcessResult> run(String exe, List<String> args) {
    final argv = _argv(exe, args);
    return Process.run(argv.first, argv.sublist(1));
  }

  @override
  ProcessResult runSync(String exe, List<String> args) {
    final argv = _argv(exe, args);
    return Process.runSync(argv.first, argv.sublist(1));
  }

  @override
  Future<Process> start(String exe, List<String> args, {String? pgidFile}) {
    // The caller asks for a new session by putting setsid first; the wrapper
    // owns setsid itself so the recorded pid really is the session leader.
    // --fork makes setsid deterministic: the session leader is the inner sh
    // (it records $$ itself), and --wait keeps the tracked process alive
    // until the program exits.
    final newSession = exe == 'setsid';
    final cmd = newSession ? args : [exe, ...args];
    final String body;
    if (newSession && pgidFile != null) {
      body = 'setsid --fork --wait sh -c '
          '\'echo \$\$ > "\$0"; exec "\$@"\' "$pgidFile" "\$@"'
          ' </dev/null & child=\$!; wait "\$child"';
    } else if (newSession) {
      body = 'exec setsid --wait "\$@"';
    } else {
      body = 'exec "\$@"';
    }
    final argv = [...spawnPrefix, 'sh', '-c', body, 'er-spawn', ...cmd];
    return Process.start(argv.first, argv.sublist(1));
  }
}
