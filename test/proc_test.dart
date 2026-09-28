import 'dart:io';

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

  group('FlatpakSpawnProc', () {
    final p = FlatpakSpawnProc(const []);

    test('reports needing a pgid file', () {
      expect(p.needsPgidFile, isTrue);
      expect(const SystemProc().needsPgidFile, isFalse);
    });

    test('run wraps the command in the spawn prefix', () async {
      final r = await p.run('echo', ['hi']);
      expect(r.exitCode, 0);
      expect((r.stdout as String).trim(), 'hi');
      final withPrefix =
          await FlatpakSpawnProc(const ['env']).run('echo', ['hi']);
      expect((withPrefix.stdout as String).trim(), 'hi');
    });

    test('runSync wraps the command in the spawn prefix', () {
      final r = p.runSync('echo', ['hi']);
      expect(r.exitCode, 0);
      expect((r.stdout as String).trim(), 'hi');
    });

    test('start with pgid file records the session leader', () async {
      final dir = Directory.systemTemp.createTempSync('er');
      addTearDown(() => dir.deleteSync(recursive: true));
      final pgidFile = '${dir.path}/er.pgid';
      final proc =
          await p.start('setsid', ['sleep', '30'], pgidFile: pgidFile);
      for (var i = 0; i < 100 && !File(pgidFile).existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final pgid = int.parse(File(pgidFile).readAsStringSync().trim());
      // The recorded pid must be a live process whose own process group id
      // is itself, i.e. the setsid'd session leader.
      final stat = File('/proc/$pgid/stat').readAsStringSync();
      final rest = stat.substring(stat.lastIndexOf(')') + 2).split(' ');
      expect(rest[0], isNot('Z'));
      expect(int.parse(rest[2]), pgid);
      Process.runSync('kill', ['-KILL', '--', '-$pgid']);
      await proc.exitCode;
    });

    test('start without setsid execs the command', () async {
      final proc = await p.start('true', const []);
      expect(await proc.exitCode, 0);
    });

    test('start with setsid but no pgid file still works', () async {
      final proc = await p.start('setsid', ['true']);
      expect(await proc.exitCode, 0);
    });
  });
}

