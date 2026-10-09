import 'package:flutter_test/flutter_test.dart';
import 'package:nba_trivia/update_service.dart';

void main() {
  test('compareVersions', () {
    expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
    expect(compareVersions('1.0.0', '1.0.0'), 0);
    expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
    expect(compareVersions('2.0', '1.9.9'), greaterThan(0));
  });
}

