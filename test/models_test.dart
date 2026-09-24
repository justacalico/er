import 'package:er/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppInstance json roundtrip', () {
    final i = AppInstance(
      appId: 'a',
      name: 'n',
      home: '/h',
      privateBus: false,
      isolateHome: false,
      pgid: 9,
    );
    final j = i.toJson();
    expect(j['pgid'], 9);
    final back = AppInstance.fromJson(j);
    expect(back.appId, 'a');
    expect(back.privateBus, isFalse);
    expect(back.isolateHome, isFalse);
    expect(back.pgid, 9);
  });

  test('AppInstance defaults and null pgid', () {
    final i = AppInstance(appId: 'a', name: 'n', home: '/h');
    expect(i.privateBus, isTrue);
    expect(i.isolateHome, isTrue);
    expect(i.toJson().containsKey('pgid'), isFalse);
    final back = AppInstance.fromJson(
        {'appId': 'a', 'name': 'n', 'home': '/h'});
    expect(back.privateBus, isTrue);
    expect(back.pgid, isNull);
  });

  test('FlatpakApp holds fields', () {
    const a = FlatpakApp(
        id: 'i', name: 'n', version: 'v', origin: 'o', installation: 's');
    expect(a.id, 'i');
    expect(a.installation, 's');
  });
}
