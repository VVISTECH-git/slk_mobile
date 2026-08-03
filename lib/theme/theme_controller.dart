import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// Holds the selected theme and persists the choice to SharedPreferences so it
/// survives cold starts. Starts on the default and swaps in the saved one once
/// it loads.
class ThemeController extends Notifier<SlkTheme> {
  static const _key = 'slk_theme';

  @override
  SlkTheme build() {
    _restore();
    return SlkThemes.fallback;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_key);
    if (id != null) state = SlkThemes.byId(id);
  }

  Future<void> select(SlkTheme theme) async {
    if (theme.id == state.id) return;
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, theme.id);
  }
}

final themeControllerProvider = NotifierProvider<ThemeController, SlkTheme>(ThemeController.new);
