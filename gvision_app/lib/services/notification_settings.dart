import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettings {
  NotificationSettings._();

  static const _keySys       = 'notif_sys';
  static const _keyInsp      = 'notif_insp';
  static const _keyLot       = 'notif_lot';
  static const _keyRecipe    = 'notif_recipe';
  static const _keyYield     = 'notif_yield_alert';
  static const _keyThreshold = 'notif_yield_threshold';

  static bool   sysEnabled       = true;
  static bool   inspEnabled      = false; // 검사 이벤트는 기본 off (빈도 높음)
  static bool   lotEnabled       = true;
  static bool   recipeEnabled    = false;
  static bool   yieldAlertEnabled = true;
  static double yieldThreshold   = 95.0;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    sysEnabled        = p.getBool(_keySys)       ?? true;
    inspEnabled       = p.getBool(_keyInsp)      ?? false;
    lotEnabled        = p.getBool(_keyLot)       ?? true;
    recipeEnabled     = p.getBool(_keyRecipe)    ?? false;
    yieldAlertEnabled = p.getBool(_keyYield)     ?? true;
    yieldThreshold    = p.getDouble(_keyThreshold) ?? 95.0;
  }

  static Future<void> setSys(bool v) async {
    sysEnabled = v;
    (await SharedPreferences.getInstance()).setBool(_keySys, v);
  }

  static Future<void> setInsp(bool v) async {
    inspEnabled = v;
    (await SharedPreferences.getInstance()).setBool(_keyInsp, v);
  }

  static Future<void> setLot(bool v) async {
    lotEnabled = v;
    (await SharedPreferences.getInstance()).setBool(_keyLot, v);
  }

  static Future<void> setRecipe(bool v) async {
    recipeEnabled = v;
    (await SharedPreferences.getInstance()).setBool(_keyRecipe, v);
  }

  static Future<void> setYieldAlert(bool v) async {
    yieldAlertEnabled = v;
    (await SharedPreferences.getInstance()).setBool(_keyYield, v);
  }

  static Future<void> setYieldThreshold(double v) async {
    yieldThreshold = v;
    (await SharedPreferences.getInstance()).setDouble(_keyThreshold, v);
  }

  // logType → 알림 허용 여부
  static bool shouldNotify(int logType) => switch (logType) {
    1 => sysEnabled,
    2 => inspEnabled,
    4 => lotEnabled,
    5 => recipeEnabled,
    _ => false,
  };
}
