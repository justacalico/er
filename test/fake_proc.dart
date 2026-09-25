import 'dart:async';
import 'dart:io';

import 'package:er/src/proc.dart';

class FakeProcess implements Process {
  FakeProcess(this.pid);

  @override
  final int pid;

  final _exit = Completer<int>();

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  Stream<List<int>> get stdout => const Stream.empty();

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!_exit.isCompleted) _exit.complete(0);
    return true;
  }
}

class FakeProc implements Proc {
  final calls = <String>[];
  final spawned = <FakeProcess>[];
  ProcessResult Function(String exe, List<String> args)? onRun;
  ProcessResult Function(String exe, List<String> args)? onRunSync;
  Process Function(String exe, List<String> args)? onStart;

  @override
  Future<ProcessResult> run(String exe, List<String> args) async {
    calls.add('$exe ${args.join(' ')}');
    return onRun?.call(exe, args) ?? ProcessResult(0, 0, '', '');
  }

  @override
  ProcessResult runSync(String exe, List<String> args) {
    calls.add('$exe ${args.join(' ')}');
    return onRunSync?.call(exe, args) ?? ProcessResult(0, 0, '', '');
  }

  @override
  Future<Process> start(String exe, List<String> args) async {
    calls.add('$exe ${args.join(' ')}');
    final p = onStart?.call(exe, args) ?? FakeProcess(4242);
    if (p is FakeProcess) spawned.add(p);
    return p;
  }
}
