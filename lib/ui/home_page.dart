import 'package:flutter/material.dart';

import '../src/flatpak_service.dart';
import '../src/instance_store.dart';
import '../src/models.dart';
import 'app_icon.dart';
import 'instance_tile.dart';
import 'new_instance_sheet.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.service, required this.store});

  final FlatpakService service;
  final InstanceStore store;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<FlatpakApp>? _apps;
  FlatpakApp? _selected;
  bool _loading = true;

  FlatpakService get _service => widget.service;
  InstanceStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    _store.load();
    _sweepTemps();
    _refreshApps();
  }

  // Drop temp instances left behind by a previous run (e.g. er was killed
  // while one was up). Ones still running stay listed so they can be
  // stopped, which wipes them.
  void _sweepTemps() {
    var changed = false;
    for (final entry in _store.entries.toList()) {
      for (final inst in entry.value.toList()) {
        if (!inst.temporary || _service.isRunning(inst)) continue;
        _service.wipeInstance(inst);
        _store.remove(entry.key, inst.name);
        changed = true;
      }
    }
    if (changed) _store.save();
  }

  Future<void> _refreshApps() async {
    setState(() => _loading = true);
    final apps = await _service.listApps();
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _loading = false;
      if (_selected == null || !apps.any((a) => a.id == _selected!.id)) {
        _selected = apps.isEmpty ? null : apps.first;
      }
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addInstance() async {
    final app = _selected;
    if (app == null) return;
    final existing = _store.forApp(app.id).map((i) => i.name).toSet();
    final inst = await showNewInstanceSheet(
        context, app.id, existing, (n) => _service.instanceHome(app.id, n));
    if (inst == null) return;
    setState(() => _store.forApp(app.id).add(inst));
    _store.save();
  }

  Future<void> _launch(AppInstance inst) async {
    try {
      await _service.launch(inst);
      _store.save();
    } catch (e) {
      _snack('Launch failed: $e');
    }
    setState(() {});
  }

  Future<void> _runTemp() async {
    final app = _selected;
    if (app == null) return;
    final taken = _store.forApp(app.id).map((i) => i.name).toSet();
    var n = 1;
    while (taken.contains('temp $n')) {
      n++;
    }
    final inst = AppInstance(
      appId: app.id,
      name: 'temp $n',
      home: _service.instanceHome(app.id, 'temp $n'),
      temporary: true,
    );
    setState(() => _store.forApp(app.id).add(inst));
    try {
      await _service.launch(inst, onExit: () => _reapTemp(inst));
      _store.save();
    } catch (e) {
      _store.remove(app.id, inst.name);
      _snack('Launch failed: $e');
    }
    setState(() {});
  }

  // A temp instance only exists while its process does; wipe it once the
  // process exits on its own.
  void _reapTemp(AppInstance inst) {
    _service.wipeInstance(inst);
    _store.remove(inst.appId, inst.name);
    _store.save();
    if (mounted) setState(() {});
  }

  Future<void> _stop(AppInstance inst) async {
    await _service.stop(inst);
    if (inst.temporary) {
      _service.wipeInstance(inst);
      _store.remove(inst.appId, inst.name);
      _store.save();
    }
    setState(() {});
  }

  Future<void> _delete(AppInstance inst) async {
    if (!inst.temporary) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Delete "${inst.name}"?'),
          content:
              const Text('The instance and all of its data will be removed.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete')),
          ],
        ),
      );
      if (confirm != true) return;
    }
    await _service.stop(inst);
    _service.wipeInstance(inst);
    setState(() => _store.remove(inst.appId, inst.name));
    _store.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('er 二',
            style: TextStyle(fontWeight: FontWeight.w800, color: erAccent)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshApps,
          ),
        ],
      ),
      body: Row(
        children: [
          SizedBox(width: 300, child: _buildAppList()),
          const VerticalDivider(width: 1),
          Expanded(child: _buildDetail()),
        ],
      ),
    );
  }

  Widget _buildAppList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final apps = _apps ?? [];
    if (apps.isEmpty) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('No flatpak apps installed'),
      ));
    }
    return ListView.builder(
      itemCount: apps.length,
      itemBuilder: (ctx, i) {
        final app = apps[i];
        return ListTile(
          dense: true,
          selected: app.id == _selected?.id,
          leading: AppIcon(app: app, size: 32),
          title: Text(app.name, overflow: TextOverflow.ellipsis),
          subtitle: Text(app.id,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis),
          onTap: () => setState(() => _selected = app),
        );
      },
    );
  }

  Widget _buildDetail() {
    final app = _selected;
    if (app == null) {
      return const Center(child: Text('Select an app'));
    }
    final instances = _store.forApp(app.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIcon(app: app, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        Text('${app.id} · ${app.version}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF9BA7B4))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _runTemp,
                    icon: const Icon(Icons.bolt),
                    label: const Text('Run once'),
                  ),
                  FilledButton.icon(
                    onPressed: _addInstance,
                    icon: const Icon(Icons.add),
                    label: const Text('New instance'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: instances.isEmpty
              ? const Center(
                  child: Text('No instances yet — create one to run a '
                      'second copy of this app'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: instances.length,
                  itemBuilder: (ctx, i) {
                    final inst = instances[i];
                    return InstanceTile(
                      instance: inst,
                      running: _service.isRunning(inst),
                      onLaunch: () => _launch(inst),
                      onStop: () => _stop(inst),
                      onDelete: () => _delete(inst),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
