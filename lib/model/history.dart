import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryModel extends ChangeNotifier {
  final List<String> _history = [];
  bool _lastChangeIsPop = false;

  UnmodifiableListView<String> get get => UnmodifiableListView(_history);

  String get top => _history.isNotEmpty ? _history.last : '/';

  bool get lastChangeIsPop {
    bool rc = _lastChangeIsPop;
    _lastChangeIsPop = false;
    return rc;
  }

  static HistoryModel of(BuildContext context) {
    return Provider.of<HistoryModel>(context, listen: false);
  }

  init() async {
    await _load();
  }

  void reset(String location, {bool notify = false}) {
    _history.clear();
    _history.add(location);
    if (notify) {
      notifyListeners();
    }
    _save();
  }

  void push(String location, bool notify) {
    if (top != location) {
      _lastChangeIsPop = false;
      _history.add(location);
      if (_history.length > 20) {
        _history.removeAt(0);
      }
      if (notify) {
        notifyListeners();
      }
      _save();
    }
  }

  void pop() {
    _lastChangeIsPop = true;
    _history.removeLast();
    notifyListeners();
    _save();
  }

  Future<void> _load() async {
    _history.clear();
    final prefs = await SharedPreferences.getInstance();
    String? location = prefs.getString('browserLocation');
    if (location != null && Directory(location).existsSync()) {
      _history.add(location);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('browserLocation', top);
  }
}
