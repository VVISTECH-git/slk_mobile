import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_layout.dart';

/// Holds the selected home layout and persists it to SharedPreferences so it
/// survives cold starts — mirrors the theme controller. Also tracks whether the
/// user has made a choice yet, so the first-run prompt only shows once.
class HomeLayoutController extends Notifier<HomeLayout> {
  static const _key = 'slk_home_layout';
  static const _chosenKey = 'slk_home_layout_chosen';

  @override
  HomeLayout build() {
    _restore();
    return HomeLayout.grid;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_key);
    if (id != null) state = homeLayoutById(id);
  }

  Future<void> select(HomeLayout layout) async {
    state = layout;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, layout.name);
    await prefs.setBool(_chosenKey, true);
  }

  /// Whether the user has already picked a layout (drives the first-run prompt).
  Future<bool> hasChosen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chosenKey) ?? false;
  }
}

final homeLayoutProvider =
    NotifierProvider<HomeLayoutController, HomeLayout>(HomeLayoutController.new);
