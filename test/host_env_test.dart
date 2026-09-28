import 'dart:io';

import 'package:er/src/host_env.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_proc.dart';

void main() {
  test('sandboxed reflects /.flatpak-info', () {
    expect(HostEnv.sandboxed, File('/.flatpak-info').existsSync());
  });

  test('parse reads KEY=value lines and skips junk', () {
    final env = HostEnv.parse('A=1\nB=x=y\n\nnoequals\n=c\n');
    expect(env, {'A': '1', 'B': 'x=y'});
  });

  test('resolve returns null when not sandboxed', () async {
    expect(await HostEnv.resolve(FakeProc(), sandboxed: false), isNull);
  });

  test('resolve merges host env over the process env', () async {
    final p = FakeProc()
      ..onRun = (e, a) =>
          ProcessResult(0, 0, 'HOME=/host-home\nER_TEST_MARKER=1\n', '');
    final env = (await HostEnv.resolve(p, sandboxed: true))!;
    expect(env['HOME'], '/host-home');
    expect(env['ER_TEST_MARKER'], '1');
    expect(env.containsKey('PATH'), isTrue);
    expect(p.calls.single, 'flatpak-spawn --host env');
  });

  test('resolve keeps sandbox env when spawn fails', () async {
    final p = FakeProc()..onRun = (e, a) => ProcessResult(0, 1, '', 'nope');
    final env = (await HostEnv.resolve(p, sandboxed: true))!;
    expect(env['HOME'], Platform.environment['HOME']);

    final p2 = FakeProc()
      ..onRun = (e, a) => throw const ProcessException('flatpak-spawn', []);
    expect(await HostEnv.resolve(p2, sandboxed: true), isNotNull);
  });
}
