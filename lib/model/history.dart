import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryModel extends ChangeNotifier {
  final List<String> _history = [];

  UnmodifiableListView<String> get get => UnmodifiableListView(_history);

  String? get top => _history.isNotEmpty ? _history.last : null;

  init() async {
    await _load();
  }

  void push(String location) {
    if (top != location) {
      _history.add(location);
      if (_history.length > 20) {
        _history.removeAt(0);
      }
      notifyListeners();
      _save();
    }
  }

  void pop() {
    _history.removeLast();
    notifyListeners();
    _save();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    var history = prefs.getStringList('history') ?? [];
    for (var path in history) {
      if (Directory(path).existsSync()) {
        _history.add(path);
      }
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('history', _history);
  }
}
