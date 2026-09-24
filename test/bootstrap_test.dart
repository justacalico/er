import 'package:er/app.dart';
import 'package:er/bootstrap/io.dart' as io;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('io bootstrap builds the desktop app', () {
    expect(io.buildApp(), isA<ErApp>());
  });
}
