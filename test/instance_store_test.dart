import 'dart:io';

import 'package:er/src/instance_store.dart';
import 'package:er/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaultPath joins data dir', () {
    expect(InstanceStore.defaultPath('/d'), '/d/instances.json');
  });

  test('load tolerates missing file', () {
    final s = InstanceStore('/nonexistent/dir/instances.json')..load();
    expect(s.forApp('a'), isEmpty);
  });

  test('save and load roundtrip', () {
    final dir = Directory.systemTemp.createTempSync('er');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/instances.json';

    final s = InstanceStore(path);
    s.forApp('org.a.One').add(AppInstance(
      appId: 'org.a.One',
      name: 'alt',
      home: '/h/alt',
      privateBus: false,
      isolateHome: true,
      pgid: 42,
    ));
    s.save();

    final s2 = InstanceStore(path)..load();
    final list = s2.forApp('org.a.One');
    expect(list, hasLength(1));
    expect(list.single.name, 'alt');
    expect(list.single.privateBus, isFalse);
    expect(list.single.isolateHome, isTrue);
    expect(list.single.pgid, 42);
  });

  test('remove deletes by name', () {
    final s = InstanceStore('/x/i.json');
    s.forApp('a').add(AppInstance(appId: 'a', name: 'one', home: '/h/1'));
    s.forApp('a').add(AppInstance(appId: 'a', name: 'two', home: '/h/2'));
    s.remove('a', 'one');
    expect(s.forApp('a').map((i) => i.name), ['two']);
  });
}
