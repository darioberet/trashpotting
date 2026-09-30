import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestisce la preferenza di tema (chiaro/scuro/sistema) e la persiste
/// tra le sessioni tramite [SharedPreferences].
class ThemeController extends ChangeNotifier {
  ThemeController({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _prefsKey = 'theme_mode';

  final SharedPreferencesAsync _preferences;
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    final stored = await _preferences.getString(_prefsKey);
    final parsed = _parse(stored);
    if (parsed != _mode) {
      _mode = parsed;
      notifyListeners();
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _preferences.setString(_prefsKey, mode.name);
  }

  ThemeMode _parse(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}

class ThemeControllerScope extends InheritedNotifier<ThemeController> {
  const ThemeControllerScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController watch(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ThemeControllerScope>();
    assert(scope != null, 'ThemeControllerScope non trovato nel widget tree.');
    return scope!.notifier!;
  }

  static ThemeController of(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<ThemeControllerScope>();
    final scope = element?.widget as ThemeControllerScope?;
    assert(scope != null, 'ThemeControllerScope non trovato nel widget tree.');
    return scope!.notifier!;
  }
}
