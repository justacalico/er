import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../app.dart';
import '../src/flatpak_service.dart';
import '../src/host_env.dart';
import '../src/instance_store.dart';
import '../src/proc.dart';

Future<Widget> buildApp() async {
  const proc = SystemProc();
  final sandboxed = HostEnv.sandboxed;
  final env = await HostEnv.resolve(proc, sandboxed: sandboxed) ??
      Platform.environment;
  final dataDir = FlatpakService.dataDir(env);
  return ErApp(
    service: FlatpakService(
      proc: sandboxed ? const FlatpakSpawnProc() : proc,
      hostHome: env['HOME'] ?? '',
      instancesRoot: '$dataDir/instances',
    ),
    store: InstanceStore(InstanceStore.defaultPath(dataDir)),
  );
}
