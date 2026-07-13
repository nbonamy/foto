import 'package:flutter_test/flutter_test.dart';
import 'package:foto/model/selection.dart';

void main() {
  test('selection remains unique and preserves insertion order', () {
    final selection = SelectionModel();

    selection.set(['a', 'b', 'a', 'c', 'b']);
    selection.add('a');

    expect(selection.get, ['a', 'b', 'c']);
  });

  test('toggle adds and removes an item exactly once', () {
    final selection = SelectionModel()..set(['a', 'b']);

    selection.toggle('a');
    expect(selection.get, ['b']);

    selection.toggle('a');
    expect(selection.get, ['b', 'a']);
  });

  test('setting an unchanged selection does not notify listeners', () {
    final selection = SelectionModel()..set(['a', 'b'], notify: false);
    var notifications = 0;
    selection.addListener(() => notifications += 1);

    selection.set(['a', 'b']);
    selection.add('a');

    expect(notifications, 0);
  });

  test('refresh notifies listeners without changing selection', () {
    final selection = SelectionModel()..set(['a'], notify: false);
    var notifications = 0;
    selection.addListener(() => notifications += 1);

    selection.refresh();

    expect(selection.get, ['a']);
    expect(notifications, 1);
  });
}
