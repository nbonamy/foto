import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

typedef Selection = UnmodifiableListView<String>;

class SelectionModel extends ChangeNotifier {
  final List<String> _selection = [];

  UnmodifiableListView<String> get get => UnmodifiableListView(_selection);

  static SelectionModel of(BuildContext context) {
    return Provider.of<SelectionModel>(context, listen: false);
  }

  bool contains(String item) {
    return _selection.contains(item);
  }

  void clear({bool notify = true}) {
    if (_selection.isEmpty) {
      return;
    }
    _selection.clear();
    if (notify) {
      notifyListeners();
    }
  }

  void add(String item, {bool notify = true}) {
    if (_selection.contains(item)) {
      return;
    }
    _selection.add(item);
    if (notify) {
      notifyListeners();
    }
  }

  void set(List<String> items, {bool notify = true}) {
    final uniqueItems = items.toSet().toList(growable: false);
    if (_selection.length == uniqueItems.length &&
        _selection.indexed
            .every((entry) => entry.$2 == uniqueItems[entry.$1])) {
      return;
    }
    _selection.clear();
    _selection.addAll(uniqueItems);
    if (notify) {
      notifyListeners();
    }
  }

  void toggle(String item, {bool notify = true}) {
    if (_selection.remove(item) == false) {
      _selection.add(item);
    }
    if (notify) {
      notifyListeners();
    }
  }

  void refresh() {
    notifyListeners();
  }
}
