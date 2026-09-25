import 'dart:async';
import 'dart:io';

import 'models.dart';
import 'proc.dart';

class FlatpakService {
  FlatpakService({
    required this.proc,
    required this.hostHome,
    required this.instancesRoot,
    this.systemFlatpakDir = '/var/lib/flatpak',
    List<String>? hostIconDirs,
  }) : hostIconDirs = hostIconDirs ??
            [
              '$hostHome/.local/share/icons',
              '$hostHome/.icons',
              '/usr/share/icons',
              '/usr/share/pixmaps',
            ];

  final Proc proc;
  final String hostHome;
  final String instancesRoot;
  final String systemFlatpakDir;
  final List<String> hostIconDirs;

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
      final apps = parseAppList(result.stdout as String);
      for (final app in apps) {
        app.iconPath = iconFor(app);
      }
      return apps;
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

  static const _iconExts = ['png', 'jpg', 'jpeg', 'webp', 'svg'];

  String? iconFor(FlatpakApp app) {
    try {
      return _resolveIcon(app);
    } on FileSystemException {
      return null;
    }
  }

  String? _resolveIcon(FlatpakApp app) {
    final names = {_desktopIconName(app.id) ?? app.id, app.id};
    for (final name in names) {
      if (name.startsWith('/') && File(name).existsSync()) return name;
    }
    String? best;
    var bestScore = -1;
    for (final dir in _iconSearchDirs(app.id)) {
      for (final name in names) {
        for (final ext in _iconExts) {
          if (!File('$dir/$name.$ext').existsSync()) continue;
          final score = _iconScore(dir, ext);
          if (score > bestScore) {
            bestScore = score;
            best = '$dir/$name.$ext';
          }
        }
      }
    }
    return best;
  }

  String? _desktopIconName(String appId) {
    for (final path in _desktopFiles(appId)) {
      final f = File(path);
      if (!f.existsSync()) continue;
      var inEntry = false;
      for (final line in f.readAsLinesSync()) {
        final l = line.trim();
        if (l.startsWith('[')) {
          inEntry = l == '[Desktop Entry]';
          continue;
        }
        if (inEntry && l.startsWith('Icon=')) return l.substring(5).trim();
      }
    }
    return null;
  }

  Iterable<String> _desktopFiles(String appId) sync* {
    for (final root in [_userFlatpakDir, systemFlatpakDir]) {
      yield '$root/exports/share/applications/$appId.desktop';
      yield '$root/app/$appId/current/active/export/share/applications/$appId.desktop';
    }
  }

  List<String> _iconSearchDirs(String appId) {
    final dirs = <String>[];
    for (final root in [_userFlatpakDir, systemFlatpakDir]) {
      dirs.addAll(_themeSizeDirs('$root/exports/share/icons'));
      final deploy = '$root/app/$appId/current/active';
      dirs.addAll(_themeSizeDirs('$deploy/export/share/icons'));
      dirs.addAll(_themeSizeDirs('$deploy/files/share/app-info/icons'));
    }
    for (final root in hostIconDirs) {
      dirs.addAll(_themeSizeDirs(root));
    }
    return dirs;
  }

  // Returns the root itself plus every <theme>/<size>[/apps] pair, so both
  // icon-theme layouts and flat dirs like /usr/share/pixmaps are covered.
  static List<String> _themeSizeDirs(String root) {
    final base = Directory(root);
    if (!base.existsSync()) return [];
    final dirs = <String>[root];
    for (final theme in base.listSync()) {
      if (theme is! Directory) continue;
      for (final size in theme.listSync()) {
        if (size is! Directory) continue;
        dirs.add('${size.path}/apps');
        dirs.add(size.path);
      }
    }
    return dirs;
  }

  // Raster wins over svg (which Image.file can't decode); bigger size wins.
  static int _iconScore(String dir, String ext) {
    var seg = dir.split('/').last;
    if (seg == 'apps') seg = dir.split('/').reversed.elementAt(1);
    var size = 0;
    final m = RegExp(r'^(\d+)x\d+(?:@(\d+))?$').firstMatch(seg);
    if (m != null) {
      size = int.parse(m.group(1)!) * (int.tryParse(m.group(2) ?? '') ?? 1);
    } else if (seg == 'scalable') {
      size = 1 << 16;
    }
    return size + (ext == 'svg' ? 0 : 1 << 20);
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

  Future<int> launch(
    AppInstance inst, {
    List<String> appArgs = const [],
    void Function()? onExit,
  }) async {
    ensureInstanceDirs(inst);
    final argv = launchArgv(inst, appArgs: appArgs);
    final process = await proc.start(argv.first, argv.sublist(1));
    inst.pgid = process.pid;
    if (onExit != null) {
      unawaited(process.exitCode.then((_) => onExit()));
    }
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
