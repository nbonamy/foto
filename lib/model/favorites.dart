import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:foto/utils/paths.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesModel extends ChangeNotifier {
  final List<String> _favorites = [];

  UnmodifiableListView<String> get get => UnmodifiableListView(_favorites);

  init() async {
    await _load();
  }

  bool isFavorite(String favorite) {
    return _favorites.contains(favorite);
  }

  void add(String favorite) {
    if (!isFavorite(favorite)) {
      _favorites.add(favorite);
      notifyListeners();
      _save();
    }
  }

  void remove(String favorite) {
    if (isFavorite(favorite)) {
      _favorites.remove(favorite);
      notifyListeners();
      _save();
    }
  }

  void move(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    _favorites.insert(newIndex, _favorites.removeAt(oldIndex));
    notifyListeners();
    _save();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    var favorites =
        prefs.getStringList('favorites') ?? FavoritesModel._defaultFavorites();
    for (var favorite in favorites) {
      if (Directory(favorite).existsSync()) {
        _favorites.add(favorite);
      }
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('favorites', _favorites);
  }

  static List<String> _defaultFavorites() {
    List<String> favorites = [];
    for (String? folder in [
      SystemPath.pictures(),
      SystemPath.desktop(),
      '/Library/Desktop Pictures',
      '/Library/User Pictures'
    ]) {
      if (folder != null && Directory(folder).existsSync()) {
        favorites.add(folder);
      }
    }
    return favorites;
  }
}
