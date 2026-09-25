import 'dart:convert';
import 'dart:io';

import 'models.dart';

class InstanceStore {
  InstanceStore(this.path);

  final String path;
  final Map<String, List<AppInstance>> _byApp = {};

  static String defaultPath(String dataDir) => '$dataDir/instances.json';

  void load() {
    _byApp.clear();
    final file = File(path);
    if (!file.existsSync()) return;
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    for (final entry in decoded.entries) {
      _byApp[entry.key] = [
        for (final j in entry.value as List)
          AppInstance.fromJson(j as Map<String, dynamic>),
      ];
    }
  }

  void save() {
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(
        _byApp.map((k, v) => MapEntry(k, v.map((i) => i.toJson()).toList())),
      ));
  }

  Iterable<MapEntry<String, List<AppInstance>>> get entries => _byApp.entries;

  List<AppInstance> forApp(String appId) => _byApp[appId] ??= [];

  void remove(String appId, String name) {
    _byApp[appId]?.removeWhere((i) => i.name == name);
  }
}
