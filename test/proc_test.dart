import 'package:er/src/proc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final p = SystemProc();

  test('run returns output', () async {
    final r = await p.run('echo', ['hi']);
    expect(r.exitCode, 0);
    expect((r.stdout as String).trim(), 'hi');
  });

  test('runSync returns output', () {
    final r = p.runSync('echo', ['hi']);
    expect(r.exitCode, 0);
  });

  test('start spawns process', () async {
    final proc = await p.start('sleep', ['0']);
    expect(proc.pid, greaterThan(0));
    expect(await proc.exitCode, 0);
  });
}
