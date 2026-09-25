import 'dart:convert';
import 'dart:io';

import 'package:er/app.dart';
import 'package:er/src/flatpak_service.dart';
import 'package:er/src/instance_store.dart';
import 'package:er/src/models.dart';
import 'package:er/ui/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_proc.dart';

const tsv = 'org.a.One\tApp One\t1.0\tflathub\tsystem\n'
    'org.b.Two\tApp Two\t2.0\tflathub\tuser\n';

Future<(FakeProc, InstanceStore)> pumpApp(WidgetTester t,
    {String? listOut,
    void Function(Directory dir)? seed,
    bool aliveStart = false}) async {
  final dir = Directory.systemTemp.createTempSync('er');
  addTearDown(() => dir.deleteSync(recursive: true));
  seed?.call(dir);
  final proc = FakeProc();
  proc.onRun = (e, a) =>
      ProcessResult(0, 0, listOut ?? tsv, '');
  var alive = aliveStart;
  proc.onRunSync = (e, a) {
    if (a.contains('-TERM')) alive = false;
    return ProcessResult(0, alive ? 0 : 1, '', '');
  };
  proc.onStart = (e, a) {
    alive = true;
    return FakeProcess(31337);
  };
  final service = FlatpakService(
      proc: proc, hostHome: dir.path, instancesRoot: '${dir.path}/inst');
  final store = InstanceStore('${dir.path}/instances.json');
  await t.pumpWidget(ErApp(service: service, store: store));
  await t.pumpAndSettle();
  return (proc, store);
}

void main() {
  testWidgets('lists apps and selects one', (t) async {
    await pumpApp(t);
    expect(find.text('App One'), findsNWidgets(2));
    expect(find.text('App Two'), findsOneWidget);
    expect(find.text('New instance'), findsOneWidget);
    await t.tap(find.text('App Two'));
    await t.pumpAndSettle();
    expect(find.text('org.b.Two · 2.0'), findsOneWidget);
  });

  testWidgets('app icons fall back to a letter tile', (t) async {
    await pumpApp(t);
    expect(find.byType(AppIcon), findsNWidgets(3));
    expect(find.text('A'), findsNWidgets(3));
  });

  testWidgets('app icon renders an image file', (t) async {
    final dir = Directory.systemTemp.createTempSync('er');
    addTearDown(() => dir.deleteSync(recursive: true));
    // 1x1 transparent png
    File('${dir.path}/a.png').writeAsBytesSync(const [
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1,
      0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65,
      84, 120, 156, 98, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73,
      69, 78, 68, 174, 66, 96, 130,
    ]);
    File('${dir.path}/bad.png').writeAsStringSync('not an image');
    FlatpakApp iconApp(String path) => FlatpakApp(
        id: 'org.x.Y',
        name: 'Xy',
        version: '',
        origin: '',
        installation: 'system',
        iconPath: path);

    // Image.file resolves over real async io, so pump inside runAsync.
    await t.runAsync(() async {
      await t.pumpWidget(MaterialApp(
          home: AppIcon(app: iconApp('${dir.path}/a.png'), size: 32)));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await t.pump();
      expect(find.byType(Image), findsOneWidget);

      await t.pumpWidget(MaterialApp(
          home: AppIcon(app: iconApp('${dir.path}/bad.png'), size: 32)));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await t.pump();
      t.takeException();
      expect(find.text('X'), findsOneWidget);
    });
  });

  testWidgets('empty state when no flatpaks', (t) async {
    await pumpApp(t, listOut: '');
    expect(find.text('No flatpak apps installed'), findsOneWidget);
    expect(find.text('Select an app'), findsOneWidget);
  });

  testWidgets('create, launch, stop, delete an instance', (t) async {
    final (proc, store) = await pumpApp(t);

    await t.tap(find.text('New instance'));
    await t.pumpAndSettle();
    expect(find.text('Isolated home'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'alt one');
    await t.tap(find.text('Private D-Bus session'));
    await t.pump();
    await t.tap(find.text('Create'));
    await t.pumpAndSettle();

    expect(find.text('alt one'), findsOneWidget);
    expect(find.textContaining('shared bus'), findsOneWidget);
    expect(store.forApp('org.a.One'), hasLength(1));

    await t.tap(find.byTooltip('Launch'));
    await t.pumpAndSettle();
    expect(proc.calls, contains(contains('flatpak run org.a.One')));
    expect(find.byTooltip('Stop'), findsOneWidget);

    await t.tap(find.byTooltip('Stop'));
    await t.pumpAndSettle();
    expect(proc.calls, contains(contains('-TERM')));

    await t.tap(find.byTooltip('Delete instance and its data'));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    expect(store.forApp('org.a.One'), isEmpty);
    expect(find.textContaining('No instances yet'), findsOneWidget);
  });

  testWidgets('delete cancel keeps instance', (t) async {
    final (proc, store) = await pumpApp(t);
    await t.tap(find.text('New instance'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'keep');
    await t.pump();
    await t.tap(find.text('Create'));
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('Delete instance and its data'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(store.forApp('org.a.One'), hasLength(1));
  });

  testWidgets('new instance dialog validates and cancels', (t) async {
    await pumpApp(t);
    await t.tap(find.text('New instance'));
    await t.pumpAndSettle();
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Create')).onPressed, isNull);

    await t.enterText(find.byType(TextField), 'x');
    await t.tap(find.text('Isolated home'));
    await t.pump();
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Create')).onPressed, isNotNull);
    await t.tap(find.text('Create'));
    await t.pumpAndSettle();

    await t.tap(find.text('New instance'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'x');
    await t.pump();
    expect(find.text('Name already used'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.text('New instance'), findsOneWidget);
  });

  testWidgets('run once launches a temp instance and reaps it on exit',
      (t) async {
    final (proc, store) = await pumpApp(t);
    final dir = File(store.path).parent.path;

    await t.tap(find.text('Run once'));
    await t.pumpAndSettle();
    expect(find.text('temp 1'), findsOneWidget);
    expect(find.textContaining('temporary'), findsOneWidget);
    expect(proc.calls, contains(contains('flatpak run org.a.One')));
    expect(store.forApp('org.a.One').single.temporary, isTrue);
    expect(Directory('$dir/inst/org.a.one/temp-1/home').existsSync(), isTrue);

    await t.tap(find.text('Run once'));
    await t.pumpAndSettle();
    expect(find.text('temp 2'), findsOneWidget);

    proc.spawned[0].kill();
    await t.pumpAndSettle();
    expect(find.text('temp 1'), findsNothing);
    expect(store.forApp('org.a.One').map((i) => i.name), ['temp 2']);
    expect(Directory('$dir/inst/org.a.one/temp-1').existsSync(), isFalse);
  });

  testWidgets('stopping a temp instance wipes it', (t) async {
    final (proc, store) = await pumpApp(t);
    final dir = File(store.path).parent.path;

    await t.tap(find.text('Run once'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Stop'), findsOneWidget);

    await t.tap(find.byTooltip('Stop'));
    await t.pumpAndSettle();
    expect(proc.calls, contains(contains('-TERM')));
    expect(store.forApp('org.a.One'), isEmpty);
    expect(Directory('$dir/inst/org.a.one/temp-1').existsSync(), isFalse);
    expect(find.textContaining('No instances yet'), findsOneWidget);
  });

  testWidgets('deleting a temp instance skips confirmation', (t) async {
    final (_, store) = await pumpApp(t);

    await t.tap(find.text('Run once'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Delete instance and its data'));
    await t.pumpAndSettle();

    expect(find.text('Cancel'), findsNothing);
    expect(store.forApp('org.a.One'), isEmpty);
    expect(find.textContaining('No instances yet'), findsOneWidget);
  });

  testWidgets('run once failure drops the temp instance', (t) async {
    final (proc, store) = await pumpApp(t);
    proc.onStart = (e, a) => throw const ProcessException('setsid', []);

    await t.tap(find.text('Run once'));
    await t.pumpAndSettle();
    expect(find.textContaining('Launch failed'), findsOneWidget);
    expect(find.text('temp 1'), findsNothing);
    expect(store.forApp('org.a.One'), isEmpty);
  });

  testWidgets('sweeps dead temp instances left from a previous run',
      (t) async {
    late Directory dir;
    final (_, store) = await pumpApp(t, seed: (d) {
      dir = d;
      File('${d.path}/instances.json').writeAsStringSync(jsonEncode({
        'org.a.One': [
          {
            'appId': 'org.a.One',
            'name': 'temp 9',
            'home': '${d.path}/inst/org.a.one/temp-9/home',
            'temporary': true,
          },
          {
            'appId': 'org.a.One',
            'name': 'keep',
            'home': '${d.path}/inst/org.a.one/keep/home',
          },
        ],
      }));
      Directory('${d.path}/inst/org.a.one/temp-9/home')
          .createSync(recursive: true);
      Directory('${d.path}/inst/org.a.one/keep/home')
          .createSync(recursive: true);
    });

    expect(store.forApp('org.a.One').map((i) => i.name), ['keep']);
    expect(find.text('keep'), findsOneWidget);
    expect(find.text('temp 9'), findsNothing);
    expect(Directory('${dir.path}/inst/org.a.one/temp-9').existsSync(),
        isFalse);
    expect(Directory('${dir.path}/inst/org.a.one/keep').existsSync(), isTrue);
  });

  testWidgets('keeps a still-running temp instance on startup', (t) async {
    final (_, store) = await pumpApp(t, aliveStart: true, seed: (d) {
      File('${d.path}/instances.json').writeAsStringSync(jsonEncode({
        'org.a.One': [
          {
            'appId': 'org.a.One',
            'name': 'temp 9',
            'home': '${d.path}/inst/org.a.one/temp-9/home',
            'temporary': true,
            'pgid': 555,
          },
        ],
      }));
      Directory('${d.path}/inst/org.a.one/temp-9/home')
          .createSync(recursive: true);
    });

    expect(find.text('temp 9'), findsOneWidget);
    expect(find.textContaining('temporary'), findsOneWidget);

    await t.tap(find.byTooltip('Stop'));
    await t.pumpAndSettle();
    expect(store.forApp('org.a.One'), isEmpty);
    expect(find.text('temp 9'), findsNothing);
  });

  testWidgets('launch failure shows snackbar', (t) async {
    final (proc, _) = await pumpApp(t);
    await t.tap(find.text('New instance'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'bad');
    await t.pump();
    await t.tap(find.text('Create'));
    await t.pumpAndSettle();

    proc.onStart = (e, a) => throw const ProcessException('setsid', []);
    await t.tap(find.byTooltip('Launch'));
    await t.pumpAndSettle();
    expect(find.textContaining('Launch failed'), findsOneWidget);
  });

  testWidgets('refresh reloads the app list', (t) async {
    final (proc, _) = await pumpApp(t);
    await t.tap(find.byTooltip('Refresh'));
    await t.pumpAndSettle();
    expect(proc.calls.where((c) => c.startsWith('flatpak list')), hasLength(2));
  });
}
