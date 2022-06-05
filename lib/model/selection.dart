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
    _selection.clear();
    if (notify) {
      notifyListeners();
    }
  }

  void add(String item, {bool notify = true}) {
    _selection.add(item);
    if (notify) {
      notifyListeners();
    }
  }

  void set(List<String> items, {bool notify = true}) {
    _selection.clear();
    _selection.addAll(items);
    if (notify) {
      notifyListeners();
    }
  }
}
