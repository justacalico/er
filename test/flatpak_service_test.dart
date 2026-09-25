import 'dart:io';

import 'package:er/src/flatpak_service.dart';
import 'package:er/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_proc.dart';

FlatpakService svc(FakeProc proc, String root, [String home = '/h']) =>
    FlatpakService(proc: proc, hostHome: home, instancesRoot: root);

AppInstance inst(String root,
        {bool bus = true, bool home = true, int? pgid}) =>
    AppInstance(
      appId: 'org.example.App',
      name: 'alt',
      home: '$root/org.example.app/alt/home',
      privateBus: bus,
      isolateHome: home,
      pgid: pgid,
    );

void main() {
  test('parseAppList parses TSV and skips bad lines', () {
    final out = FlatpakService.parseAppList(
      'org.a.One\tApp One\t1.0\tflathub\tsystem\n'
      '\n'
      'org.b.Two\tApp Two\n'
      'broken\n',
    );
    expect(out, hasLength(2));
    expect(out[0].id, 'org.a.One');
    expect(out[0].name, 'App One');
    expect(out[0].version, '1.0');
    expect(out[0].origin, 'flathub');
    expect(out[0].installation, 'system');
    expect(out[1].version, '');
  });

  test('iconFor reads Icon= and prefers raster over svg', () {
    final root = Directory.systemTemp.createTempSync('er');
    addTearDown(() => root.deleteSync(recursive: true));
    final deploy =
        '${root.path}/sys/app/org.a.One/current/active';
    File('$deploy/export/share/applications/org.a.One.desktop')
      ..createSync(recursive: true)
      ..writeAsStringSync('[Desktop Entry]\n'
          'Name=One\n'
          'Icon=one-icon\n'
          '[Desktop Action x]\n'
          'Icon=wrong\n');
    File('$deploy/export/share/icons/hicolor/48x48/apps/one-icon.png')
        .createSync(recursive: true);
    File('$deploy/export/share/icons/hicolor/scalable/apps/one-icon.svg')
        .createSync(recursive: true);
    final s = FlatpakService(
        proc: FakeProc(),
        hostHome: '${root.path}/home',
        instancesRoot: '${root.path}/inst',
        systemFlatpakDir: '${root.path}/sys',
        hostIconDirs: []);
    final app = FlatpakApp(
        id: 'org.a.One',
        name: 'One',
        version: '',
        origin: '',
        installation: 'system');
    expect(s.iconFor(app), endsWith('48x48/apps/one-icon.png'));
  });

  test('iconFor uses appstream cache and largest size', () {
    final root = Directory.systemTemp.createTempSync('er');
    addTearDown(() => root.deleteSync(recursive: true));
    final deploy =
        '${root.path}/sys/app/org.b.Two/current/active';
    File('$deploy/files/share/app-info/icons/flatpak/64x64/org.b.Two.png')
        .createSync(recursive: true);
    File('$deploy/files/share/app-info/icons/flatpak/128x128/org.b.Two.png')
        .createSync(recursive: true);
    final s = FlatpakService(
        proc: FakeProc(),
        hostHome: '${root.path}/home',
        instancesRoot: '${root.path}/inst',
        systemFlatpakDir: '${root.path}/sys',
        hostIconDirs: []);
    final app = FlatpakApp(
        id: 'org.b.Two',
        name: 'Two',
        version: '',
        origin: '',
        installation: 'system');
    expect(s.iconFor(app), endsWith('128x128/org.b.Two.png'));
  });

  test('iconFor returns null on unreadable desktop file', () {
    final root = Directory.systemTemp.createTempSync('er');
    addTearDown(() => root.deleteSync(recursive: true));
    final desktop = File(
        '${root.path}/sys/app/org.a.One/current/active/export/share/'
        'applications/org.a.One.desktop')
      ..createSync(recursive: true);
    Process.runSync('chmod', ['000', desktop.path]);
    final s = FlatpakService(
        proc: FakeProc(),
        hostHome: '${root.path}/home',
        instancesRoot: '${root.path}/inst',
        systemFlatpakDir: '${root.path}/sys',
        hostIconDirs: []);
    final app = FlatpakApp(
        id: 'org.a.One',
        name: 'One',
        version: '',
        origin: '',
        installation: 'system');
    expect(s.iconFor(app), isNull);
  });

  test('iconFor returns null when no icon exists', () {
    final root = Directory.systemTemp.createTempSync('er');
    addTearDown(() => root.deleteSync(recursive: true));
    final s = FlatpakService(
        proc: FakeProc(),
        hostHome: '${root.path}/home',
        instancesRoot: '${root.path}/inst',
        systemFlatpakDir: '${root.path}/sys',
        hostIconDirs: []);
    final app = FlatpakApp(
        id: 'org.c.Three',
        name: 'Three',
        version: '',
        origin: '',
        installation: 'system');
    expect(s.iconFor(app), isNull);
  });

  test('listApps fills iconPath', () async {
    final root = Directory.systemTemp.createTempSync('er');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/sys/app/org.a.One/current/active/files/share/'
            'app-info/icons/flatpak/64x64/org.a.One.png')
        .createSync(recursive: true);
    final p = FakeProc();
    p.onRun = (e, a) =>
        ProcessResult(0, 0, 'org.a.One\tApp One\t1\tf\ts\n', '');
    final s = FlatpakService(
        proc: p,
        hostHome: '${root.path}/home',
        instancesRoot: '${root.path}/inst',
        systemFlatpakDir: '${root.path}/sys',
        hostIconDirs: []);
    final apps = await s.listApps();
    expect(apps.single.iconPath, endsWith('org.a.One.png'));
  });

  test('slug normalizes names', () {
    expect(FlatpakService.slug('My Alt 2'), 'my-alt-2');
    expect(FlatpakService.slug('!!!'), 'instance');
    expect(FlatpakService.slug('--a--'), 'a');
    expect(FlatpakService.slug('ok'), 'ok');
  });

  test('dataDir respects XDG_DATA_HOME', () {
    expect(FlatpakService.dataDir({'XDG_DATA_HOME': '/x', 'HOME': '/h'}),
        '/x/er');
    expect(FlatpakService.dataDir({'XDG_DATA_HOME': '', 'HOME': '/h'}),
        '/h/.local/share/er');
    expect(FlatpakService.dataDir({'HOME': '/h'}), '/h/.local/share/er');
    expect(FlatpakService.dataDir(), contains('/er'));
  });

  test('instanceHome nests under instances root', () {
    final s = svc(FakeProc(), '/r');
    expect(s.instanceHome('org.a.One', 'Alt 2'),
        '/r/org.a.one/alt-2/home');
  });

  test('listApps parses output and tolerates failures', () async {
    final p = FakeProc();
    p.onRun = (exe, args) => ProcessResult(0, 0, 'org.a.One\tApp One\t1\tf\ts\n', '');
    expect(await svc(p, '/r').listApps(), hasLength(1));

    p.onRun = (exe, args) => ProcessResult(0, 1, '', 'no');
    expect(await svc(p, '/r').listApps(), isEmpty);

    p.onRun = (exe, args) => throw const ProcessException('flatpak', []);
    expect(await svc(p, '/r').listApps(), isEmpty);
  });

  test('launchArgv full isolation', () {
    final s = svc(FakeProc(), '/r');
    final argv = s.launchArgv(inst('/r'), appArgs: ['--x'], extraBinds: [
      '/h/.local/share/flatpak',
      '/h/.fonts',
    ]);
    expect(
        argv,
        equals([
          'setsid',
          'bwrap', '--dev-bind', '/', '/',
          '--bind', '/r/org.example.app/alt/home', '/h',
          '--bind', '/h/.local/share/flatpak', '/h/.local/share/flatpak',
          '--ro-bind', '/h/.fonts', '/h/.fonts',
          '--',
          'dbus-run-session', '--',
          'flatpak', 'run', 'org.example.App', '--x',
        ]));
  });

  test('launchArgv variants', () {
    final s = svc(FakeProc(), '/r');
    expect(s.launchArgv(inst('/r', bus: false, home: false)),
        equals(['setsid', 'flatpak', 'run', 'org.example.App']));
    expect(s.launchArgv(inst('/r', bus: true, home: false)),
        equals([
          'setsid',
          'dbus-run-session', '--',
          'flatpak', 'run', 'org.example.App'
        ]));
    final argv = s.launchArgv(inst('/r', bus: false), extraBinds: []);
    expect(argv.take(2).toList(), ['setsid', 'bwrap']);
    expect(argv.sublist(argv.length - 3), ['flatpak', 'run', 'org.example.App']);
    expect(argv.contains('dbus-run-session'), isFalse);
  });

  test('ensureInstanceDirs creates home and bind targets', () {
    final root = Directory.systemTemp.createTempSync('er');
    addTearDown(() => root.deleteSync(recursive: true));
    final s = svc(FakeProc(), root.path);
    final i = inst(root.path);
    s.ensureInstanceDirs(i, extraBinds: ['/h/.fonts', '/h/.local/share/flatpak']);
    expect(Directory(i.home).existsSync(), isTrue);
    expect(Directory('${i.home}/.fonts').existsSync(), isTrue);
    expect(
        Directory('${i.home}/.local/share/flatpak').existsSync(), isTrue);
  });

  test('launch starts process and records pgid', () async {
    final root = Directory.systemTemp.createTempSync('er');
    addTearDown(() => root.deleteSync(recursive: true));
    final p = FakeProc()..onStart = (e, a) => FakeProcess(777);
    final s = svc(p, root.path, '/nonexistent-home');
    final i = inst(root.path);
    final pid = await s.launch(i);
    expect(pid, 777);
    expect(i.pgid, 777);
    expect(p.calls.single, startsWith('setsid bwrap'));
    expect(Directory(i.home).existsSync(), isTrue);
  });

  test('launch onExit fires when the process exits', () async {
    final root = Directory.systemTemp.createTempSync('er');
    addTearDown(() => root.deleteSync(recursive: true));
    final spawned = FakeProcess(4242);
    final p = FakeProc()..onStart = (e, a) => spawned;
    final s = svc(p, root.path, '/nonexistent-home');
    var exited = false;
    await s.launch(inst(root.path), onExit: () => exited = true);
    expect(exited, isFalse);
    spawned.kill();
    await Future<void>.delayed(Duration.zero);
    expect(exited, isTrue);
  });

  test('isRunning checks process group', () {
    final p = FakeProc();
    final s = svc(p, '/r');
    expect(s.isRunning(inst('/r')), isFalse);

    var alive = true;
    p.onRunSync = (e, a) => ProcessResult(0, alive ? 0 : 1, '', '');
    final i = inst('/r', pgid: 55);
    expect(s.isRunning(i), isTrue);
    expect(p.calls.last, 'kill -0 -- -55');
    alive = false;
    expect(s.isRunning(i), isFalse);
  });

  test('stop sends TERM then KILL if needed', () async {
    final p = FakeProc();
    final s = svc(p, '/r');
    final i = inst('/r', pgid: 9);

    var alive = false;
    p.onRunSync = (e, a) => ProcessResult(0, alive ? 0 : 1, '', '');
    await s.stop(i, pollInterval: Duration.zero);
    expect(p.calls.where((c) => c.contains('-TERM')), hasLength(1));
    expect(p.calls.where((c) => c.contains('-KILL')), isEmpty);

    alive = true;
    p.calls.clear();
    await s.stop(i, attempts: 2, pollInterval: Duration.zero);
    expect(p.calls.last, 'kill -KILL -- -9');

    p.calls.clear();
    await s.stop(inst('/r'));
    expect(p.calls, isEmpty);
  });

  test('wipeInstance only deletes inside instances root', () {
    final root = Directory.systemTemp.createTempSync('er');
    addTearDown(() => root.deleteSync(recursive: true));
    final p = FakeProc();
    final s = svc(p, root.path);
    final i = inst(root.path);
    s.ensureInstanceDirs(i, extraBinds: []);
    s.wipeInstance(i);
    expect(p.calls.single, startsWith('chmod -R u+w'));
    expect(Directory(i.home).parent.existsSync(), isFalse);

    p.calls.clear();
    final outside = inst('/tmp');
    s.wipeInstance(outside);
    expect(Directory('/tmp').existsSync(), isTrue);
    expect(p.calls, isEmpty);
  });
}
