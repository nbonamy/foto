import 'package:flutter_test/flutter_test.dart';
import 'package:foto/model/history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('does not pop the root location', () {
    final history = HistoryModel()..reset('/root');

    history.pop();

    expect(history.get, ['/root']);
    expect(history.canPop, isFalse);
  });

  test('keeps navigation history aligned beyond twenty pushes', () {
    final history = HistoryModel()..reset('/root');
    for (var index = 0; index < 25; index += 1) {
      history.push('/root/$index', false);
    }

    expect(history.get, hasLength(26));
    expect(history.top, '/root/24');
  });

  test('can mirror an external navigator pop without notifying', () {
    final history = HistoryModel()
      ..reset('/root')
      ..push('/root/child', false);
    var notifications = 0;
    history.addListener(() => notifications += 1);

    history.pop(notify: false);

    expect(history.top, '/root');
    expect(notifications, 0);
  });
}
