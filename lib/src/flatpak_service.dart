import 'dart:io';

import 'models.dart';
import 'proc.dart';

class FlatpakService {
  FlatpakService({
    required this.proc,
    required this.hostHome,
    required this.instancesRoot,
  });

  final Proc proc;
  final String hostHome;
  final String instancesRoot;

  static String dataDir([Map<String, String>? env]) {
    env ??= Platform.environment;
    final xdg = env['XDG_DATA_HOME'];
    if (xdg != null && xdg.isNotEmpty) return '$xdg/er';
    return '${env['HOME']}/.local/share/er';
  }

  static const extraHomeBinds = [
    '.local/share/fonts',
    '.fonts',
    '.icons',
    '.themes',
  ];

  Future<List<FlatpakApp>> listApps() async {
    try {
      final result = await proc.run('flatpak', [
        'list',
        '--app',
        '--columns=application,name,version,origin,installation',
      ]);
      if (result.exitCode != 0) return [];
      return parseAppList(result.stdout as String);
    } on ProcessException {
      return [];
    }
  }

  static List<FlatpakApp> parseAppList(String output) {
    final apps = <FlatpakApp>[];
    for (final line in output.split('\n')) {
      if (line.trim().isEmpty) continue;
      final cols = line.split('\t');
      if (cols.length < 2) continue;
      apps.add(FlatpakApp(
        id: cols[0],
        name: cols[1],
        version: cols.length > 2 ? cols[2] : '',
        origin: cols.length > 3 ? cols[3] : '',
        installation: cols.length > 4 ? cols[4] : '',
      ));
    }
    return apps;
  }

  static String slug(String name) {
    final s = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return s.isEmpty ? 'instance' : s;
  }

  String instanceHome(String appId, String name) =>
      '$instancesRoot/${slug(appId)}/${slug(name)}/home';

  String get _userFlatpakDir => '$hostHome/.local/share/flatpak';

  List<String> _hostExtraBinds() => [
        _userFlatpakDir,
        for (final rel in extraHomeBinds) '$hostHome/$rel',
      ].where((d) => Directory(d).existsSync()).toList();

  List<String> launchArgv(
    AppInstance inst, {
    List<String> appArgs = const [],
    List<String>? extraBinds,
  }) {
    final inner = [
      if (inst.privateBus) ...['dbus-run-session', '--'],
      'flatpak',
      'run',
      inst.appId,
      ...appArgs,
    ];
    final argv = ['setsid'];
    if (inst.isolateHome) {
      argv.addAll(['bwrap', '--dev-bind', '/', '/']);
      argv.addAll(['--bind', inst.home, hostHome]);
      for (final dir in extraBinds ?? _hostExtraBinds()) {
        final rel = dir.substring(hostHome.length + 1);
        final rw = rel == '.local/share/flatpak';
        argv.addAll([rw ? '--bind' : '--ro-bind', dir, '$hostHome/$rel']);
      }
      argv.add('--');
    }
    argv.addAll(inner);
    return argv;
  }

  void ensureInstanceDirs(AppInstance inst, {List<String>? extraBinds}) {
    Directory(inst.home).createSync(recursive: true);
    for (final dir in extraBinds ?? _hostExtraBinds()) {
      final rel = dir.substring(hostHome.length + 1);
      Directory('${inst.home}/$rel').createSync(recursive: true);
    }
  }

  Future<int> launch(AppInstance inst, {List<String> appArgs = const []}) async {
    ensureInstanceDirs(inst);
    final argv = launchArgv(inst, appArgs: appArgs);
    final process = await proc.start(argv.first, argv.sublist(1));
    inst.pgid = process.pid;
    return process.pid;
  }

  bool isRunning(AppInstance inst) {
    final pgid = inst.pgid;
    if (pgid == null) return false;
    return proc.runSync('kill', ['-0', '--', '-$pgid']).exitCode == 0;
  }

  Future<void> stop(
    AppInstance inst, {
    int attempts = 30,
    Duration pollInterval = const Duration(milliseconds: 100),
  }) async {
    final pgid = inst.pgid;
    if (pgid == null) return;
    proc.runSync('kill', ['-TERM', '--', '-$pgid']);
    for (var i = 0; i < attempts && isRunning(inst); i++) {
      await Future<void>.delayed(pollInterval);
    }
    if (isRunning(inst)) {
      proc.runSync('kill', ['-KILL', '--', '-$pgid']);
    }
  }

  void wipeInstance(AppInstance inst) {
    final dir = Directory(inst.home).parent;
    if (!dir.path.startsWith(instancesRoot) || !dir.existsSync()) return;
    // Sandboxed apps can drop read-only files (mocktail's APK payload does),
    // so make everything writable before deleting.
    proc.runSync('chmod', ['-R', 'u+w', dir.path]);
    dir.deleteSync(recursive: true);
  }
}
