import 'dart:io';

import 'proc.dart';

// When er runs inside a flatpak sandbox, filesystem paths and environment
// must be the host's, not the sandbox's ~/.var/app view. Host commands go
// through flatpak-spawn, which sees the real environment.
class HostEnv {
  static const infoPath = '/.flatpak-info';

  static bool get sandboxed => File(infoPath).existsSync();

  // The host environment merged over the current one, or null when not
  // sandboxed. Falls back to the sandbox environment when flatpak-spawn
  // cannot be reached.
  static Future<Map<String, String>?> resolve(
    Proc proc, {
    bool sandboxed = true,
  }) async {
    if (!sandboxed) return null;
    final env = Map<String, String>.of(Platform.environment);
    try {
      final r = await proc.run('flatpak-spawn', ['--host', 'env']);
      if (r.exitCode == 0) env.addAll(parse(r.stdout as String));
    } on ProcessException {
      // Keep the sandbox environment.
    }
    // A custom XDG_DATA_HOME on the host is not reachable from the sandbox;
    // only the canonical ~/.local/share can be exposed to a flatpak.
    env.remove('XDG_DATA_HOME');
    return env;
  }

  static Map<String, String> parse(String out) {
    final env = <String, String>{};
    for (final line in out.split('\n')) {
      final i = line.indexOf('=');
      if (i > 0) env[line.substring(0, i)] = line.substring(i + 1);
    }
    return env;
  }
}
