import 'dart:io';

import 'package:er/app.dart';
import 'package:er/src/flatpak_service.dart';
import 'package:er/src/instance_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_proc.dart';

const tsv = 'org.a.One\tApp One\t1.0\tflathub\tsystem\n'
    'org.b.Two\tApp Two\t2.0\tflathub\tuser\n';

Future<(FakeProc, InstanceStore)> pumpApp(WidgetTester t,
    {String? listOut}) async {
  final dir = Directory.systemTemp.createTempSync('er');
  addTearDown(() => dir.deleteSync(recursive: true));
  final proc = FakeProc();
  proc.onRun = (e, a) =>
      ProcessResult(0, 0, listOut ?? tsv, '');
  var alive = false;
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
