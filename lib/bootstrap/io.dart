import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../app.dart';
import '../src/flatpak_service.dart';
import '../src/instance_store.dart';
import '../src/proc.dart';

Widget buildApp() {
  final dataDir = FlatpakService.dataDir();
  return ErApp(
    service: FlatpakService(
      proc: const SystemProc(),
      hostHome: Platform.environment['HOME'] ?? '',
      instancesRoot: '$dataDir/instances',
    ),
    store: InstanceStore(InstanceStore.defaultPath(dataDir)),
  );
}
